/*! \file char_packet_router.c
 * \author Gioele Giunta
 * \version 2.5
 * \since 2025
 * \brief Implementazione del modulo char packet router
 */

/* Librerie */
#include <string.h>

/* Headers specifici */
#include "char_packet_router.h"
#include "char_packet_printer.h"
#include "protocol.h"

static CharPacket master_out;
static CharPacket slave_out;
static CharPacket config_out;
/**
 * @brief Funzione char_packet_router_init.
 */

void char_packet_router_init(void){
    char_packet_init(&master_out);
    char_packet_init(&slave_out);
    char_packet_init(&config_out);
}

static CharPacket *output_for(ChannelType ch){
    switch(ch){
        case CHANNEL_MASTER: return &master_out;
        case CHANNEL_SLAVE:  return &slave_out;
        default:             return &config_out;
    }
}
/**
 * @brief Funzione char_packet_router_route.
 * @param ch Parametro ch.
 * @param msg Parametro msg.
 */

void char_packet_router_route(ChannelType ch, const char *msg){
    if(strchr(msg, '5') != NULL){
        char_packet_printer_print(msg);
    } else {
        CharPacket *out = output_for(ch);
        char_packet_push(out, msg);
        protocol_handle_message(ch, msg);
    }
}

CharPacket *char_packet_router_get_output(ChannelType ch){
    return output_for(ch);
}
