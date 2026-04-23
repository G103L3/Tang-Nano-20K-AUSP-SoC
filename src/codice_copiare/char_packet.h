/*! \file char_packet.h
 * \author Gioele Giunta
 * \version 1.5
 * \since 2025
 * \brief Interfaccia del modulo char packet
 */

#ifndef CHAR_PACKET_H
#define CHAR_PACKET_H
/* Librerie */
#include <stddef.h>
#include <stdbool.h>

#define CHAR_PACKET_BUFFER_SIZE 256
#define CHAR_PACKET_SEPARATOR '|'

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char buffer[CHAR_PACKET_BUFFER_SIZE];
    size_t head;  /* index of next byte to read */
    size_t tail;  /* index of next free byte */
    size_t count; /* number of complete packets stored */
} CharPacket;

void char_packet_init(CharPacket *cp);
bool char_packet_push(CharPacket *cp, const char *msg);
bool char_packet_pop(CharPacket *cp, char *out, size_t out_size);
size_t char_packet_count(const CharPacket *cp);

#ifdef __cplusplus
}
#endif

#endif /* CHAR_PACKET_H */
