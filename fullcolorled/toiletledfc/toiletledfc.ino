#include <Adafruit_NeoPixel.h>
#include <avr/power.h>

#define FLOORMIN 1
#define FLOORMAX 6

#define PIN            9
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

// floor 1-6 => pixelidx 0-5
int floor2pixelidx(int floor) {
  return floor - FLOORMIN;
}

#define UINT32_MAX 0xffffffff
#define RGB_PARSING UINT32_MAX
#define RGB_UNDEF   (UINT32_MAX-1)

uint32_t parseRgb(int n) {
  static int rgb[3] = {-1, -1, -1};
  static int i = 0;

  if (n < 0) { // reset
    i = 0;
    rgb[0] = rgb[1] = rgb[2] = -1;
    return RGB_UNDEF;
  }

  if (rgb[i] < 0) {
    rgb[i] = n;
  } else {
    rgb[i] = rgb[i]*16 + n;
    i++;
    if (i >= 3) { // rgb parse done
      uint32_t c = pixels.Color(rgb[0], rgb[1], rgb[2]);
      i = 0;
      rgb[0] = rgb[1] = rgb[2] = -1;
      return c;
    }
  }
  return RGB_PARSING;
}

void Serial_listen() {
  int floor = -1;
  // rgb color for each floor. ex: ff0000ff0000ff0000ff0000ff0000ff0000
  while (Serial.available() > 0) {
    int c = Serial.read();
    uint32_t color = RGB_UNDEF;
    switch (c) { 
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      color = parseRgb(c - '0');
      break;
    case 'a':
    case 'b':
    case 'c':
    case 'd':
    case 'e':
    case 'f':
      color = parseRgb(c - 'a' + 10);
      break;
    case '\n':
    case '\r':
      floor = FLOORMIN;
      parseRgb(-1); // reset
      continue;
    default:
      // ignore illegal command. TODO: checksum
      floor = -1;
      continue;
    }
    if (color != RGB_PARSING && color != RGB_UNDEF) {
      if (floor >= FLOORMIN && floor <= FLOORMAX) {
        pixels.setPixelColor(floor2pixelidx(floor), color);
        if (floor == FLOORMAX) {
          pixels.show();
          prev_recv_tm = millis();
        }
        floor++;
      }
    }
  }
}

void offallled() {
  uint32_t offcolor = pixels.Color(0, 0, 0);
  for (int floor = FLOORMIN; floor <= FLOORMAX; floor++) {
    pixels.setPixelColor(floor2pixelidx(floor), offcolor);
  }
  pixels.show();
}

void loop() {
  Serial_listen();
  if (millis() - prev_recv_tm > TIMEOUTMS) {
    offallled();
  }
}
