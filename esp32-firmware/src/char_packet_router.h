/*! \file char_packet_router.h
 * \brief Instrada i pacchetti ai 3 canali (master/slave/config) e al protocol
 *        (porting dal reference C, invariato).
 */
#ifndef CHAR_PACKET_ROUTER_H
#define CHAR_PACKET_ROUTER_H
#include "char_packet.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CHANNEL_MASTER = 0,
    CHANNEL_SLAVE,
    CHANNEL_CONFIG
} ChannelType;

void char_packet_router_init(void);
void char_packet_router_route(ChannelType ch, const char *msg);
CharPacket *char_packet_router_get_output(ChannelType ch);

#ifdef __cplusplus
}
#endif
#endif /* CHAR_PACKET_ROUTER_H */
