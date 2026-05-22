/* main.cpp — FASE CALIBRAZIONE
 *
 * In questa fase la FPGA gira con audio_decoder DEBUG_MODE=true e manda righe
 * di testo hex via UART. L'ESP32 fa solo da bridge: inoltra ogni byte ricevuto
 * dalla FPGA (Serial2 RX) verso la USB serial, cosi' puoi leggerle nel monitor.
 *
 * Formato riga FPGA: "N<nf4> G<gb2>:<gm4> M<mb2>:<mm4> S<sb2>:<sm4>\r\n"
 *   nf = noise floor (media bin),  G = picco globale (bin:mag),
 *   M  = picco finestra master (bin 86-88),  S = picco finestra signal (9-85).
 *
 * Quando avremo calibrato soglie/range, passeremo DEBUG_MODE=false sulla FPGA
 * e questo main.cpp diventera' il firmware completo (protocol + Blynk).
 */
#include <Arduino.h>

#ifndef FPGA_UART_BAUD
#define FPGA_UART_BAUD   115200
#endif
#ifndef FPGA_UART_RX_PIN
#define FPGA_UART_RX_PIN 27
#endif
#ifndef FPGA_UART_TX_PIN
#define FPGA_UART_TX_PIN 14
#endif

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial2.begin(FPGA_UART_BAUD, SERIAL_8N1, FPGA_UART_RX_PIN, FPGA_UART_TX_PIN);
    Serial.println();
    Serial.println("=== ESP32 <- FPGA DEBUG BRIDGE ===");
    Serial.printf("Serial2 RX=%d TX=%d @ %d baud\n",
                  FPGA_UART_RX_PIN, FPGA_UART_TX_PIN, FPGA_UART_BAUD);
    Serial.println("In attesa di righe dal decoder FPGA...");
}

void loop() {
    // FPGA -> USB: righe di debug del decoder
    while (Serial2.available()) {
        Serial.write(Serial2.read());
    }
    // USB -> FPGA: i char che digiti nel monitor vanno alla FSM TX della FPGA
    // (es. 'a' = master Z1 -> emette carrier 2000 Hz + tono 3200 Hz).
    while (Serial.available()) {
        Serial2.write(Serial.read());
    }
}
