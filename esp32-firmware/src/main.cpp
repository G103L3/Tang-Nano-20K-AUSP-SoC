/* main.cpp — NODO MASTER (hotspot) del protocollo acustico AUSP, versione FPGA.
 *
 * Architettura (versione giocattolo a 2 dispositivi, vedi DIARIO):
 *   - La FPGA fa tutto l'audio: SPI ADC -> DMA -> SDRAM -> FFT -> audio_decoder.
 *     Il decoder manda via UART i CHAR gia' decodificati (minuscoli = carrier
 *     master/bin22, MAIUSCOLI = carrier slave/bin27).
 *   - Questo ESP32 fa SOLO il link layer + il ruolo MASTER:
 *       RX: char dalla FPGA -> bit_input_packer -> ascii -> router -> protocol
 *       TX: comandi -> bit_output_packer -> char -> FPGA (che emette i toni)
 *   - Niente config carrier: con 2 dispositivi la registrazione viaggia sui
 *     carrier rispettivi (master->master, slave->slave). Vedi protocol.cpp.
 *
 * Lo SLAVE e' un secondo dispositivo (ESP32+speaker col firmware originale
 * Project01Giunta in modo non-hotspot, riconfigurato con la nostra mappa).
 *
 * Console comandi:
 *   - Default: via USB Serial (digita "CONNS", "ABORT", "SET->0001", ...).
 *   - Con -DUSE_BLYNK + credenziali: via app Blynk (widget terminale su V1).
 */
#include <Arduino.h>
#include <string.h>
#include <strings.h>   /* strcasecmp */

#include "global_parameters.h"
#include "char_packet_router.h"
#include "protocol.h"
#include "fpga_uart_link.h"
#include "bit_input_packer.h"
#include "command_dict.h"

/* ----------------------------- Output console ----------------------------- */
#ifdef USE_BLYNK
  /* Definisci questi 3 + le credenziali WiFi nei build_flags o qui sotto. */
  #ifndef BLYNK_TEMPLATE_ID
  #define BLYNK_TEMPLATE_ID   "TMPLxxxxxxxx"
  #endif
  #ifndef BLYNK_TEMPLATE_NAME
  #define BLYNK_TEMPLATE_NAME "AUSP"
  #endif
  #ifndef BLYNK_AUTH_TOKEN
  #define BLYNK_AUTH_TOKEN    "PASTE_TOKEN_HERE"
  #endif
  #include <WiFi.h>
  #include <BlynkSimpleEsp32.h>
  #ifndef WIFI_SSID
  #define WIFI_SSID "PASTE_SSID"
  #endif
  #ifndef WIFI_PASS
  #define WIFI_PASS "PASTE_PASS"
  #endif
  static void out_msg(const char *m){ Blynk.virtualWrite(V1, m); }
#else
  static void out_msg(const char *m){ Serial.print(m); }
#endif

/* ------------------- Comando da console -> protocollo --------------------- */
static void handle_command(const char *input) {
    /* Scorciatoia bring-up: un singolo char di protocollo (a..q / A..Q) viene
     * inviato GREZZO alla FPGA (come la vecchia modalita' bridge), per testare
     * il path TX FPGA senza passare dal protocollo. */
    if (input[0] && input[1] == '\0' &&
        ((input[0] >= 'a' && input[0] <= 'q') || (input[0] >= 'A' && input[0] <= 'Q'))) {
        fpga_uart_send_char(input[0]);
        out_msg("char grezzo -> FPGA\n");
        return;
    }
    if (strcasecmp(input, "CONNS") == 0) {
        char list[160];
        protocol_list_devices(list, sizeof(list));
        out_msg(list);
        return;
    }
    if (strcasecmp(input, "ABORT") == 0) {
        protocol_send_abort();
        out_msg("ABORT inviato\n");
        return;
    }
    if (strcasecmp(input, "HELP") == 0) {
        out_msg("Comandi: CONNS | ABORT | <OP>-><ID>  (es. SET->0001, OK->0001)\n");
        return;
    }
    /* formato "<OP>-><ID>" : invia un comando a un dispositivo */
    const char *arrow = strstr(input, "->");
    if (arrow) {
        char op[32]   = {0};
        char dest[8]  = {0};
        size_t oplen  = (size_t)(arrow - input);
        if (oplen >= sizeof(op)) oplen = sizeof(op) - 1;
        strncpy(op, input, oplen);
        strncpy(dest, arrow + 2, sizeof(dest) - 1);
        if (command_from_string(op) != CMD_UNKNOWN) {
            protocol_send_command(dest, op);
            out_msg("Comando inviato\n");
        } else {
            out_msg("Operazione sconosciuta (HELP per la lista)\n");
        }
        return;
    }
    out_msg("Formato non valido. HELP per la lista.\n");
}

#ifndef USE_BLYNK
static void poll_serial_console(void) {
    static char line[64];
    static size_t n = 0;
    static unsigned long last_byte_ms = 0;
    while (Serial.available()) {
        char c = (char)Serial.read();
        last_byte_ms = millis();
        if (c == '\n' || c == '\r') {
            if (n) { line[n] = '\0'; handle_command(line); n = 0; }
        } else if (n < sizeof(line) - 1) {
            line[n++] = c;
        }
    }
    /* Flush per monitor che NON manda newline (line ending = None): se sono
     * arrivati byte ma da >80 ms non ne arrivano altri, processo comunque. */
    if (n > 0 && (millis() - last_byte_ms) > 80) {
        line[n] = '\0';
        handle_command(line);
        n = 0;
    }
}
#endif

/* --------- Pacchetti ASCII pronti (dal packer) -> router -> protocol ------ */
static void process_ready_packets(void) {
    char buffer[ASCII_PACKET_SIZE];

    /* Il master riceve i messaggi dello slave sul carrier slave (MAIUSCOLI). */
    if (slave_ascii_ready) {
        size_t idx = 0;
        for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++)
            for (size_t j = 0; j < ASCII_ARRAY_SIZE && slave_ascii_arrays[i][j]; j++)
                buffer[idx++] = slave_ascii_arrays[i][j];
        buffer[idx] = '\0';
        char_packet_router_route(CHANNEL_SLAVE, buffer);
        slave_ascii_ready = false;
    }
    /* Loopback acustico del proprio TX (carrier master): scartato. */
    if (master_ascii_ready) master_ascii_ready = false;
    if (config_ascii_ready) config_ascii_ready = false;
}

void setup() {
    Serial.begin(115200);
    delay(300);

    fpga_uart_init();
    char_packet_router_init();
    protocol_init(true);                 /* QUESTO nodo e' il MASTER (hotspot) */
    protocol_set_message_callback(out_msg);

#ifdef USE_BLYNK
    Blynk.begin(BLYNK_AUTH_TOKEN, WIFI_SSID, WIFI_PASS);
    out_msg("=== ESP32 MASTER (FPGA + Blynk) pronto ===\n");
#else
    Serial.println();
    Serial.println("=== ESP32 MASTER (FPGA) pronto ===");
    Serial.println("Console comandi via USB. Digita HELP.");
#endif
}

void loop() {
    fpga_uart_tick();          /* FPGA -> char -> bit_input_packer            */
    process_ready_packets();   /* packer -> char_packet_router -> protocol    */
    protocol_tick();           /* retry / timeout del protocollo              */

#ifdef USE_BLYNK
    Blynk.run();
#else
    poll_serial_console();
#endif
}

#ifdef USE_BLYNK
BLYNK_WRITE(V1) {
    String input = param.asStr();
    handle_command(input.c_str());
}
#endif
