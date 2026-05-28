/*! \file protocol.cpp
 * \brief Protocollo a CODEBOOK ALTERNATO — lato MASTER (hotspot). Vedi protocol.h / DIARIO.
 */
#include <Arduino.h>
#include <stdio.h>
#include <string.h>

#include "protocol.h"
#include "fpga_uart_link.h"
#include "flash_link.h"
#include "web_link.h"

/* ---------------- codebook a (primo_bit, lunghezza), max len 3 --------------
 * Il carrier identifica la direzione, quindi master->slave e slave->master
 * RIUSANO gli stessi (first,len). I messaggi RIPETUTI (richiesta/risposta
 * presenza) hanno len 2 = i piu' robusti. Le tabelle DEVONO combaciare con lo
 * slave (Project01Giunta/src/protocol.c): master TX = slave RX, e viceversa.
 *
 *   master -> slave (qui: TX)        slave -> master (qui: RX)
 *     REQ_PRESENCE = (0,2) "01"        PRESENCE_YES = (0,2) "01"
 *     SET          = (1,2) "10"        PRESENCE_NO  = (1,2) "10"
 *     ABORT        = (0,3) "010"       REQ          = (0,3) "010"
 *                                      OK           = (1,3) "101"
 */
typedef enum {
    MSG_NONE = -1,
    MSG_REQ,
    MSG_SET,
    MSG_OK,
    MSG_REQ_PRESENCE,
    MSG_PRESENCE_NO,
    MSG_PRESENCE_YES,
    MSG_ABORT
} msg_t;

/* msg -> pattern. Solo i messaggi che il MASTER trasmette (master->slave). */
static bool msg_to_pattern(msg_t m, int *first, int *len) {
    switch (m) {
        case MSG_REQ_PRESENCE: *first = 0; *len = 2; return true;
        case MSG_SET:          *first = 1; *len = 2; return true;
        case MSG_ABORT:        *first = 0; *len = 3; return true;
        default:                                     return false;
    }
}

/* pattern -> msg. Solo i messaggi che il MASTER riceve (slave->master). */
static msg_t pattern_to_msg(int first, int len, bool alt) {
    if (!alt) return MSG_NONE;
    switch (len) {
        case 2: return first ? MSG_PRESENCE_NO : MSG_PRESENCE_YES;
        case 3: return first ? MSG_OK          : MSG_REQ;
        default: return MSG_NONE;
    }
}

/* --------------------------------------------------------------------------- */

static bool hotspot = false;
static char my_id[5] = "0000";

/* registrazione (giocattolo: 1 solo slave, id sempre 1) */
static int  slave_id    = -1;
static bool slave_known = false;

/* retry del SET (canale master->slave lossy: ritrasmetto finche' arriva OK) */
static bool          awaiting_ack = false;
static unsigned long retry_at = 0;

/* retry della richiesta presenza (idem: ritrasmetto REQ_PRESENCE finche' non
 * arriva una risposta presenza, con un tetto di tentativi) */
static bool          awaiting_presence = false;
static unsigned long presence_retry_at = 0;
static int           presence_tries    = 0;
#define PRESENCE_RETRY_MS   8000UL
static int           presence_max_tries = 6;

static uint16_t      auto_presence_s = 0;
static unsigned long auto_at = 0;

static ProtocolMessageCallback  msg_cb      = NULL;
static ProtocolEventCallback    event_cb    = NULL;
static ProtocolStatusCallback   status_cb   = NULL;
static ProtocolPresenceCallback presence_cb = NULL;
static int                      last_present = -1;   /* -1 = sconosciuta */

static unsigned long retry_ms(void){ return 30000UL + (unsigned long)random(0, 10000); }

/* notifiche verso la dashboard (no-op se nessun callback registrato) */
static void emit_event(const char *dir, const char *msg){ if (event_cb) event_cb(dir, msg); }
static void emit_status(void){ if (status_cb) status_cb(slave_known, slave_id); }
static void emit_presence(int present){ last_present = present; if (presence_cb) presence_cb(present != 0); }

static void logf(const char *fmt, ...) {
    char buf[160];
    va_list ap; va_start(ap, fmt); vsnprintf(buf, sizeof(buf), fmt, ap); va_end(ap);
    Serial.print(buf);
    if (msg_cb) msg_cb(buf);
}

static void send_msg(msg_t m) {
    int f, l;
    if (msg_to_pattern(m, &f, &l)) fpga_uart_send_pattern(f, l);
}

void protocol_init(bool is_hotspot){
    hotspot = is_hotspot;
    strcpy(my_id, "0000");          /* il master e' 0000 */
    awaiting_ack = false;
    slave_known = false; slave_id = -1;
}

const char* protocol_device_id(void){ return my_id; }
void protocol_set_message_callback(ProtocolMessageCallback cb){ msg_cb = cb; }

/* invia il SET (id sempre 1, implicito nel messaggio) e arma il retry */
static void send_set(void){
    awaiting_ack = true;
    retry_at = millis() + retry_ms();
    logf("Invio SET (id=1)\n");
    emit_event("tx", "SET");
    flash_log_append(LOG_EVT, millis() / 1000, 1, "M:SET1");
    web_link_push_flashlog();
    send_msg(MSG_SET);
}

void protocol_on_pattern(int channel, int first_bit, int length, bool alternating){
    /* sul master arriva tutto dal carrier slave */
    if (channel != CH_SLAVE) return;

    msg_t m = pattern_to_msg(first_bit, length, alternating);
    switch (m) {
        case MSG_REQ:
            emit_event("rx", "REQ");
            flash_log_append(LOG_EVT, millis() / 1000, 0, "S:REQ");
            web_link_push_flashlog();
            /* idempotente: se sto gia' registrando, NON ri-assegnare (ritrasmetto
             * lo stesso SET finche' arriva l'OK). */
            if (!awaiting_ack) {
                logf("REQ ricevuto -> registro id=1\n");
                send_set();
            }
            break;

        case MSG_OK:
            emit_event("rx", "OK");
            if (awaiting_ack) {
                awaiting_ack = false;
                slave_id = 1; slave_known = true;
                logf("Nuovo dispositivo registrato con successo, id=%d\n", slave_id);
                emit_status();
                flash_log_append(LOG_EVT, millis() / 1000, (uint8_t)slave_id, "S:OK1");
                web_link_push_flashlog();
            }
            break;

        case MSG_PRESENCE_NO:
            logf("Presenza dallo slave: NO\n");
            emit_event("rx", "PRESENCE_NO");
            awaiting_presence = false;     /* risposta arrivata: stop retry */
            emit_presence(0);
            flash_log_append(LOG_EVT, millis() / 1000, 0, "S:PRES0");
            web_link_push_flashlog();
            break;
        case MSG_PRESENCE_YES:
            logf("Presenza dallo slave: SI\n");
            emit_event("rx", "PRESENCE_YES");
            awaiting_presence = false;     /* risposta arrivata: stop retry */
            emit_presence(1);
            flash_log_append(LOG_EVT, millis() / 1000, 1, "S:PRES1");
            web_link_push_flashlog();
            break;

        default:
            break;
    }
}

void protocol_tick(void){
    if (awaiting_ack && (long)(millis() - retry_at) > 0) {
        logf("Retry SET (id=1)\n");
        send_msg(MSG_SET);
        retry_at = millis() + retry_ms();
    }

    /* ritrasmetto REQ_PRESENCE finche' non arriva la risposta (o esaurisco i
     * tentativi): il canale master->slave perde simboli, una sola richiesta
     * spesso non passa. */
    if (awaiting_presence && (long)(millis() - presence_retry_at) > 0) {
        if (presence_tries >= presence_max_tries) {
            awaiting_presence = false;
            logf("Presenza: nessuna risposta dopo %d tentativi\n", presence_max_tries);
        } else {
            presence_tries++;
            logf("Retry REQ_PRESENCE (%d/%d)\n", presence_tries, presence_max_tries);
            emit_event("tx", "REQ_PRESENCE");
            send_msg(MSG_REQ_PRESENCE);
            presence_retry_at = millis() + PRESENCE_RETRY_MS;
        }
    }

    if (auto_presence_s > 0 && slave_known && !awaiting_presence &&
        (long)(millis() - auto_at) > 0) {
        auto_at = millis() + (unsigned long)auto_presence_s * 1000UL;
        protocol_request_presence();
    }
}

void protocol_set_presence_tries(int n){ if (n > 0) presence_max_tries = n; }
void protocol_set_auto_presence(uint16_t s){ auto_presence_s = s; auto_at = millis() + (unsigned long)s * 1000UL; }

void protocol_request_presence(void){
    if (!hotspot) return;
    logf("Invio REQ_PRESENCE\n");
    awaiting_presence = true;
    presence_tries    = 1;
    presence_retry_at = millis() + PRESENCE_RETRY_MS;
    emit_event("tx", "REQ_PRESENCE");
    flash_log_append(LOG_EVT, millis() / 1000, 0, "M:PRES?");
    web_link_push_flashlog();
    send_msg(MSG_REQ_PRESENCE);
}

void protocol_send_abort(void){
    if (!hotspot) return;
    logf("Invio ABORT\n");
    emit_event("tx", "ABORT");
    flash_log_append(LOG_EVT, millis() / 1000, 0, "M:ABORT");
    web_link_push_flashlog();
    send_msg(MSG_ABORT);
}

void protocol_list_devices(char *buf, size_t buflen){
    if (!buf || buflen == 0) return;
    if (slave_known) snprintf(buf, buflen, "Slave registrato: id=%d\n", slave_id);
    else             snprintf(buf, buflen, "Nessun dispositivo registrato :(\n");
}

void protocol_set_event_callback(ProtocolEventCallback cb){ event_cb = cb; }
void protocol_set_status_callback(ProtocolStatusCallback cb){ status_cb = cb; }
void protocol_set_presence_callback(ProtocolPresenceCallback cb){ presence_cb = cb; }

void protocol_publish_state(void){
    emit_status();
    if (presence_cb && last_present >= 0) presence_cb(last_present != 0);
}
