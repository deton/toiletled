#include <Adafruit_NeoPixel.h>
#include <avr/power.h>

#define NUMFLOORS 6

#define PIN            2
#define NUMPIXELS      6
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(NUMPIXELS, PIN, NEO_RGB + NEO_KHZ800);

#define CMD_FROM_MPU 1
#ifdef CMD_FROM_MPU  // accept command from MPU for Arduino Yun/Linino ONE
#include <Console.h>
#define Serial Console
#endif

uint32_t prev_recv_tm = 0;
const uint32_t TIMEOUTMS = 5000; // 5 [sec]

void setup() {
  pixels.begin();

#ifdef CMD_FROM_MPU
  Bridge.begin(115200);
  Console.begin();
#else
  Serial.begin(115200);
#endif
}

// floor 1-6 => pixelidx 5-0
int floor2pixelidx(int floor) {
  return NUMFLOORS - floor;
}

uint32_t vacant2color(char vacant) {
  switch (vacant) {
  case '0':
    return pixels.Color(20, 0, 0); // red
  case '1':
    return pixels.Color(25, 20, 2); // orange?
    //return pixels.Color(20, 20, 0); // yellow
  case '2':
    return pixels.Color(12, 20, 0);
    //return pixels.Color(12, 20, 0);
  case '3':
    return pixels.Color(8, 20, 0);
    //return pixels.Color(6, 20, 0);
  case '4':
    return pixels.Color(0, 20, 0); // green
  case 'u': // unknown
  default:
    return pixels.Color(0, 0, 0);
  }
}

void Serial_listen() {
  int floor = 1;
  while (Serial.available() > 0) {
    prev_recv_tm = millis();
    int c = Serial.read(); // available doors at each floor
    switch (c) { 
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case 'u': // unknown
      pixels.setPixelColor(floor2pixelidx(floor), vacant2color(c));
      pixels.show();
      floor++;
      if (floor > 6) {
        floor = 1;
      }
      break;
    case '\n':
    case '\r':
      floor = 1;
      break;
    default:
      break;
    }
  }
}

void offallled() {
  for (int floor = 1; floor <= 6; floor++) {
    pixels.setPixelColor(floor2pixelidx(floor), vacant2color('u'));
  }
  pixels.show();
}

void loop() {
  Serial_listen();
  if (millis() - prev_recv_tm > TIMEOUTMS) {
    offallled();
  }
}
