#include "char_packet_router.h"
#include "uart_iface.h"

void char_packet_router_init(void) {}

void char_packet_router_route(ChannelType ch, const char *msg) {
    (void)ch;
    uart_tx_string(msg);
    uart_tx_char('\n');
}
