/* main.cpp — NODO MASTER (hotspot), protocollo a OPCODE (DIARIO 2026-05-24).
 *
 * La FPGA fa l'audio (SPI->DMA->SDRAM->FFT->audio_decoder) e manda via UART i
 * simboli decodificati (A/B/C = carrier slave bit0/bit1/EOF). Questo ESP32 fa il
 * link layer a opcode + il ruolo master (registrazione, richiesta PIR).
 *
 * Console comandi via USB Serial (default): CONNS | PRES | ABORT | HELP.
 * Con -DUSE_BLYNK + credenziali: comandi via widget terminale Blynk (V1).
 */
#include <Arduino.h>
#include <string.h>
#include <strings.h>

#include "protocol.h"
#include "fpga_uart_link.h"
#include "web_link.h"

#ifdef USE_BLYNK
  #ifndef BLYNK_TEMPLATE_ID
  #define BLYNK_TEMPLATE_ID   "TMPLxxxxxxxx"
  #endif
  #ifndef BLYNK_TEMPLATE_NAME
  #define BLYNK_TEMPLATE_NAME "AUSP"
  #endif
  #ifndef BLYNK_AUTH_TOKEN
  #define BLYNK_AUTH_TOKEN    "PASTE_TOKEN"
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

static void handle_command(const char *input) {
    if (strcasecmp(input, "CONNS") == 0) {
        char list[96]; protocol_list_devices(list, sizeof(list)); out_msg(list);
    } else if (strcasecmp(input, "PRES") == 0) {
        protocol_request_presence();
    } else if (strcasecmp(input, "ABORT") == 0) {
        protocol_send_abort();
    } else if (strcasecmp(input, "HELP") == 0) {
        out_msg("Comandi: CONNS (lista) | PRES (chiedi presenza) | ABORT | HELP\n");
    } else {
        out_msg("Comando sconosciuto. HELP per la lista.\n");
    }
}

#ifndef USE_BLYNK
static void poll_serial_console(void) {
    static char line[64];
    static size_t n = 0;
    static unsigned long last_byte = 0;
    while (Serial.available()) {
        char c = (char)Serial.read();
        last_byte = millis();
        if (c == '\n' || c == '\r') { if (n) { line[n] = 0; handle_command(line); n = 0; } }
        else if (n < sizeof(line) - 1) { line[n++] = c; }
    }
    if (n > 0 && (millis() - last_byte) > 80) { line[n] = 0; handle_command(line); n = 0; }
}
#endif

void setup() {
    Serial.begin(115200);
    delay(300);
    fpga_uart_init();
    protocol_init(true);                 /* questo nodo e' il MASTER */
    protocol_set_message_callback(out_msg);

    /* dashboard web (WebSocket): WiFi + eventi verso il server relay */
    web_link_init();
    protocol_set_status_callback(web_link_status);
    protocol_set_event_callback(web_link_event);
    protocol_set_presence_callback(web_link_presence);
#ifdef USE_BLYNK
    Blynk.begin(BLYNK_AUTH_TOKEN, WIFI_SSID, WIFI_PASS);
    out_msg("=== ESP32 MASTER (opcode + Blynk) pronto ===\n");
#else
    Serial.println();
    Serial.println("=== ESP32 MASTER (codebook) pronto ===");
    Serial.println("Console: HELP per i comandi.");
#endif
}

void loop() {
    fpga_uart_tick();        /* FPGA -> simboli -> pattern -> protocol_on_pattern */
    protocol_tick();         /* retry SET                                     */
    web_link_tick();         /* WebSocket verso la dashboard                 */
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
