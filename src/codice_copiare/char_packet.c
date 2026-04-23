/*! \file char_packet.c
 * \author Gioele Giunta
 * \version 3.0
 * \since 2025
 * \brief Implementazione del modulo char packet
 */

/* Librerie */
#include <string.h>

/* Headers specifici */
#include "char_packet.h"
/**
 * @brief Funzione advance.
 * @param index Parametro index.
 * @param n Parametro n.
 * @return Valore di ritorno.
 */

static size_t advance(size_t index, size_t n){
    return (index + n) % CHAR_PACKET_BUFFER_SIZE;
}
/**
 * @brief Funzione char_packet_init.
 * @param cp Parametro cp.
 */

void char_packet_init(CharPacket *cp){
    cp->head = cp->tail = cp->count = 0;
    memset(cp->buffer, 0, sizeof(cp->buffer));
}
/**
 * @brief Funzione has_space.
 * @param cp Parametro cp.
 * @param len Parametro len.
 * @return Valore di ritorno.
 */

static bool has_space(const CharPacket *cp, size_t len){
    size_t free_space = (cp->head <= cp->tail)
        ? (CHAR_PACKET_BUFFER_SIZE - cp->tail + cp->head)
        : (cp->head - cp->tail);
    return free_space > len;
}
/**
 * @brief Funzione char_packet_push.
 * @param cp Parametro cp.
 * @param msg Parametro msg.
 * @return Valore di ritorno.
 */

bool char_packet_push(CharPacket *cp, const char *msg){
    size_t len = strlen(msg);
    /* need len bytes plus separator */
    if(!has_space(cp, len + 1))
        return false;
    for(size_t i=0;i<len;i++){
        cp->buffer[cp->tail] = msg[i];
        cp->tail = advance(cp->tail,1);
    }
    cp->buffer[cp->tail] = CHAR_PACKET_SEPARATOR;
    cp->tail = advance(cp->tail,1);
    cp->count++;
    return true;
}
/**
 * @brief Funzione char_packet_pop.
 * @param cp Parametro cp.
 * @param out Parametro out.
 * @param out_size Parametro out_size.
 * @return Valore di ritorno.
 */

bool char_packet_pop(CharPacket *cp, char *out, size_t out_size){
    if(cp->count==0)
        return false;
    size_t idx = 0;
    while(cp->head != cp->tail && cp->buffer[cp->head] != CHAR_PACKET_SEPARATOR){
        if(idx + 1 < out_size){
            out[idx++] = cp->buffer[cp->head];
        }
        cp->head = advance(cp->head,1);
    }
    if(cp->buffer[cp->head] == CHAR_PACKET_SEPARATOR){
        cp->head = advance(cp->head,1);
    }
    out[idx] = '\0';
    cp->count--;
    return true;
}
/**
 * @brief Funzione char_packet_count.
 * @param cp Parametro cp.
 * @return Valore di ritorno.
 */

size_t char_packet_count(const CharPacket *cp){
    return cp->count;
}
