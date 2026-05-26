/*! \file protocol.h
 * \brief Protocollo a CODEBOOK ALTERNATO — lato MASTER (hotspot).
 *        Ogni messaggio = pattern di bit STRETTAMENTE alternati, identificato da
 *        (primo_bit, lunghezza). Nessun simbolo uguale di fila => ogni simbolo e'
 *        un cambio di frequenza, robusto al riverbero. Il canale (master/slave)
 *        e' dato dal carrier. Vedi DIARIO.
 *
 *  msg            primo_bit  lunghezza  pattern   direzione
 *  REQ                0          2        01      slave  -> master
 *  SET                1          2        10      master -> slave (= registrato, id=1)
 *  OK                 0          3        010     ack
 *  REQ_PRESENCE       1          3        101     master -> slave
 *  PRESENCE_NO        0          4        0101    slave  -> master
 *  PRESENCE_YES       1          4        1010    slave  -> master
 *  ABORT              0          5        01010   master -> slave
 */
#ifndef PROTOCOL_H
#define PROTOCOL_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* canale (= carrier del mittente) */
#define CH_MASTER 0
#define CH_SLAVE  1

#ifdef __cplusplus
extern "C" {
#endif

void protocol_init(bool is_hotspot);
void protocol_tick(void);

/* chiamata dal link layer all'arrivo di un pattern completo (tra due EOF). */
void protocol_on_pattern(int channel, int first_bit, int length, bool alternating);

/* API applicative */
void protocol_request_presence(void);   /* master -> slave: chiedi PIR */
void protocol_send_abort(void);
void protocol_list_devices(char *buf, size_t buflen);
const char* protocol_device_id(void);

typedef void (*ProtocolMessageCallback)(const char *msg);
void protocol_set_message_callback(ProtocolMessageCallback cb);

/* Eventi strutturati per la dashboard web (vedi web_link). */
typedef void (*ProtocolEventCallback)(const char *dir, const char *msg); /* dir: "rx"|"tx" */
typedef void (*ProtocolStatusCallback)(bool paired, int slave_id);
typedef void (*ProtocolPresenceCallback)(bool present);
void protocol_set_event_callback(ProtocolEventCallback cb);
void protocol_set_status_callback(ProtocolStatusCallback cb);
void protocol_set_presence_callback(ProtocolPresenceCallback cb);
/* Re-emette stato di aggancio + ultima presenza nota (chiamata alla connessione
 * della dashboard, cosi' la pagina si popola subito). */
void protocol_publish_state(void);

#ifdef __cplusplus
}
#endif
#endif /* PROTOCOL_H */
