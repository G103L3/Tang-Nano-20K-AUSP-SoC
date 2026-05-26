/*! \file web_link.cpp
 * \brief Client WebSocket del master verso la dashboard. Vedi web_link.h.
 */
#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsClient.h>

#include "web_link.h"
#include "protocol.h"

/* ---- configurazione (override via build_flags) ---- */
#ifndef WIFI_SSID
#define WIFI_SSID "iPhone di Gioele"
#endif
#ifndef WIFI_PASS
#define WIFI_PASS "nf130900$"
#endif
#ifndef WS_HOST
#define WS_HOST "efes-relay.giuntagioele0.workers.dev"   /* Cloudflare Worker relay */
#endif
#ifndef WS_PORT
#define WS_PORT 443
#endif
#ifndef WS_PATH
#define WS_PATH "/"
#endif
#ifndef WS_USE_TLS
#define WS_USE_TLS 1             /* Cloudflare e' solo wss:// (TLS) */
#endif

static WebSocketsClient ws;

static void send_json(const char *json) {
    ws.sendTXT(json);            /* no-op se non connesso */
}

/* comandi in arrivo dalla dashboard: parsing minimale (protocollo fisso) */
static void on_command(const char *payload) {
    if (strstr(payload, "request_presence")) {
        protocol_request_presence();
    } else if (strstr(payload, "\"abort\"")) {
        protocol_send_abort();
    }
}

static void on_ws_event(WStype_t type, uint8_t *payload, size_t length) {
    switch (type) {
        case WStype_CONNECTED:
            Serial.println("[web] WebSocket connesso");
            send_json("{\"t\":\"hello\",\"role\":\"device\"}");
            protocol_publish_state();   /* riallinea subito la dashboard */
            break;
        case WStype_DISCONNECTED:
            Serial.println("[web] WebSocket disconnesso");
            break;
        case WStype_TEXT: {
            char buf[160];
            size_t n = (length < sizeof(buf) - 1) ? length : sizeof(buf) - 1;
            memcpy(buf, payload, n); buf[n] = 0;
            on_command(buf);
            break;
        }
        default:
            break;
    }
}

void web_link_init(void) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    /* Riduce il picco di corrente della radio (~da 19.5 a 11 dBm): aiuta su
     * alimentazioni deboli a non far scattare il brownout. La vera cura resta
     * comunque alimentare l'ESP32 da una USB/5V solidi. */
    WiFi.setTxPower(WIFI_POWER_11dBm);
    Serial.printf("[web] WiFi: connessione a \"%s\"...\n", WIFI_SSID);

#if WS_USE_TLS
    ws.beginSSL(WS_HOST, WS_PORT, WS_PATH);
#else
    ws.begin(WS_HOST, WS_PORT, WS_PATH);
#endif
    ws.onEvent(on_ws_event);
    ws.setReconnectInterval(3000);   /* riprova ogni 3 s finche' WiFi/WS non sono su */
}

void web_link_tick(void) {
    ws.loop();
}

/* ---- push verso la dashboard ---- */
void web_link_status(bool paired, int slave_id) {
    char j[80];
    snprintf(j, sizeof(j), "{\"t\":\"status\",\"paired\":%s,\"slave_id\":%d}",
             paired ? "true" : "false", slave_id);
    send_json(j);
}

void web_link_event(const char *dir, const char *msg) {
    char j[96];
    snprintf(j, sizeof(j), "{\"t\":\"event\",\"dir\":\"%s\",\"msg\":\"%s\"}", dir, msg);
    send_json(j);
}

void web_link_presence(bool present) {
    char j[48];
    snprintf(j, sizeof(j), "{\"t\":\"presence\",\"present\":%s}", present ? "true" : "false");
    send_json(j);
}
