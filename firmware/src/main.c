/*
 * EFES - firmware "cervello" del soft core PicoRV32.
 *
 * La CPU prende il posto delle FSM che oggi stanno in top.vhd:
 *   - EMIT  (TX): legge un char dall'UART caratteri (S6, 0x2000_0000), lo converte
 *                 in (carrier, tono) e pilota la PWM DDS a due toni (S2, 0x5000_0000).
 *                 Mappa identica a char_to_wbdata() del top.
 *   - DECODE(RX): all'IRQ dell'audio accelerator (bit 20) legge i risultati FFT dalla
 *                 SDRAM (S0, 0x4800_0000), applica ESATTAMENTE l'algoritmo intero di
 *                 audio_decoder.vhd (bin 22/27/39/50/32, finestra +-3, THRESHOLD=6,
 *                 test = 8*d*(beta-T)+(alpha-gamma)^2), ed emette il char a/b/c (master)
 *                 o A/B/C (slave) sull'UART caratteri.
 *
 * Tutto intero: nessun float, nessuna sqrt (la "magnitudine" e' |X_k_re| a 15 bit,
 * come fa abs_mag() in VHDL).
 *
 * NB: richiede che la CPU sia master M0 sul bus (top.vhd) e che SDRAM/PWM siano slave
 * raggiungibili. Vedi periphs.h per la mappa.
 */
#include <stdint.h>
#include "../include/periphs.h"
/* norflash.h rimosso: il flash ora e' hardware (flash_ctrl.vhd), non lo fa la CPU. */

#define CPU_HZ   40500000u
#define BAUD     115200u

/* ----- emit (char -> due toni), identico a char_to_wbdata() in top.vhd ----- */
/* PWM DDS S2: 0x04 = dat[31:16]=tono(f2), dat[15:0]=carrier(f1) -> start; 0x08 stop.
 * (Le macro pwm10_* di periphs.h sono di un vecchio PWM period/duty: non usarle.) */
#define PWM10_TONES  (*(volatile uint32_t*)(0x50000000u + 0x04))
#define PWM10_STOPW  (*(volatile uint32_t*)(0x50000000u + 0x08))

/* tono ~72 ms, silenzio ~350 ms (come TONE_CYCLES/SIL_CYCLES del top) */
#define TONE_MS  72u
#define SIL_MS   350u

/* ----- decode: costanti ESATTE di audio_decoder.vhd ----- */
#define NCAND      5
#define WINR       3
#define THRESHOLD  6
/* ordine: 0=carrier master(2000/bin22), 1=carrier slave(2400/27),
 *         2=bit0(3500/39), 3=bit1(4500/50), 4=EOF(2900/32) */
static const int CAND_BIN[NCAND] = { 22, 27, 39, 50, 32 };

/* S0 (0x4800_0000) = FSM tst_ collegata al bus (opzione 2). La FSM legge la SDRAM
 * come prima (26 parole x 20 burst) e mette il burst corrente in tst_rd_arr2; noi
 * la leggiamo via bus su flag, burst per burst. NON e' una BSRAM mirror: e' il
 * buffer di burst della FSM che ha appena letto la SDRAM.
 *   0x00..0x64 : tst_rd_arr2[0..25] (26 parole del burst corrente)
 *   0x80       : stato = [31]=frame_ready, [16]=in_read, [12:8]=burst, [5:0]=idx
 * bin k -> burst = k/26, parola j = k%26. I bin che servono (<=53) stanno nei
 * burst 0,1,2. */
#define FFT_S0_WORDS   ((volatile uint32_t*)0x48000000u)
#define FFT_S0_STATUS  (*(volatile uint32_t*)(0x48000000u + 0x80))
#define NEED_BURSTS    3                 /* burst 0,1,2 -> bin 0..77 (servono <=53) */
static uint16_t fftbuf[NEED_BURSTS][26]; /* copia locale dei burst, riempita via S0 */

/* Raccoglie i burst 0,1,2 dalla FSM via S0: poll dello stato, quando idx>=26 il
 * burst corrente e' pronto -> copia le 26 parole. Si ferma quando ha i 3 burst
 * (o per timeout). La FSM gira da sola: bisogna stare al passo (opzione 2). */
static void capture_bursts(void) {
    unsigned got = 0;                 /* bitmask burst presi */
    uint32_t guard = 4000000u;        /* timeout di sicurezza */
    while (got != ((1u << NEED_BURSTS) - 1u) && guard--) {
        uint32_t st  = FFT_S0_STATUS;
        unsigned idx = st & 0x3Fu;
        unsigned b   = (st >> 8) & 0x1Fu;
        if (idx >= 26u && b < NEED_BURSTS && !(got & (1u << b))) {
            for (int j = 0; j < 26; j++)
                fftbuf[b][j] = (uint16_t)(FFT_S0_WORDS[j] & 0xFFFFu);
            got |= (1u << b);
        }
    }
}

volatile uint32_t g_frame_ready = 0;   /* alzato dall'IRQ dell'accelerator */

/* crt0.S salta qui sul vettore IRQ. L'unico IRQ abilitato e' il bit 20 (FFT done). */
void irq_handler(void) { g_frame_ready = 1; }

/* Contatore cicli del picorv32 (ENABLE_COUNTERS=1): conta i cicli di clk_sdram
 * (40.5 MHz). rdcycle e' ACCURATO a prescindere dal CPI multi-ciclo della CPU. */
static inline uint32_t rdcycle32(void) {
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}
static inline uint32_t ms_to_cycles(uint32_t ms) {
    return ms * (CPU_HZ / 1000u);
}

/* ===========================================================================
 * DIAGNOSTICA. Canale DEBUG: ogni riga = '$' + testo + '\n'. Solo SCRITTURE UART
 * (affidabili). L'ESP32 (fpga_uart_link.cpp) le inoltra VERBATIM su USB con a-capo
 * pulito. I token usano SOLO caratteri sicuri (niente a/b/c/A/B/C, che l'ESP32
 * filtra/decodifica come simboli) -> leggibili anche con ESP32 NON aggiornato (perde
 * solo gli a-capo, le righe si attaccano ma i numeri restano).
 * =========================================================================== */
static uint32_t g_loops;   /* giri main loop (indicatore polling rate)         */
static uint32_t g_rxok;    /* giri con STATUS=rx_valid                         */
static uint32_t g_got;     /* char di protocollo validi accodati              */
static uint32_t g_inv;     /* byte letti ma NON validi (rumore/lettura sporca) */
static uint32_t g_flk;     /* STATUS=valid ma DATA bit8=0 (lettura flaky)      */
static uint32_t g_drp;     /* char scartati per coda piena                    */
static uint32_t g_emt;     /* toni completati (a fine silenzio)               */
static uint32_t g_qhi;     /* massimo riempimento coda visto                  */
static uint32_t g_tick;    /* righe stats stampate (~uptime in s; reset=reboot)*/
static uint32_t g_sym[6];  /* conteggio per simbolo: 0=a 1=b 2=c 3=A 4=B 5=C  */
static uint8_t  g_inv_last; /* ultimo byte DATA[7:0] NON valido (decimale in stats: ivb=) */

static void dbg_begin(void) { uartext_putchar('$'); }
static void dbg_end(void)   { uartext_putchar('\n'); }
static void dbg_str(const char *s) { while (*s) uartext_putchar(*s++); }
static void dbg_line(const char *s) { dbg_begin(); dbg_str(s); dbg_end(); }

static void put_u32(uint32_t v) {
    char b[10];
    int i = 0;
    if (v == 0) { uartext_putchar('0'); return; }
    while (v) { b[i++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (i) uartext_putchar(b[--i]);
}
/* 2 cifre hex: SICURO solo sui char di protocollo (0x41-43/0x61-63 -> nessuna A-F). */
static void put_hh(uint8_t b) {
    static const char H[] = "0123456789ABCDEF";
    uartext_putchar(H[(b >> 4) & 0xF]);
    uartext_putchar(H[b & 0xF]);
}
/* eventi real-time: $R<hex> = char catturato ; $E<hex> = tono avviato. Mostra il treno. */
static void ev_rx(uint8_t c)   { dbg_begin(); uartext_putchar('R'); put_hh(c); dbg_end(); }
static void ev_emit(uint8_t c) { dbg_begin(); uartext_putchar('E'); put_hh(c); dbg_end(); }

/* indice del simbolo (0..5) o -1 se NON e' un char di protocollo (a/b/c/A/B/C). */
static int sym_idx(uint8_t c) {
    switch (c) {
        case 'a': return 0; case 'b': return 1; case 'c': return 2;
        case 'A': return 3; case 'B': return 4; case 'C': return 5;
        default:  return -1;
    }
}

static int tone_word_for_char(char ch, uint32_t *word) {
    int letter = -1, carrier = 0, sig = 0;
    if      (ch >= 'A' && ch <= 'Z') { letter = ch - 'A'; carrier = 2400; } /* slave  */
    else if (ch >= 'a' && ch <= 'z') { letter = ch - 'a'; carrier = 2000; } /* master */
    switch (letter) {
        case 0:  sig = 3500; break;   /* bit 0 */
        case 1:  sig = 4500; break;   /* bit 1 */
        case 2:  sig = 2900; break;   /* EOF   */
        default: return 0;            /* char non valido: niente tono */
    }
    *word = ((uint32_t)sig << 16) | (uint32_t)carrier;
    return 1;
}

/* La UART_GENERIC ha un solo registro RX, non una FIFO. Se il firmware resta in
 * busy-wait mentre suona, i byte successivi dell'ESP32 vengono sovrascritti. Qui una
 * piccola coda software (di CHAR) disaccoppia la CATTURA dalla RIPRODUZIONE, e il
 * player temporizza tono/silenzio SENZA bloccare il polling della UART. */
#define TXQ_LEN 16u
static uint8_t  tone_q[TXQ_LEN];
static unsigned q_head = 0, q_tail = 0, q_count = 0;

typedef enum { PLAYER_IDLE, PLAYER_TONE, PLAYER_SILENCE } player_state_t;
static player_state_t player_state = PLAYER_IDLE;
static uint32_t player_t0 = 0;

static void tone_enqueue(uint8_t ch) {
    if (q_count >= TXQ_LEN) {
        /* coda piena: scarta il piu' vecchio e conserva il flusso recente */
        q_tail = (q_tail + 1u) % TXQ_LEN;
        q_count--;
        g_drp++;
    }
    tone_q[q_head] = ch;
    q_head = (q_head + 1u) % TXQ_LEN;
    q_count++;
    if (q_count > g_qhi) g_qhi = q_count;
}

static int tone_dequeue(uint8_t *ch) {
    if (q_count == 0) return 0;
    *ch = tone_q[q_tail];
    q_tail = (q_tail + 1u) % TXQ_LEN;
    q_count--;
    return 1;
}

static void tone_player_tick(void) {
    uint32_t now = rdcycle32();
    uint8_t  ch;
    uint32_t word;

    switch (player_state) {
        case PLAYER_IDLE:
            if (tone_dequeue(&ch)) {
                if (tone_word_for_char((char)ch, &word)) {
                    PWM10_TONES = word;          /* start (il pwm carica la freq con start=0) */
                    ev_emit(ch);
                    player_t0 = now;
                    player_state = PLAYER_TONE;
                }
                /* char non valido: scartato, resta IDLE */
            }
            break;
        case PLAYER_TONE:
            if ((now - player_t0) >= ms_to_cycles(TONE_MS)) {
                PWM10_STOPW = 1;                 /* stop */
                player_t0 = now;
                player_state = PLAYER_SILENCE;
            }
            break;
        case PLAYER_SILENCE:
            if ((now - player_t0) >= ms_to_cycles(SIL_MS)) {
                g_emt++;
                player_state = PLAYER_IDLE;
            }
            break;
    }
}

/* CAPTURE (NON bloccante).
 * I diagnostici sul campo (r8) hanno mostrato: STATUS (0x14) torna rx_valid in modo
 * AFFIDABILE (rxok cresce coi REQ_PRESENCE), ma il bit8 della lettura di DATA (0x00) e'
 * SEMPRE 0 (flk == rxok). E' una race "clear-on-read": leggere 0x00 azzera rx_valid nello
 * stesso ciclo in cui sale l'ack REGISTRATO, e dat_o(8)=rx_valid e' COMBINATORIO -> quando
 * la CPU campiona il dato (al ciclo dell'ack) rx_valid e' gia' 0. MA rx_data[7:0] NON viene
 * azzerato dalla lettura: il carattere e' nel byte basso.
 * Quindi: gate su STATUS (affidabile), prendi DATA[7:0] e IGNORA il bit8 (lo teniamo solo
 * come diagnostica in g_flk). La lettura di DATA azzera rx_valid -> nessun doppio prelievo. */
static void capture(void) {
    if (UARTEXT_STATUS & 0x2u) {              /* bit1 = rx_valid via STATUS (affidabile, non consuma) */
        g_rxok++;
        uint32_t d = UARTEXT_DATA;            /* consuma rx_valid; [7:0] = char (affidabile) */
        if (!(d & (1u << 8))) g_flk++;        /* diagnostica: bit8 azzerato dalla race (atteso ~sempre) */
        uint8_t ch = (uint8_t)(d & 0xFF);
        int si = sym_idx(ch);
        if (si >= 0) {                        /* char di protocollo valido */
            g_got++;
            g_sym[si]++;
            ev_rx(ch);
            tone_enqueue(ch);
        } else {
            g_inv++;                          /* DATA[7:0] non valido: rumore o byte basso sporco */
            g_inv_last = ch;                  /* mostrato in stats come ivb= (decimale, sicuro) */
        }
    }
}

/* Riga di statistiche compatta (canale debug). Significato dei campi: vedi i contatori
 * in cima. Confronta got (catturati) con flk/inv (letture perse/sporche) per capire
 * quanto sono affidabili le letture OPEN WB; sym=na/nb/nc/nA/nB/nC = treno catturato. */
static void print_stats(void) {
    dbg_begin();
    dbg_str("t=");     put_u32(g_tick);
    dbg_str(" lp=");   put_u32(g_loops);
    dbg_str(" rxok="); put_u32(g_rxok);
    dbg_str(" got=");  put_u32(g_got);
    dbg_str(" inv=");  put_u32(g_inv);
    dbg_str(" ivb=");  put_u32((uint32_t)g_inv_last);
    dbg_str(" flk=");  put_u32(g_flk);
    dbg_str(" drp=");  put_u32(g_drp);
    dbg_str(" emt=");  put_u32(g_emt);
    dbg_str(" qhi=");  put_u32(g_qhi);
    dbg_str(" q=");    put_u32(q_count);
    dbg_str(" sym=");
    put_u32(g_sym[0]); uartext_putchar('/');
    put_u32(g_sym[1]); uartext_putchar('/');
    put_u32(g_sym[2]); uartext_putchar('/');
    put_u32(g_sym[3]); uartext_putchar('/');
    put_u32(g_sym[4]); uartext_putchar('/');
    put_u32(g_sym[5]);
    dbg_end();
    g_tick++;
}

/* |X_k_re| a 15 bit, come abs_mag() in VHDL (clamp 0x8000 -> 0x7FFF).
 * Legge dal buffer locale riempito via S0: bin -> burst k/26, parola k%26. */
static int fft_mag(int bin) {
    int burst = bin / 26, j = bin % 26;
    int16_t raw = (burst < NEED_BURSTS) ? (int16_t)fftbuf[burst][j] : 0;
    int m = (raw < 0) ? -(int)raw : (int)raw;
    if (m > 0x7FFF) m = 0x7FFF;
    return m;
}

/* Ritorna il char da emettere, 0 se nessuna rilevazione. Algoritmo intero identico
 * al process ST_EVAL/ST_DECIDE di audio_decoder.vhd. */
static char decode_frame(void) {
    int det[NCAND], beta[NCAND];
    for (int c = 0; c < NCAND; c++) {
        int k = CAND_BIN[c];
        int w[2 * WINR + 1];
        for (int i = 0; i <= 2 * WINR; i++) w[i] = fft_mag(k - WINR + i);
        int b = w[WINR], a = w[WINR - 1], g = w[WINR + 1];
        int localmax = (b >= w[0]) && (b >= w[1]) && (b >= w[2]) &&
                       (b >= w[4]) && (b >= w[5]) && (b >= w[6]);
        int d = 2 * b - a - g;                                   /* curvatura */
        long long diff = (long long)a - (long long)g;
        long long test = 8LL * (long long)d * (long long)(b - THRESHOLD) + diff * diff;
        det[c]  = (localmax && d > 0 && test > 0) ? 1 : 0;
        beta[c] = b;
    }
    /* dato piu' forte tra bit0(idx2)/bit1(idx3)/EOF(idx4) */
    int have = 0, dbeta = 0, dsym = 0;
    if (det[2] && beta[2] > dbeta) { dbeta = beta[2]; dsym = 0; have = 1; }
    if (det[3] && beta[3] > dbeta) { dbeta = beta[3]; dsym = 1; have = 1; }
    if (det[4] && beta[4] > dbeta) { dbeta = beta[4]; dsym = 2; have = 1; }
    /* carrier: master XOR slave (se entrambi, il piu' forte) */
    int use_master = 0;
    if      (det[0] && !det[1]) use_master = 1;
    else if (det[1] && !det[0]) use_master = 0;
    else if (det[0] &&  det[1]) use_master = (beta[0] >= beta[1]);
    if (have && (det[0] || det[1])) {
        int base = use_master ? 97 : 65;   /* 'a' master / 'A' slave */
        return (char)(base + dsym);
    }
    return 0;
}

/* ===== BRING-UP: stampa via la simpleuart NATIVA dell'IP (instradata su pin 17 nel
 * top: ser_tx -> uart_ext_tx). Serve a sapere se la CPU ESEGUE. La simpleuart e' a
 * 0x0300_0004 (clkdiv) e 0x0300_0008 (data): scrivere data manda 1 byte (la CPU
 * stalla finche' la UART lo accetta, flow control hw). Se vedi "CPU RUNS" -> la CPU
 * gira e il problema era la UART_GENERIC/OPEN WB. Metti 0 per il firmware completo. */
#define BRINGUP_SIMPLEUART 0   /* PRODUZIONE: emit + flash via bus (letture OK) */
#define BRINGUP_BUSUART 0
#define SU_CLKDIV (*(volatile uint32_t*)0x03000004u)
#define SU_DATA   (*(volatile uint32_t*)0x03000008u)

#if BRINGUP_SIMPLEUART
static void su_puts(const char *s) { while (*s) SU_DATA = (uint8_t)(*s++); }
#endif

int main(void) {
    uartext_init(CPU_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));

    /* banner sul canale debug. "r7" = marcatore versione: se lo vedi (e t= riparte da
     * 0 nelle stats) sai se/quando l'IP ha caricato QUESTO firmware o si e' riavviato. */
    dbg_line("[EFES] up r9 statusgate+lowbyte");

    /* FLASH: gestito in HARDWARE (flash_ctrl.vhd), non dalla CPU.
     * La CPU fa solo emit (TX -> PWM). Decode (RX) OFF: vedi #if 0 sotto. */

    uint32_t stats_t0 = rdcycle32();

    for (;;) {
        g_loops++;

        capture();           /* UART -> coda: NON bloccante, gating su STATUS */
        tone_player_tick();  /* FSM toni: NON bloccante                       */

        /* riga di statistiche ~1 volta al secondo (rdcycle, niente delay bloccante) */
        if ((uint32_t)(rdcycle32() - stats_t0) >= (uint32_t)CPU_HZ) {
            stats_t0 = rdcycle32();
            print_stats();
        }

#if 0
        /* RX/decode: a fine FFT, leggi i burst dalla FSM via S0, decodifica, emetti.
         * OFF finche' le letture SDRAM/OPEN WB non sono affidabili. */
        if (g_frame_ready) {
            g_frame_ready = 0;
            capture_bursts();
            char d = decode_frame();
            if (d) uartext_putchar(d);
        }
#endif
    }
    return 0;
}
