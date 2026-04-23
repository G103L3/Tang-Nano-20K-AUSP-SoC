#ifndef CHAR_PACKET_H
#define CHAR_PACKET_H

#include <stddef.h>
#include <stdbool.h>

#define CHAR_PACKET_BUFFER_SIZE 256
#define CHAR_PACKET_SEPARATOR   '|'

typedef struct {
    char   buffer[CHAR_PACKET_BUFFER_SIZE];
    size_t head;
    size_t tail;
    size_t count;
} CharPacket;

void   char_packet_init(CharPacket *cp);
bool   char_packet_push(CharPacket *cp, const char *msg);
bool   char_packet_pop(CharPacket *cp, char *out, size_t out_size);
size_t char_packet_count(const CharPacket *cp);

#endif
