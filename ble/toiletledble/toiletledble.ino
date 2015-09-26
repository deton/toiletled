#include "Tlc5940.h"

const int NUMLEDS = 16; // 0-15
const int LEDIDX_START = 1; // use LED index 1-15
const int LEDIDX_END = 15;
const int MAX_BRIGHTNESS = 4095; // 0-4095
const uint8_t LEDREQ_OFF   = 0x20; // ' '
const uint8_t LEDREQ_ON    = 0x21; // '!'
const uint8_t LEDREQ_BLINK = 0x22; // '"'

uint32_t prev_recv_tm = 0;
const uint32_t TIMEOUTMS = 5000; // 5 [sec]
uint32_t prev_blink_tm = 0;
const uint32_t BLINKMS = 500; // 500 [ms]
int isblinks[NUMLEDS];
int isledon[NUMLEDS];

void setup() {
  Serial.begin(9600); // for BLESerial
  Tlc.init();
  Tlc.clear();
  Tlc.set(1, 2047); // setup OK
  Tlc.update();
  for (int i = 0; i < NUMLEDS; i++) {
    isblinks[i] = 0;
  }
}

void Serial_listen() {
  if (!Serial.available()) {
    Tlc.set(0, 0); // no msg
    Tlc.update();
    return;
  } else {
    Tlc.set(0, 2047); // receiving msg
    Tlc.update();
  }
  int idx = -1;
  while (Serial.available() > 0) {
    int c = Serial.read();
    if (c == '\n') { // start mark
      prev_recv_tm = millis();
      prev_blink_tm = millis();
      idx = LEDIDX_START;
      continue;
    }
    if (idx < LEDIDX_START || idx > LEDIDX_END) {
      continue;
    }
    switch (c) {
    case LEDREQ_BLINK:
      if (!isblinks[idx]) {
        isblinks[idx] = 1;
        isledon[idx] = 1;
        Tlc.set(idx, MAX_BRIGHTNESS);
      }
      break;
    case LEDREQ_ON:
      isblinks[idx] = 0;
      Tlc.set(idx, MAX_BRIGHTNESS);
      break;
    case LEDREQ_OFF:
      isblinks[idx] = 0;
      Tlc.set(idx, 0);
      break;
    default:
      // ignore "OPEN", "CONNECT", "DISCONNECT" from BLESerial
      break;
    }
    Tlc.update();
    idx++;
  }
}

void blink(int i) {
  if (isledon[i]) {
    isledon[i] = 0;
    Tlc.set(i, 0);
  } else {
    isledon[i] = 1;
    Tlc.set(i, MAX_BRIGHTNESS);
  }
}

void blinkled() {
  for (int i = LEDIDX_START; i <= LEDIDX_END; i++) {
    if (isblinks[i]) {
      blink(i);
    }
  }
  Tlc.update();
  prev_blink_tm = millis();
}

void offallled() {
  Tlc.setAll(0);
  Tlc.update();
  for (int i = LEDIDX_START; i <= LEDIDX_END; i++) {
    isblinks[i] = 0;
  }
}

void loop() {
  uint32_t now = millis();
  if (now - prev_blink_tm > BLINKMS) {
    blinkled();
  }
  if (now - prev_recv_tm > TIMEOUTMS) {
    offallled();
  }
  Serial_listen();
  delay(50);
}
