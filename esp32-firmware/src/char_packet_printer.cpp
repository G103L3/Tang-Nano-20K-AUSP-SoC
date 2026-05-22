/*! \file char_packet_printer.cpp
 * \brief Stampa pacchetto su USB serial (ESP32).
 */
#include <Arduino.h>
#include "char_packet_printer.h"

void char_packet_printer_print(const char *msg){
    Serial.println(msg);
}
