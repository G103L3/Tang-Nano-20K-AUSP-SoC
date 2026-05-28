/*! \file web_link.h
 * \brief Collegamento del MASTER alla dashboard web via WebSocket.
 *
 * L'ESP32 si connette in WiFi e apre un WebSocket verso il server relay (vedi
 * dashboard/server). Manda eventi (stato aggancio, traffico rx/tx, presenza) e
 * riceve comandi dalla dashboard (es. "chiedi presenza").
 *
 * Configurazione (override via build_flags in platformio.ini):
 *   WIFI_SSID, WIFI_PASS, WS_HOST, WS_PORT, WS_PATH, WS_USE_TLS.
 */
#ifndef WEB_LINK_H
#define WEB_LINK_H
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void web_link_init(void);   /* WiFi + apertura WebSocket (non bloccante) */
void web_link_tick(void);   /* da chiamare nel loop()                    */

/* push verso la dashboard (firme compatibili coi callback di protocol.h) */
void web_link_status(bool paired, int slave_id);
void web_link_event(const char *dir, const char *msg);
void web_link_presence(bool present);
void web_link_push_flashlog(void);

#ifdef __cplusplus
}
#endif
#endif /* WEB_LINK_H */
