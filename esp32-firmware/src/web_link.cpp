/*! \file web_link.cpp
 * \brief Client WebSocket del master verso la dashboard. Vedi web_link.h.
 */
#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>

#include "web_link.h"
#include "protocol.h"
#include "flash_link.h"

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

static void send_settings(void) {
    flash_settings_t s;
    if (!flash_get_settings(&s)) return;
    JsonDocument d;
    d["t"]     = "settings";
    d["name"]  = s.name;
    d["auto"]  = s.auto_presence_s;
    d["tries"] = s.presence_tries;
    String out; serializeJson(d, out);
    ws.sendTXT(out);
}

static void send_flash_log(void) {
    int head = flash_log_head();
    JsonDocument d;
    d["t"] = "flashlog";
    JsonArray arr = d["recs"].to<JsonArray>();

    uint16_t seen_seq[60];
    int      nseen = 0;

    /* 1) NOR via FPGA: lettura a ritroso da head-1 scorrendo TUTTI gli slot.
     *    Skippa i 0xFF (slot erased) e i garbage da retry falliti senza
     *    fermarsi: gli slot validi possono essere sparpagliati su sessioni
     *    diverse con buchi in mezzo. Stop solo a 60 record o 512 slot
     *    visitati. Validi = byte 2 in {B,R,P,N,E}. */
    if (head >= 0) {
        uint8_t rec[FLASH_REC_BYTES];
        for (int k = 1; k <= FLASH_N_SLOTS && nseen < 60; k++) {
            int slot = (head - k + FLASH_N_SLOTS) % FLASH_N_SLOTS;
            if (flash_log_read(slot, 1, rec) != FLASH_REC_BYTES) continue;
            uint8_t t = rec[2];
            if (t != 'B' && t != 'R' && t != 'P' && t != 'N' && t != 'E') continue;
            JsonObject o = arr.add<JsonObject>();
            char ty[2] = { (char)t, 0 };
            char txt[9]; memcpy(txt, &rec[8], 8); txt[8] = 0;
            uint16_t seq = ((uint16_t)rec[0] << 8) | rec[1];
            o["seq"]  = seq;
            o["type"] = ty;
            o["t"]    = ((uint32_t)rec[3] << 24) | ((uint32_t)rec[4] << 16) |
                        ((uint32_t)rec[5] << 8) | rec[6];
            o["val"]  = rec[7];
            o["text"] = txt;
            seen_seq[nseen++] = seq;
        }
    }

    /* 2) Cache RAM ESP32: aggiungi i record di questa sessione che NON sono
     *    gia' presenti dalla NOR (dedup per seq). Sopravvive ai refresh della
     *    dashboard ma non al reboot dell'ESP32. */
    flash_cache_rec_t cr[60];
    int cn = flash_cache_get(cr, 60);
    for (int i = 0; i < cn && nseen < 60; i++) {
        bool dup = false;
        for (int j = 0; j < nseen; j++) {
            if (seen_seq[j] == cr[i].seq) { dup = true; break; }
        }
        if (dup) continue;
        JsonObject o = arr.add<JsonObject>();
        char ty[2] = { (char)cr[i].type, 0 };
        o["seq"]  = cr[i].seq;
        o["type"] = ty;
        o["t"]    = cr[i].t_sec;
        o["val"]  = cr[i].val;
        o["text"] = cr[i].text;
        seen_seq[nseen++] = cr[i].seq;
    }

    String out; serializeJson(d, out);
    ws.sendTXT(out);
}

static void send_flash_ok(const char *op) {
    JsonDocument d;
    d["t"]  = "flashok";
    d["op"] = op;
    String out; serializeJson(d, out);
    ws.sendTXT(out);
}

static void on_command(const char *payload) {
    JsonDocument d;
    DeserializationError jerr = deserializeJson(d, payload);
    if (jerr) {
        Serial.printf("[web] JSON parse err: %s\n", jerr.c_str());
        return;
    }
    const char *cmd = d["cmd"] | "";
    Serial.printf("[web] cmd: %s\n", cmd);

    if (!strcmp(cmd, "request_presence")) {
        protocol_request_presence();
    } else if (!strcmp(cmd, "abort")) {
        protocol_send_abort();
    } else if (!strcmp(cmd, "flash_load")) {
        send_flash_log();
    } else if (!strcmp(cmd, "flash_clear")) {
        bool ok = flash_log_clear();
        Serial.printf("[web] flash_clear -> %s\n", ok ? "OK" : "FAIL");
        send_flash_ok("clear");
        send_flash_log();
    } else if (!strcmp(cmd, "flash_note")) {
        const char *t = d["text"] | "";
        bool ok = flash_log_append(LOG_NOTE, millis() / 1000, 0, t);
        Serial.printf("[web] flash_note '%s' -> %s\n", t, ok ? "OK" : "FAIL");
        send_flash_ok("note");
        send_flash_log();
    } else if (!strcmp(cmd, "settings_get")) {
        send_settings();
    } else if (!strcmp(cmd, "settings_set")) {
        flash_settings_t s;
        const char *nm = d["name"] | "Master EFES";
        strncpy(s.name, nm, 15); s.name[15] = 0;
        s.auto_presence_s = d["auto"]  | 0;
        s.presence_tries  = d["tries"] | 6;
        Serial.printf("[web] settings_set name='%s' auto=%u tries=%u\n",
                      s.name, s.auto_presence_s, s.presence_tries);
        bool ok = flash_set_settings(&s);
        Serial.printf("[web] flash_set_settings -> %s\n", ok ? "OK" : "FAIL");
        protocol_set_presence_tries(s.presence_tries);
        protocol_set_auto_presence(s.auto_presence_s);
        send_settings();
    } else {
        Serial.printf("[web] cmd sconosciuto: '%s'\n", cmd);
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
            Serial.printf("[web] RX (%u): %s\n", (unsigned)length, buf);
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

void web_link_push_flashlog(void) {
    send_flash_log();
}
