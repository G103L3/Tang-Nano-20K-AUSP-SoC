#ifndef CHAR_PACKET_ROUTER_H
#define CHAR_PACKET_ROUTER_H

#include "char_packet.h"

typedef enum {
    CHANNEL_MASTER = 0,
    CHANNEL_SLAVE,
    CHANNEL_CONFIG
} ChannelType;

void char_packet_router_init(void);
void char_packet_router_route(ChannelType ch, const char *msg);

#endif
