/*! \file protocol.cpp
 * \brief Link layer del protocollo. Porting dal reference C, con due differenze:
 *   1) niente movement sensor (su questa board non c'e'): i comandi applicativi
 *      vengono solo ACKati con OK.
 *   2) emissione: comprime in signal code binari e li manda alla FPGA via UART
 *      (fpga_uart_emit_codes) invece di suonare frequenze in I2S.
 */
#include <Arduino.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "protocol.h"
#include "command_dict.h"
#include "bit_output_packer.h"
#include "fpga_uart_link.h"

static unsigned long now_ms(void){ return millis(); }

static bool hotspot = false;
static char my_id[5] = "0000";
static char provisional_id[4] = "";
static unsigned int id_counter = 1;

#define MAX_DEVICES 16
#define RETRY_MS 20000

static char known_ids[MAX_DEVICES][5];
static size_t known_count = 0;

static char pending_cmd[64];
static char pending_dest[5];
typedef enum { PEND_NONE, PEND_CONFIG, PEND_MASTER, PEND_SLAVE } PendingType;
static PendingType pending_type = PEND_NONE;
static bool awaiting_ack = false;
static bool awaiting_response = false;
static unsigned long retry_interval = RETRY_MS;
static unsigned long retry_at = 0;

static ProtocolMessageCallback msg_cb = NULL;

static void log_recv(const char *msg){
    if(hotspot && msg_cb){
        char buf[128];
        snprintf(buf, sizeof(buf), "Segnale ricevuto: %s\n", msg);
        msg_cb(buf);
    }
}
static void log_send(const char *msg){
    if(hotspot && msg_cb){
        char buf[128];
        snprintf(buf, sizeof(buf), "Invio: %s\n", msg);
        msg_cb(buf);
    }
}

/* --- Emissione: testo -> signal code binari -> char alla FPGA --------------
 * role: 0=master, 1=slave, 2=config. Ritorna durata stimata (ms). */
static unsigned long send_codes(const char *msg, int role){
    log_send(msg);
    BitOutputPacker packer;
    bit_output_packer_init(&packer);
    unsigned long duration = 0;
    if(bit_output_packer_compress(&packer, msg)){
        duration = (unsigned long)packer.count * 100UL;   /* ~100 ms / code */
        fpga_uart_emit_codes(packer.codes, packer.count, role);
    }
    return duration;
}
static unsigned long send_master(const char *msg){ return send_codes(msg, 0); }
static unsigned long send_slave (const char *msg){ return send_codes(msg, 1); }
static unsigned long send_config(const char *msg){ return send_codes(msg, 2); }

static void register_device(const char *id){
    for(size_t i=0;i<known_count;i++){
        if(strcmp(known_ids[i], id) == 0) return;
    }
    if(known_count < MAX_DEVICES){
        strncpy(known_ids[known_count], id, 4);
        known_ids[known_count][4] = '\0';
        known_count++;
    }
}

static void assign_new_id(const char *pid){
    char new_id[5];
    snprintf(new_id, sizeof(new_id), "%04X", id_counter++ & 0xFFFF);
    char resp[64];
    snprintf(resp, sizeof(resp), "ID:%s{SET:%s}k{0000}", pid, new_id);
    unsigned long dur = send_config(resp);
    strncpy(pending_cmd, resp, sizeof(pending_cmd)-1);
    pending_cmd[sizeof(pending_cmd)-1] = '\0';
    strncpy(pending_dest, new_id, sizeof(pending_dest));
    pending_type = PEND_CONFIG;
    awaiting_ack = true;
    awaiting_response = false;
    retry_interval = dur + RETRY_MS;
    retry_at = now_ms() + retry_interval;
}

void protocol_init(bool is_hotspot){
    hotspot = is_hotspot;
    if(hotspot){
        strcpy(my_id, "0000");
    } else {
        unsigned long r = now_ms();
        srand((unsigned)r);
        int rid = rand()%900 + 100;
        snprintf(provisional_id, sizeof(provisional_id), "%03d", rid);
        char req[32];
        snprintf(req, sizeof(req), "{REQ}l{%s}", provisional_id);
        send_config(req);
    }
}

const char* protocol_device_id(void){ return my_id; }

static void handle_set(const char *dest, const char *value){
    if(!hotspot && strcmp(dest, provisional_id)==0){
        strncpy(my_id, value, sizeof(my_id));
        my_id[4] = '\0';
        char ack[64];
        snprintf(ack, sizeof(ack), "ID:0000{OK}k{%s}", my_id);
        send_config(ack);
    }
}

static void handle_ok(const char *src){
    if(hotspot){
        register_device(src);
        if(awaiting_ack && strcmp(src, pending_dest) == 0){
            awaiting_ack = false;
            PendingType prev = pending_type;
            pending_dest[0] = '\0';
            if(!awaiting_response) pending_type = PEND_NONE;
            if(prev == PEND_CONFIG){
                char buffer[128];
                snprintf(buffer, sizeof(buffer),
                         "Nuovo dispositivo registrato con successo, ID: %s", src);
                log_send(buffer);
            }
        }
    } else {
        if(awaiting_ack && strcmp(src, pending_dest) == 0){
            awaiting_ack = false;
            pending_type = PEND_NONE;
            pending_dest[0] = '\0';
        }
    }
}

void protocol_tick(void){
    unsigned long now = now_ms();
    if(awaiting_ack && now > retry_at){
        unsigned long dur = 0;
        switch(pending_type){
            case PEND_CONFIG: dur = send_config(pending_cmd); break;
            case PEND_MASTER: dur = send_master(pending_cmd); break;
            case PEND_SLAVE:  dur = send_slave(pending_cmd);  break;
            default: break;
        }
        retry_interval = dur + RETRY_MS;
        retry_at = now + retry_interval;
    } else if(awaiting_response && now > retry_at){
        unsigned long dur = send_master(pending_cmd);
        retry_interval = dur + RETRY_MS;
        retry_at = now + retry_interval;
    }
}

void protocol_handle_message(ChannelType ch, const char *msg){
    if(!msg) return;
    log_recv(msg);

    if(ch == CHANNEL_CONFIG){
        if(strncmp(msg, "{REQ}l{", 7) == 0){
            if(hotspot){
                char pid[4] = {0};
                sscanf(msg, "{REQ}l{%3[^}]}", pid);
                assign_new_id(pid);
            }
            return;
        }
        if(strncmp(msg, "ID:", 3) != 0) return;

        char dest[5] = {0};
        const char *dest_start = msg + 3;
        const char *dest_end = strchr(dest_start, '{');
        size_t dest_len = dest_end ? (size_t)(dest_end - dest_start) : 4;
        if(dest_len >= sizeof(dest)) dest_len = sizeof(dest) - 1;
        strncpy(dest, dest_start, dest_len);
        dest[dest_len] = '\0';

        const char *op_start = strchr(msg, '{');
        const char *op_end = op_start ? strchr(op_start+1, '}') : NULL;
        if(!op_start) return;
        if(!op_end) op_end = msg + strlen(msg);
        char op_buf[32];
        size_t op_len = (size_t)(op_end - op_start - 1);
        if(op_len >= sizeof(op_buf)) op_len = sizeof(op_buf)-1;
        strncpy(op_buf, op_start+1, op_len);
        op_buf[op_len] = '\0';

        const char *src_start = strchr(op_end+1, '{');
        const char *src_end = src_start ? strchr(src_start+1, '}') : NULL;
        char src[5] = {0};
        if(src_start){
            size_t src_len = src_end ? (size_t)(src_end - src_start -1) : strlen(src_start+1);
            if(src_len >= sizeof(src)) src_len = sizeof(src)-1;
            strncpy(src, src_start+1, src_len);
            src[src_len] = '\0';
        }

        char *colon = strchr(op_buf, ':');
        char value[32] = {0};
        if(colon){ *colon = '\0'; strncpy(value, colon+1, sizeof(value)-1); }

        Command cmd = command_from_string(op_buf);
        switch(cmd){
            case CMD_SET: handle_set(dest, value); break;
            case CMD_OK:  handle_ok(src); break;
            default: break;
        }
        return;
    }

    if(ch == CHANNEL_MASTER && !hotspot){
        if(strncmp(msg, "ID:", 3) != 0) return;
        char dest[5] = {0};
        const char *dest_start = msg + 3;
        const char *dest_end = strchr(dest_start, '{');
        size_t dest_len = dest_end ? (size_t)(dest_end - dest_start) : 4;
        if(dest_len >= sizeof(dest)) dest_len = sizeof(dest)-1;
        strncpy(dest, dest_start, dest_len);
        dest[dest_len] = '\0';
        bool broadcast = (strcmp(dest, "1111") == 0);
        if(strcmp(dest, my_id) != 0 && !broadcast) return;

        const char *op_start = strchr(msg, '{');
        const char *op_end = op_start ? strchr(op_start+1, '}') : NULL;
        if(!op_start) return;
        if(!op_end) op_end = msg + strlen(msg);
        char op_buf[32];
        size_t op_len = (size_t)(op_end - op_start - 1);
        if(op_len >= sizeof(op_buf)) op_len = sizeof(op_buf)-1;
        strncpy(op_buf, op_start+1, op_len);
        op_buf[op_len] = '\0';

        const char *src_start = strchr(op_end+1, '{');
        const char *src_end = src_start ? strchr(src_start+1, '}') : NULL;
        char src[5] = {0};
        if(src_start){
            size_t src_len = src_end ? (size_t)(src_end - src_start -1) : strlen(src_start+1);
            if(src_len >= sizeof(src)) src_len = sizeof(src)-1;
            strncpy(src, src_start+1, src_len);
            src[src_len] = '\0';
        }

        char *colon = strchr(op_buf, ':');
        char value[32] = {0};
        if(colon){ *colon = '\0'; strncpy(value, colon+1, sizeof(value)-1); }

        Command cmd = command_from_string(op_buf);
        if(cmd == CMD_OK){ handle_ok(src); return; }
        if(cmd == CMD_ABORT){ printf("[Debug] Abort from %s\n", src); return; }

        /* Comando applicativo generico: senza sensori, il nodo risponde OK.
         * (Nel reation originale qui c'era la rilevazione movimento.) */
        protocol_send_response("OK");
        return;
    }

    if(ch == CHANNEL_SLAVE && hotspot){
        if(strncmp(msg, "ID:", 3) != 0) return;
        char dest[5] = {0};
        const char *dest_start = msg + 3;
        const char *dest_end = strchr(dest_start, '{');
        size_t dest_len = dest_end ? (size_t)(dest_end - dest_start) : 4;
        if(dest_len >= sizeof(dest)) dest_len = sizeof(dest)-1;
        strncpy(dest, dest_start, dest_len);
        dest[dest_len] = '\0';
        if(strcmp(dest, "0000") != 0) return;

        const char *op_start = strchr(msg, '{');
        const char *op_end = op_start ? strchr(op_start+1, '}') : NULL;
        if(!op_start) return;
        if(!op_end) op_end = msg + strlen(msg);
        char op_buf[32];
        size_t op_len = (size_t)(op_end - op_start - 1);
        if(op_len >= sizeof(op_buf)) op_len = sizeof(op_buf)-1;
        strncpy(op_buf, op_start+1, op_len);
        op_buf[op_len] = '\0';
        char *colon = strchr(op_buf, ':');
        char value[32] = {0};
        if(colon){ *colon = '\0'; strncpy(value, colon+1, sizeof(value)-1); }

        const char *src_start = strchr(op_end+1, '{');
        const char *src_end = src_start ? strchr(src_start+1, '}') : NULL;
        char src[5] = {0};
        if(src_start){
            size_t src_len = src_end ? (size_t)(src_end - src_start -1) : strlen(src_start+1);
            if(src_len >= sizeof(src)) src_len = sizeof(src)-1;
            strncpy(src, src_start+1, src_len);
            src[src_len] = '\0';
        }

        Command cmd = command_from_string(op_buf);
        if(cmd == CMD_OK){ handle_ok(src); return; }
        if(awaiting_response && strcmp(src, pending_dest) == 0){
            awaiting_response = false;
            pending_type = PEND_NONE;
            pending_dest[0] = '\0';
        }
        if(msg_cb){
            char buf[128];
            snprintf(buf, sizeof(buf), "Risposta da %s: %s\n", src, value);
            msg_cb(buf);
        }
        return;
    }
}

void protocol_send_command(const char *dest_id, const char *operation){
    if(!hotspot) return;
    snprintf(pending_cmd, sizeof(pending_cmd), "ID:%s{%s}k{0000}", dest_id, operation);
    strncpy(pending_dest, dest_id, sizeof(pending_dest));
    pending_dest[4] = '\0';
    pending_type = PEND_MASTER;
    awaiting_ack = true;
    awaiting_response = false;
    unsigned long dur = send_master(pending_cmd);
    retry_interval = dur + RETRY_MS;
    retry_at = now_ms() + retry_interval;
}

void protocol_send_response(const char *operation){
    if(hotspot) return;
    snprintf(pending_cmd, sizeof(pending_cmd), "ID:0000{%s}k{%s}", operation, my_id);
    strncpy(pending_dest, "0000", sizeof(pending_dest));
    pending_type = PEND_SLAVE;
    awaiting_ack = true;
    awaiting_response = false;
    unsigned long dur = send_slave(pending_cmd);
    retry_interval = dur + RETRY_MS;
    retry_at = now_ms() + retry_interval;
}

void protocol_send_abort(void){
    if(!hotspot) return;
    char msg[64];
    snprintf(msg, sizeof(msg), "ID:1111{ABORT}k{0000}");
    send_master(msg);
    delay(50);
    send_master(msg);
}

void protocol_list_devices(char *buf, size_t buflen){
    if(!buf || buflen == 0) return;
    buf[0] = '\0';
    if(known_count == 0){
        strncpy(buf, "Nessun dispositivo collegato :(\n", buflen-1);
        buf[buflen-1] = '\0';
        return;
    }
    for(size_t i=0;i<known_count;i++){
        strncat(buf, known_ids[i], buflen - strlen(buf) - 1);
        strncat(buf, "\n", buflen - strlen(buf) - 1);
    }
}

void protocol_set_message_callback(ProtocolMessageCallback cb){
    msg_cb = cb;
}
