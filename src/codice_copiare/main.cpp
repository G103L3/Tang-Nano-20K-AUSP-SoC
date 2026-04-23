/*! \file main.cpp
 * \brief File principale per ESP32 con acquisizione DMA
 */

 /* C Library Headers */
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
 
 /* Driver Headers */
#include <Arduino.h>
#include <math.h>
 
 /* Our Headers */
 #include "global_parameters.h"
 #include "complex_g3.h"
 #include "reader.h"
 #include "fft.h"
 #include "decoder.h"
#include "serial_bridge.h"
#include "leds.h"
#include "audio_driver.h"
#include "bit_freq_codec.h"
#include "bit_input_packer.h"
#include "bit_output_packer.h"
#include "char_packet_router.h"
#include "protocol.h"
#include "movement_sensor.h"
#include "command_dict.h"
//#include <HardwareSerial.h>
#include <WiFi.h>
#include <WiFiClient.h>
 
#include "emit_tones.h"
 
extern "C" {
    #include "global_parameters.h"
}

static BitOutputPacker out_packer;
static struct_out_tones* out_pairs = NULL;
static size_t out_len = 0;
static bool message_sent = false;

bool hotspot_mode = false;

// Blynk
 //Blynk Data
 #define BLYNK_AUTH            "RonJtq8yYARwRVRVgrYYurO-UzhyENr8"
 #define BLYNK_TEMPLATE_ID     "TMPL4tHCnjG_H"
 #define BLYNK_TEMPLATE_NAME   "AUSP"
#include <BlynkSimpleEsp32.h>


// WiFi
const char WIFI_SSID[] PROGMEM  = "iPhone di Gioele";
const char WIFI_PASS[]  PROGMEM = "nf130900$";

static void blynk_print(const char *msg){
    Blynk.virtualWrite(V1, msg);
}

static void wait_for_next_decasecond() {
    const uint32_t SLOT_MS = 10000;
    uint32_t now = millis();
    uint32_t remainder = now % SLOT_MS;
    uint32_t wait_ms = remainder ? (SLOT_MS - remainder) : 0;
    delay(wait_ms);
}

static void process_ready_packets(){
    char buffer[ASCII_PACKET_SIZE] = {0};
    if(master_ascii_ready){
        size_t idx=0;
        for(size_t i=0;i<ASCII_NUM_ARRAYS;i++){
            for(size_t j=0;j<ASCII_ARRAY_SIZE && master_ascii_arrays[i][j];j++){
                buffer[idx++] = master_ascii_arrays[i][j];
            }
        }
        buffer[idx]='\0';
        char_packet_router_route(CHANNEL_MASTER, buffer);
        master_ascii_ready=false;
    }
    if(slave_ascii_ready){
        size_t idx=0;
        for(size_t i=0;i<ASCII_NUM_ARRAYS;i++){
            for(size_t j=0;j<ASCII_ARRAY_SIZE && slave_ascii_arrays[i][j];j++){
                buffer[idx++] = slave_ascii_arrays[i][j];
            }
        }
        buffer[idx]='\0';
        char_packet_router_route(CHANNEL_SLAVE, buffer);
        slave_ascii_ready=false;
    }
    if(config_ascii_ready){
        size_t idx=0;
        for(size_t i=0;i<ASCII_NUM_ARRAYS;i++){
            for(size_t j=0;j<ASCII_ARRAY_SIZE && config_ascii_arrays[i][j];j++){
                buffer[idx++] = config_ascii_arrays[i][j];
            }
        }
        buffer[idx]='\0';
        char_packet_router_route(CHANNEL_CONFIG, buffer);
        config_ascii_ready=false;
    }
}

 // Variabili globali
 char sequence[G_SEQUENCE_LENGTH];
 char last_char = 'N';
 int algorithm = 2;
 int g_scrolling = 0;
 int g_scroll_offset = 0;


 
 /*! \fn void decoder_operations(void)
 * \brief Esegue tutte le operazioni di decodifica
 * \details Gestisce FFT, Goertzel e comparazione frequenze
 */

 void decoder_operations() {
    if(data_ready) {
         struct_tone_frequencies tone_frequencies;
         complex_g3_t* out;
         struct_tone_bits tone_bits;
         // Applica una finestra di Hann per ridurre la leakage spettrale
         for(int i = 0; i < G_ARRAY_SIZE; i++) {
             double w = 0.5 - 0.5 * cos((2 * G_PI * i) / (G_ARRAY_SIZE - 1));
             array_ready[i].re *= w;
         }

         out = FFT_simple(array_ready, G_ARRAY_SIZE);
         tone_frequencies = decode_ausp(out);
          tone_bits = bit_coder(tone_frequencies);
          //printf("Master: %d %d %d | Slave: %d %d %d | Config: %d %d %d\n", tone_frequencies.master[0], tone_frequencies.master[1], tone_frequencies.master[2], tone_frequencies.slave[0], tone_frequencies.slave[1], tone_frequencies.slave[2], tone_frequencies.configuration[0], tone_frequencies.configuration[1], tone_frequencies.configuration[2]);
          bool packet_ready = process_tone_bits(tone_bits);
          (void)packet_ready;
         
    }
 }
 
 /*! \fn void setup(void)
 * \brief Inizializzazione hardware e software
 */
void setup() {
    Serial.begin(115200);
    memset(sequence, 0, G_SEQUENCE_LENGTH);

    pinMode(HOTSPOT_PIN, INPUT);

    hotspot_mode = digitalRead(HOTSPOT_PIN);
    if(hotspot_mode) {
        printf(" ______________________\n");
        printf("| HotSpot mode enabled |\n");
        printf("\\______________________|\n");
        Blynk.begin(BLYNK_AUTH, WIFI_SSID, WIFI_PASS);
    }
     /*Inizializzazione audio driver I2S*/
     audio_init();
    /* Inizializzazione reader DMA */
    reader_init();

    if(G_LINEAR_REGRESSION_MODE == 0 && G_TESTING_MODE != 2) {
        status_flag = 1;
    }

    char_packet_router_init();
    protocol_init(hotspot_mode);
    movement_sensor_init();
    protocol_set_message_callback(blynk_print);
    Blynk.virtualWrite(V1, "_____________________\n");
    Blynk.virtualWrite(V1, "| HotSpot Device ON |\n");
    Blynk.virtualWrite(V1, "\\___________________|\n");
}
 
 /*! \fn void loop(void)
 * \brief Loop principale
 */
void loop() {
    if(G_LINEAR_REGRESSION_MODE == 1) {
        int freqs[9] = {1000, 2000, 3000, 4000, 5500, 7000, 8000, 9000, 10000};
        play_nine_tones(freqs);
    }
    if(data_ready) {
        decoder_operations();
        process_ready_packets();
        protocol_tick();
        if(hotspot_mode) {
            Blynk.run();
        }
        data_ready = 0;
    }

}


BLYNK_WRITE(V1) {
    String input = param.asStr();
    bool handled = false;
    if(input.equalsIgnoreCase("CONNS")) {
        char list[128];
        protocol_list_devices(list, sizeof(list));
        Blynk.virtualWrite(V1, list);
        handled = true;
    } else if(input.equalsIgnoreCase("ABORT")) {
        protocol_send_abort();
        handled = true;
    } else if(input.equalsIgnoreCase("HELP")) {
        Blynk.virtualWrite(V1,
            "Comandi disponibili:\n"
            "CONNS: lista dispositivi connessi\n"
            "ABORT: interrompe la trasmissione corrente\n"
            "movement_sensor_on[_durata_ms]->ID: attiva il sensore di movimento (default 5000 ms)\n"
            "REQ->ID, SET->ID, OK->ID, MOVEMENT->ID, EXT->ID: invia il comando indicato al dispositivo\n"
            "HELP: mostra questo messaggio");
        handled = true;
    } else {
        int arrow = input.indexOf("->");
        if(arrow > 0){
            String op = input.substring(0, arrow);
            String dest = input.substring(arrow+2);
            if(op.startsWith("movement_sensor_on")){
                unsigned long dur = 5000;
                int idx = op.lastIndexOf('_');
                if(idx > String("movement_sensor_on").length()){
                    dur = op.substring(idx+1).toInt();
                }
                protocol_send_movement_request(dest.c_str(), dur);
                handled = true;
            } else if(command_from_string(op.c_str()) != CMD_UNKNOWN){
                protocol_send_command(dest.c_str(), op.c_str());
                handled = true;
            }
        }
    }
    if(!handled){
        Blynk.virtualWrite(V1, "Comando non riconosciuto digita help per tutti i comandi");
    }
}
