/*! \file char_packet_router.cpp
 * \brief Implementazione router (porting dal reference C, invariato).
 */
#include <string.h>
#include "char_packet_router.h"
#include "char_packet_printer.h"
#include "protocol.h"

static CharPacket master_out;
static CharPacket slave_out;
static CharPacket config_out;

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

void char_packet_router_route(ChannelType ch, const char *msg){
    /* (Rimosso il dirottamento "se contiene '5'": gli ID sono cifre e contengono
     * spesso '5', spediva i messaggi al printer invece che al protocollo.) */
    CharPacket *out = output_for(ch);
    char_packet_push(out, msg);
    protocol_handle_message(ch, msg);
}

CharPacket *char_packet_router_get_output(ChannelType ch){
    return output_for(ch);
}
