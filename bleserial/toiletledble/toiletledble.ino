#include "Tlc5940.h"

const int NUMLEDS = 16; // 0-15
const int LEDIDX_START = 1; // use LED index 1-15
const int LEDIDX_END = 15;
const int MAX_BRIGHTNESS = 4095; // 0-4095
const uint8_t LEDREQ_OFF     = 0x20; // ' '
const uint8_t LEDREQ_BLINK10 = 0x21; // '!' duty 10%
const uint8_t LEDREQ_BLINK90 = 0x29; // ')' duty 90%
const uint8_t LEDREQ_ON      = 0x2A; // '*'

uint32_t prev_recv_tm = 0;
const uint32_t TIMEOUTMS = 5000; // [ms]
uint32_t prev_blink_tm = 0;
const uint32_t BLINK_INTERVAL = 1000; // [ms]
uint32_t blinkonms[NUMLEDS]; // [ms] 0: no blink, BLINK_INTERVAL*10%, ..., 90%

void setup() {
  Serial.begin(9600); // for BLESerial
  Tlc.init();
  Tlc.clear();
  Tlc.set(1, 2047); // setup OK
  Tlc.update();
  for (int i = 0; i < NUMLEDS; i++) {
    blinkonms[i] = 0;
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
      idx = LEDIDX_START;
      continue;
    }
    if (idx < LEDIDX_START || idx > LEDIDX_END) {
      continue;
    }
    switch (c) {
    case LEDREQ_ON:
      blinkonms[idx] = 0;
      Tlc.set(idx, MAX_BRIGHTNESS);
      break;
    case LEDREQ_OFF:
      blinkonms[idx] = 0;
      Tlc.set(idx, 0);
      break;
    default:
      if (c >= LEDREQ_BLINK10 && c <= LEDREQ_BLINK90) {
        int dutyPercent = (c - LEDREQ_BLINK10 + 1) * 10; // 10-90%
        blinkonms[idx] = BLINK_INTERVAL * dutyPercent / 100;
      }
      // ignore "OPEN", "CONNECT", "DISCONNECT" from BLESerial
      break;
    }
    Tlc.update();
    idx++;
  }
}

void blinkled(uint32_t now) {
  if (now >= prev_blink_tm + BLINK_INTERVAL) { // set 'on' all blink LEDs
    prev_blink_tm = now;
    for (int i = LEDIDX_START; i <= LEDIDX_END; i++) {
      if (blinkonms[i]) {
        Tlc.set(i, MAX_BRIGHTNESS);
      }
    }
  } else {
    for (int i = LEDIDX_START; i <= LEDIDX_END; i++) {
      if (blinkonms[i] && now >= prev_blink_tm + blinkonms[i]) {
        Tlc.set(i, 0);
      }
    }
  }
  Tlc.update();
}

void offallled() {
  Tlc.setAll(0);
  Tlc.update();
  for (int i = LEDIDX_START; i <= LEDIDX_END; i++) {
    blinkonms[i] = 0;
  }
}

void loop() {
  uint32_t now = millis();
  blinkled(now);
  if (now - prev_recv_tm > TIMEOUTMS) {
    offallled();
  }
  Serial_listen();
  delay(50);
}
