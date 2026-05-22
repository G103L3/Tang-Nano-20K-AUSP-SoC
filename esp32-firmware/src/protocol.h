/*! \file protocol.h
 * \brief Link layer del protocollo (porting dal reference C, SENZA la parte
 *        movement sensor che su questa board FPGA non esiste).
 *
 * Emissione adattata: invece di suonare frequenze (I2S), comprime il messaggio
 * in signal code binari (bit_output_packer) e li invia come char alla FPGA
 * (fpga_uart_emit_codes), che li emette via PWM.
 */
#ifndef PROTOCOL_H
#define PROTOCOL_H
#include <stdbool.h>
#include <stddef.h>
#include "char_packet_router.h"

#ifdef __cplusplus
extern "C" {
#endif

void protocol_init(bool is_hotspot);
void protocol_handle_message(ChannelType ch, const char *msg);
void protocol_tick(void);
const char* protocol_device_id(void);
void protocol_send_command(const char *dest_id, const char *operation);
void protocol_send_response(const char *operation);
void protocol_send_abort(void);
void protocol_list_devices(char *buf, size_t buflen);

typedef void (*ProtocolMessageCallback)(const char *msg);
void protocol_set_message_callback(ProtocolMessageCallback cb);

#ifdef __cplusplus
}
#endif
#endif /* PROTOCOL_H */
