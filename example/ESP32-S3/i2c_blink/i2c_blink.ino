#include "Arduino.h"
#include "Wire.h"
#include "XPowersLib.h" //https://github.com/lewisxhe/XPowersLib
#include "pins_config.h"

XPowersAXP2101 PMU;

void led_task(void *param);
void fpga_led(bool en);

void scan_i2c_device(TwoWire &wire)
{
    Serial.println("Scanning for I2C devices ...");
    Serial.print("      ");
    for (int i = 0; i < 0x10; i++) {
        Serial.printf("0x%02X|", i);
    }
    uint8_t error;
    for (int j = 0; j < 0x80; j += 0x10) {
        Serial.println();
        Serial.printf("0x%02X |", j);
        for (int i = 0; i < 0x10; i++) {
            wire.beginTransmission(i | j);
            error = wire.endTransmission();
            if (error == 0)
                Serial.printf("0x%02X|", i | j);
            else
                Serial.print(" -- |");
        }
    }
    Serial.println();
    Serial.println("I2C device scan ends");
}

void setup()
{
    Serial.begin(115200);
    Serial.println("Hello T-FPGA-CORE");
    xTaskCreatePinnedToCore(led_task, "led_task", 1024, NULL, 1, NULL, 1);

    bool result = PMU.begin(Wire, AXP2101_SLAVE_ADDRESS, PIN_IIC_SDA, PIN_IIC_SCL);

    if (result == false) {
        Serial.println("PMU is not online...");
        while (1)
            delay(50);
    }

    PMU.setDC4Voltage(1200);   // Here is the FPGA core voltage. Careful review of the manual is required before modification.
    PMU.setALDO1Voltage(3300); // BANK0 area voltage
    PMU.setALDO2Voltage(3300); // BANK1 area voltage
    PMU.setALDO3Voltage(2500); // BANK2 area voltage
    PMU.setALDO4Voltage(1800); // BANK3 area voltage

    PMU.enableALDO1();
    PMU.enableALDO2();
    PMU.enableALDO3();
    PMU.enableALDO4();

    delay(1000);
    Wire1.begin(PIN_FPGA_D0, PIN_FPGA_SCK);
    scan_i2c_device(Wire1);
}

void loop()
{
    PMU.setChargingLedMode(XPOWERS_CHG_LED_ON);
    fpga_led(true);
    delay(20);
    PMU.setChargingLedMode(XPOWERS_CHG_LED_OFF);
    fpga_led(false);
    delay(random(300, 980));
}

void led_task(void *param)
{
    pinMode(PIN_LED, OUTPUT);
    while (true) {
        digitalWrite(PIN_LED, 1);
        delay(20);
        digitalWrite(PIN_LED, 0);
        delay(random(300, 980));
    }
}

void fpga_led(bool en)
{
    Wire1.beginTransmission(0x30);
    Wire1.write(en);
    Wire1.endTransmission();
}
