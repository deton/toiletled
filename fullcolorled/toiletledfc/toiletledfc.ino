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
uint32_t prev_blink_tm = 0;
const uint32_t BLINKMS = 500; // 500 [ms]
//TODO: make struct or object
uint32_t colors[NUMPIXELS];
int isblinks[NUMPIXELS];
int isledon[NUMPIXELS];

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

void setColor(int idx, uint32_t color) {
  isledon[idx] = (color != 0);
  pixels.setPixelColor(idx, color);
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
  int isblink = 0;
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
    case 'T': // tenTou
      isblink = 0;
      break;
    case 'M': // tenMetu
      isblink = 1;
      break;
    case '\n':
    case '\r':
      floor = FLOORMIN;
      isblink = 0;
      parseRgb(-1); // reset
      continue;
    default:
      // ignore illegal command. TODO: checksum
      floor = -1;
      continue;
    }
    if (color != RGB_PARSING && color != RGB_UNDEF) {
      if (floor >= FLOORMIN && floor <= FLOORMAX) {
        int idx = floor2pixelidx(floor);
        colors[idx] = color;
        isblinks[idx] = isblink;
        setColor(idx, color);
        if (floor == FLOORMAX) {
          pixels.show();
          prev_recv_tm = millis();
          prev_blink_tm = millis();
        }
        floor++;
      }
    }
  }
}

void blink(int i) {
  if (isledon[i]) {
    setColor(i, 0);
  } else {
    setColor(i, colors[i]);
  }
}

void blinkled() {
  for (int floor = FLOORMIN; floor <= FLOORMAX; floor++) {
    int i = floor2pixelidx(floor);
    if (isblinks[i]) {
      blink(i);
    }
  }
  pixels.show();
  prev_blink_tm = millis();
}

void offallled() {
  uint32_t offcolor = pixels.Color(0, 0, 0);
  for (int floor = FLOORMIN; floor <= FLOORMAX; floor++) {
    int idx = floor2pixelidx(floor);
    colors[idx] = offcolor;
    isblinks[idx] = 0;
    setColor(idx, offcolor);
  }
  pixels.show();
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
}
