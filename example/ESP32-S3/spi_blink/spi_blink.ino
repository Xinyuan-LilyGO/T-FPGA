#include "Arduino.h"
#include "SPI.h"
#include "Wire.h"
#include "XPowersLib.h" //https://github.com/lewisxhe/XPowersLib
#include "pins_config.h"

XPowersAXP2101 PMU;

void led_task(void *param);

void fpga_spi_test()
{
    Serial.println("=== SPI test ===");

    digitalWrite(PIN_FPGA_CS, 1);
    delay(100);

    // First, send a virtual byte to initialize the state.
    digitalWrite(PIN_FPGA_CS, 0);
    delayMicroseconds(20);
    SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
    uint8_t init_data = SPI.transfer(0x00);
    SPI.endTransaction();
    delayMicroseconds(20);
    digitalWrite(PIN_FPGA_CS, 1);
    delay(10);

    Serial.printf("Initialization: Send 0x00 -> Received 0x%02X\n", init_data);

    // Test the continuous mode
    uint8_t previous_send = 0x00;

    for (int i = 1; i <= 8; i++) {
        uint8_t send_data = i * 0x20;  // 0x20, 0x40, 0x60, ...

        digitalWrite(PIN_FPGA_CS, 0);
        delayMicroseconds(20);

        SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
        uint8_t received = SPI.transfer(send_data);
        SPI.endTransaction();

        delayMicroseconds(20);
        digitalWrite(PIN_FPGA_CS, 1);

        uint8_t expected = (uint8_t)(previous_send + 1);
        Serial.printf("Test %d: Send 0x%02X -> Received 0x%02X", i, send_data, received);

        // The FPGA returns data equal to the last received byte + 1 each time.
        if (received == expected) {
            Serial.printf(" ✓ (Expected: 0x%02X = 0x%02X + 1)\n", expected, previous_send);
        } else {
            Serial.printf(" ✗ (Expected: 0x%02X = 0x%02X + 1)\n", expected, previous_send);
        }

        previous_send = send_data;
        delay(30);
    }
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

    PMU.disableTSPinMeasure();
    delay(1000);

    // Wire1.begin(PIN_FPGA_D0, PIN_FPGA_SCK);
    pinMode(PIN_FPGA_CS, OUTPUT);
    pinMode(PIN_BTN, INPUT);
    // SPI.begin(PIN_FPGA_SCK, PIN_FPGA_D1, PIN_FPGA_D0);
    SPI.begin(PIN_FPGA_SCK, PIN_FPGA_D0, PIN_FPGA_D1);

    digitalWrite(PIN_FPGA_CS, 0);
    SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
    SPI.transfer(0x00);  // 虚拟传输，初始化FPGA状态
    SPI.endTransaction();
    digitalWrite(PIN_FPGA_CS, 1);
    delay(10);


    fpga_spi_test();
}

void loop()
{
    PMU.setChargingLedMode(XPOWERS_CHG_LED_ON);
    delay(20);
    PMU.setChargingLedMode(XPOWERS_CHG_LED_OFF);
    delay(20);
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
