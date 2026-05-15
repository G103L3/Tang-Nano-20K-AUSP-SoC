#include <Arduino.h>

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial2.begin(115200, SERIAL_8N1, 27, 14);
    Serial.println("ESP32 BOOT COMPLETED");
}

void loop() {
    while (Serial2.available()) {
        Serial.write(Serial2.read());
    }
}
