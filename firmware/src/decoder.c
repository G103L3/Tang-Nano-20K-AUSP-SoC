#include "decoder.h"

/* ── Decoder protocollo CARRIER + BIT (port SW del decoder HW di c9bf2c0 "works") ──
 * Ogni simbolo trasmesso e' una COPPIA: un carrier (chi parla) + un tono-dato (il bit).
 * Per ogni frame FFT il decoder cerca, su 5 bin attesi, il carrier (master/slave) e il
 * dato (bit0/bit1/EOF) col massimo locale +-3 + test parabolico vs soglia assoluta.
 *   - carrier MASTER bin22 (~2014 Hz) -> e' SE STESSO (loopback) -> minuscole 'a'/'b'/'c'
 *   - carrier SLAVE  bin27 (~2472 Hz) -> messaggio RICEVUTO    -> MAIUSCOLE 'A'/'B'/'C'
 *   - dato: bit0 bin39 (~3571), bit1 bin50 (~4577), EOF bin32 (~2930)
 * fs=46875, N=512 -> bin = round(freq*512/46875). I bin sono quelli del decoder HW. */

#define BIN_CM   22    /* carrier master 2014 Hz */
#define BIN_CS   27    /* carrier slave  2472 Hz */
#define BIN_B0   39    /* bit0           3571 Hz */
#define BIN_B1   50    /* bit1           4577 Hz */
#define BIN_EOF  32    /* EOF            2930 Hz */

#define WINR       3   /* meta'-finestra del massimo locale: +-3 (come HW WINR=3) */
#define THRESHOLD  6   /* soglia ASSOLUTA sul magnitude (come generic HW THRESHOLD=6) */

/* magnitudine del bin = |parte reale xk_re| */
static int bin_mag(const int16_t *re, int bin) {
    int v = re[bin];
    return (v < 0) ? -v : v;
}

/* Rilevazione di UN bin atteso (identica al ST_EVAL del decoder HW):
 *   - finestra +-3 attorno al bin
 *   - massimo locale: centro >= tutti e 6 i vicini
 *   - curvatura d = 2b - a - g > 0 (e' un picco verso l'alto)
 *   - test parabolico vs soglia: 8*d*(b-THR) + (a-g)^2 > 0  (ampiezza interpolata > THR)
 * Ritorna 1 se rilevato; *beta = magnitude del centro (per confronto forza). */
static int detect_bin(const int16_t *re, int n, int bin, int *beta) {
    if (bin < WINR || bin >= n - WINR) { *beta = 0; return 0; }
    int w[2 * WINR + 1];
    for (int k = 0; k < 2 * WINR + 1; k++) w[k] = bin_mag(re, bin - WINR + k);
    int b = w[WINR];
    *beta = b;
    if (!(b >= w[0] && b >= w[1] && b >= w[2] &&
          b >= w[4] && b >= w[5] && b >= w[6])) return 0;   /* massimo locale */
    int a = w[WINR - 1], g = w[WINR + 1];
    int d = 2 * b - a - g;                                  /* curvatura */
    if (d <= 0) return 0;
    int diff = a - g;
    long test = 8L * (long)d * (long)(b - THRESHOLD) + (long)diff * (long)diff;
    return (test > 0);
}

/* 1 se il carrier dello SLAVE (bin27) e' presente nel frame. Usato dalla logica del
 * canale (main): il master non parla / si interrompe se sente lo slave. Indipendente
 * dal proprio carrier (bin22) -> il master non si auto-rileva mentre emette. */
int decode_slave_carrier(const int16_t *re, int n) {
    int beta;
    return detect_bin(re, n, BIN_CS, &beta);
}

rx_symbol_t decode_symbol(const int16_t *re, int n) {
    rx_symbol_t r; r.channel = -1; r.sym = -1;

    int bcm, bcs, bb0, bb1, beof;
    int dcm = detect_bin(re, n, BIN_CM,  &bcm);
    int dcs = detect_bin(re, n, BIN_CS,  &bcs);
    int d0  = detect_bin(re, n, BIN_B0,  &bb0);
    int d1  = detect_bin(re, n, BIN_B1,  &bb1);
    int de  = detect_bin(re, n, BIN_EOF, &beof);

    /* dato = il piu' forte tra bit0/bit1/EOF (solo se rilevato) */
    int data_sym = -1, data_beta = 0;
    if (d0 && bb0  > data_beta) { data_beta = bb0;  data_sym = 0; }
    if (d1 && bb1  > data_beta) { data_beta = bb1;  data_sym = 1; }
    if (de && beof > data_beta) { data_beta = beof; data_sym = 2; }

    /* carrier = master XOR slave (se entrambi, il piu' forte) */
    int chan = -1;
    if      (dcm && !dcs) chan = 0;
    else if (dcs && !dcm) chan = 1;
    else if (dcm &&  dcs) chan = (bcm >= bcs) ? 0 : 1;

    if (data_sym >= 0 && chan >= 0) { r.channel = chan; r.sym = data_sym; }
    return r;
}

char decode_char(const int16_t *re, int n) {
    rx_symbol_t s = decode_symbol(re, n);
    if (s.sym < 0) return 0;
    /* slave -> 'A'/'B'/'C' (ricevuto); master -> 'a'/'b'/'c' (loopback di se stesso) */
    return (char)((s.channel == 1 ? 'A' : 'a') + s.sym);
}
