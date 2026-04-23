/*! \file char_packet_printer.c
 * \author Gioele Giunta
 * \version 1.6
 * \since 2025
 * \brief Implementazione del modulo char packet printer
 */

/* Librerie */
#include <stdio.h>

/* Headers specifici */
#include "char_packet_printer.h"
/**
 * @brief Funzione char_packet_printer_print.
 * @param msg Parametro msg.
 */

void char_packet_printer_print(const char *msg){
    printf("%s\n", msg);
}
