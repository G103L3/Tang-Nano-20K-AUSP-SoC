/*! \file char_packet_printer.h
 * \brief Stampa un pacchetto (porting dal reference C; su ESP32 va su Serial).
 */
#ifndef CHAR_PACKET_PRINTER_H
#define CHAR_PACKET_PRINTER_H
#ifdef __cplusplus
extern "C" {
#endif
void char_packet_printer_print(const char *msg);
#ifdef __cplusplus
}
#endif
#endif /* CHAR_PACKET_PRINTER_H */
