/*
 * Serial Bridge for Arduino Due
 * Created by Gioele Giunta
 * Date: 2025-02-25
 *
 * This file provides C-compatible functions to enable serial communication 
 * for C code using Arduino's Serial library.
 */

 #include <Arduino.h>
 #include "global_parameters.h"

 int mode = G_MODE; //2: Stampa Debug-Info  1: Stampa solo Info 0: Non stampa nulla
 extern "C" {
     // Initialize serial communication with the specified baud rate
     void serial_init(unsigned long baudrate) {
         Serial.begin(baudrate);
         while (!Serial) {
             ; 
         }
     }
 
     // Send a single character over the serial port
     void serial_write_char(char c) {
         Serial.write(c);
     }
 
     // Send a string over the serial port
     bool serial_write_string(const char* str) {
        if((strstr(str, "Debug") != NULL) && mode <= 1){
            return false;
        }
        if((strstr(str, "Info") != NULL) && (strstr(str, ">") != NULL) && mode == 0){
            return false;
        }
         Serial.print(str);
         return true;
     }

     void serial_write_formatted(const char* format, ...) {
        char buffer[128];
        va_list args;
    
        va_start(args, format);
        vsnprintf(buffer, sizeof(buffer), format, args);
        va_end(args);
    
        serial_write_string(buffer);
    }
 }
 