#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <esp_system.h>

// --- LCD & Sensor ---
LiquidCrystal_I2C lcd(0x27, 16, 2);
const int sensorPin = 27;
int rawSensorValue = 0;
int filteredSensor = 0;
int lastFilteredSensor = 0;
const int deltaThreshold = 20;
const int noiseFloor = 1050;
unsigned long lastBeatTime = 0;
unsigned long currentTime = 0;
int bpm = 0;
bool beatDetected = false;
unsigned long beatTimeout = 3000;

// --- Kalman Filter ---
float kalman_Q = 0.05;  // Noise proses
float kalman_R = 1.0;   // Noise sensor
float kalman_P = 1.0;   // Error estimasi
float kalman_K;
float kalman_X = 0.0;   // Estimasi awal

// --- BLE ---
#define LED_BUILTIN 2
#define BLE_SERVICE_UUID        "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_CHARACTERISTIC_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
BLECharacteristic *pCharacteristic;
bool bleDeviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleDeviceConnected = true;
    digitalWrite(LED_BUILTIN, HIGH);
    Serial.println("[ESP32] BLE device connected");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BLE: CONNECTED   ");
    lcd.setCursor(0, 1);
    lcd.print("Dopply Monitor   ");
  }

  void onDisconnect(BLEServer* pServer) {
    bleDeviceConnected = false;
    digitalWrite(LED_BUILTIN, LOW);
    Serial.println("[ESP32] BLE device disconnected");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BLE: DISCONNECT ");
    lcd.setCursor(0, 1);
    lcd.print("Wait/Scan Again ");
    pServer->getAdvertising()->start();
    delay(500);
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BLE: ADVERTISING");
    lcd.setCursor(0, 1);
    lcd.print("Dopply Monitor   ");
  }
};

void setup() {
  Serial.begin(9600);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
  lcd.begin();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("BLE: STANDBY    ");
  lcd.setCursor(0, 1);
  lcd.print("Dopply Monitor  ");
  Serial.println("[ESP32] STATUS: STANDBY");

  // BLE Init
  BLEDevice::init("Dopply-FetalMonitor");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    BLE_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("[ESP32] BLE advertising started");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("BLE: ADVERTISING");
  lcd.setCursor(0, 1);
  lcd.print("Dopply Monitor   ");
}

unsigned long lastSendTime = 0;

void loop() {
  rawSensorValue = analogRead(sensorPin);
  currentTime = millis();

  // --- Kalman Filter ---
  kalman_P = kalman_P + kalman_Q;
  kalman_K = kalman_P / (kalman_P + kalman_R);
  kalman_X = kalman_X + kalman_K * (rawSensorValue - kalman_X);
  kalman_P = (1 - kalman_K) * kalman_P;
  filteredSensor = (int)kalman_X;

  int delta = filteredSensor - lastFilteredSensor;
  lastFilteredSensor = filteredSensor;

  if (filteredSensor < noiseFloor) {
    beatDetected = false;
  }

  if (delta > deltaThreshold && !beatDetected) {
    beatDetected = true;
    unsigned long interval = currentTime - lastBeatTime;
    if (interval > 300) {
      bpm = 60000 / interval;
      lastBeatTime = currentTime;

      Serial.print("Detak terdeteksi! BPM: ");
      Serial.println(bpm);

      // --- Tampilkan status di LCD ---
      lcd.clear();
      lcd.setCursor(0, 0);
      String status = "";

      if (bpm < 120) {
        status = "Bradikardia";
        lcd.print("Bradikardia     ");
        Serial.println("Peringatan: Bradikardia!");
      } else if (bpm > 160) {
        status = "Takikardia";
        lcd.print("Takikardia      ");
        Serial.println("Peringatan: Takikardia!");
      } else {
        status = "Detak Normal";
        lcd.print("Detak Normal    ");
      }

      lcd.setCursor(0, 1);
      lcd.print("BPM: ");
      lcd.print(bpm);
    }
  }

  if (delta < 5) {
    beatDetected = false;
  }

  if ((currentTime - lastBeatTime) > beatTimeout && bpm != 0) {
    bpm = 0;
    Serial.println("Tidak ada detak. BPM = 0");

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Tidak terdeteksi");
    lcd.setCursor(0, 1);
    lcd.print("BPM: 0");
  }

  // Kirim via BLE jika terkoneksi
  if (bleDeviceConnected && (millis() - lastSendTime > 1000)) {
    String bpmStr = String(bpm);
    if (bpm < 120) {
      bpmStr += " (Bradikardia)";
    } else if (bpm > 160) {
      bpmStr += " (Takikardia)";
    } else {
      bpmStr += " (Normal)";
    }

    pCharacteristic->setValue(bpmStr.c_str());
    pCharacteristic->notify();
    Serial.print("[ESP32] Send BPM: ");
    Serial.println(bpmStr);
    lastSendTime = millis();
  }

  delay(10);
}