#include "decoder.h"

#define DEC_FS    46875        /* sample rate ADC reale (40.5MHz / 864) */
#define DEC_NFFT  512          /* punti FFT (per la risoluzione in frequenza) */


/* UN TONO ALLA VOLTA (half-duplex, 2 soli device): 3 frequenze TUTTE forti, condivise da
 * master e slave. Il simbolo E' la frequenza; il decode = bin piu' forte tra i 3.
 * Niente piu' carrier+dato: chi ricevi mentre sei zitto e' per forza l'altro. */
#define F_BIT0    1200         /* bit 0         -> bin13 (provato forte: decodifica A) */
#define F_BIT1    1700         /* bit 1         -> bin19 (provato forte: 34-138 in v32) */
#define F_EOF     2472         /* EOF/preambolo -> bin27 (vecchio carrier: 34-90 per decine di log) */

/* meta'-finestra del massimo locale: ±3 (come l'hardware: WINR=3) */
#define WIN_HALF  3

/* risoluzione in frequenza di un bin */
#define FREQ_TOL  ((double)DEC_FS / (double)DEC_NFFT)   /* ~91.55 Hz */

#define NF_SKIP_LOW 8        /* salta DC + bin bassi nel noise floor */


/* Soglia unica: i 3 toni arrivano FORTI (34..138), il rumore sta a 1..3 -> 6 separa pulito.
 * mult=0 -> nf ignorato, conta solo il minimo assoluto. */
#define TONE_MULT   0.0
#define TONE_MIN    6.0

/* magnitudine del bin = |parte reale| */
static int bin_mag(const int16_t *re, int bin) {
    int v = re[bin];
    return (v < 0) ? -v : v;
}

static double noise_floor(const int16_t *re, int n) {
    long sum = 0; int cnt = 0;
    for (int i = NF_SKIP_LOW; i < n; i++) { sum += bin_mag(re, i); cnt++; }
    return cnt ? (double)sum / (double)cnt : 0.0;
}

/* interpolazione parabolica attorno a peak_bin -> frequenza e ampiezza stimate */
static void interpolate_peak(const int16_t *re, int peak_bin, double *freq, double *amp) {
    double a = (double)bin_mag(re, peak_bin - 1);
    double b = (double)bin_mag(re, peak_bin);
    double g = (double)bin_mag(re, peak_bin + 1);
    double denom = a - 2.0 * b + g;
    double p = 0.0;
    if (denom != 0.0) p = 0.5 * (a - g) / denom;
    if (p < -0.5) p = -0.5;
    if (p >  0.5) p =  0.5;
    *freq = ((double)peak_bin + p) * (double)DEC_FS / (double)DEC_NFFT;
    *amp  = b - 0.25 * (a - g) * p;
}

/* ampiezza interpolata se target_hz e' presente (picco > nf*4, massimo locale +-3,
 * frequenza entro 1 bin dal target); 0 altrimenti. */
static double detect_freq(const int16_t *re, int n, int target_hz, double nf,
                          double mult, double minthr) {
    int j = (int)((double)target_hz / FREQ_TOL + 0.5);   /* round (positivo) */
    if (j < 4 || j >= n - 4) return 0.0;
    double amp = (double)bin_mag(re, j);
    double thr = nf * mult;
    if (thr < minthr) thr = minthr;
    if (amp <= thr) return 0.0;
    for (int i = j - WIN_HALF; i <= j + WIN_HALF; i++)    /* dev'essere il max locale */
        if (i != j && (double)bin_mag(re, i) > amp) return 0.0;
    double f, a;
    interpolate_peak(re, j, &f, &a);
    double d = f - (double)target_hz;
    if (d < 0) d = -d;
    return (d <= FREQ_TOL) ? a : 0.0;
}

rx_symbol_t decode_symbol(const int16_t *re, int n) {
    rx_symbol_t r; r.channel = 1; r.sym = -1;       /* canale non piu' usato (half-duplex) */
    double nf = noise_floor(re, n);

    /* UN tono alla volta: prendo il PIU' FORTE tra i 3 bin (sopra soglia). Ognuno passa per
     * detect_freq -> 3 bin attorno + parabolica + max locale; poi vince il maggiore. */
    double a0 = detect_freq(re, n, F_BIT0, nf, TONE_MULT, TONE_MIN);   /* 1200 bin13 */
    double a1 = detect_freq(re, n, F_BIT1, nf, TONE_MULT, TONE_MIN);   /* 1700 bin19 */
    double ae = detect_freq(re, n, F_EOF,  nf, TONE_MULT, TONE_MIN);   /* 2200 bin24 */
    double best = 0.0; int sym = -1;
    if (a0 > best) { best = a0; sym = 0; }
    if (a1 > best) { best = a1; sym = 1; }
    if (ae > best) { best = ae; sym = 2; }

    r.sym = sym;
    return r;
}

char decode_char(const int16_t *re, int n) {
    rx_symbol_t s = decode_symbol(re, n);
    if (s.sym < 0) return 0;
    return (char)('A' + s.sym);   /* bit0->'A', bit1->'B', EOF->'C' (mittente = l'altro device) */
}
