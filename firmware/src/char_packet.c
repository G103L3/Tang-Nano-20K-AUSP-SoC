#include <string.h>
#include "char_packet.h"

static size_t advance(size_t index, size_t n) {
    return (index + n) % CHAR_PACKET_BUFFER_SIZE;
}

void char_packet_init(CharPacket *cp) {
    cp->head = cp->tail = cp->count = 0;
    memset(cp->buffer, 0, sizeof(cp->buffer));
}

static bool has_space(const CharPacket *cp, size_t len) {
    size_t free_space = (cp->head <= cp->tail)
        ? (CHAR_PACKET_BUFFER_SIZE - cp->tail + cp->head)
        : (cp->head - cp->tail);
    return free_space > len;
}

bool char_packet_push(CharPacket *cp, const char *msg) {
    size_t len = strlen(msg);
    if (!has_space(cp, len + 1)) return false;
    for (size_t i = 0; i < len; i++) {
        cp->buffer[cp->tail] = msg[i];
        cp->tail = advance(cp->tail, 1);
    }
    cp->buffer[cp->tail] = CHAR_PACKET_SEPARATOR;
    cp->tail = advance(cp->tail, 1);
    cp->count++;
    return true;
}

bool char_packet_pop(CharPacket *cp, char *out, size_t out_size) {
    if (cp->count == 0) return false;
    size_t idx = 0;
    while (cp->head != cp->tail && cp->buffer[cp->head] != CHAR_PACKET_SEPARATOR) {
        if (idx + 1 < out_size) out[idx++] = cp->buffer[cp->head];
        cp->head = advance(cp->head, 1);
    }
    if (cp->buffer[cp->head] == CHAR_PACKET_SEPARATOR)
        cp->head = advance(cp->head, 1);
    out[idx] = '\0';
    cp->count--;
    return true;
}

size_t char_packet_count(const CharPacket *cp) {
    return cp->count;
}
