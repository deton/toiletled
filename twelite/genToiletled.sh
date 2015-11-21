#!/bin/sh
cp -r Samp_PingPong toiletled
cd toiletled
rm PingPong/Build/Samp_PingPong_*.bin
cp -r PingPong toiletled
mv PingPong Serial2Send
sed -ie '/^DIRS/s/=.*$/= Serial2Send toiletled/' Makefile
sed -ie '/^APPSRC/s/$/ tlc5940.c/' toiletled/Build/Makefile
# TWESDK/Tools/cygwin does not have 'patch' command
vim -u NONE --noplugin -e -s Common/Source/config.h << "DIFF"
32c
#define APP_ID              0x81012CB8 // XXX: set 0x80000000 + server TWE-Lite S/N
.
x
DIFF
cd Serial2Send/Source
mv PingPong.h Serial2Send.h
mv PingPong.c Serial2Send.c
# no 'cat' command
head -n 999 >Serial2Send.c.diff << "DIFF"
600c
	    	vfPrintf(&sSerStream, "\r\n*** Serial2Send %d.%02d-%d ***", VERSION_MAIN, VERSION_SUB, VERSION_VAR);
.
522,576d
491,520d
457,489c
		if (i16Char >= 0 && i16Char <= 0xff) {
			if (inmsg) {
				if (i16Char == '\n' || i16Char == '\r') { // 終端
					sAppData.i16ValidCountDown = VALIDCOUNT;
					inmsg = FALSE;
					continue;
				}
				if (u8Idx >= LEDREQ_LEN) {
					continue;
				}
				sAppData.auLedData[u8Idx++] = i16Char;
			} else if (i16Char == 't') { // LED制御コマンド開始
				inmsg = TRUE;
				u8Idx = 0;
				memset(sAppData.auLedData, ' ', LEDREQ_LEN);
.
455d
451a
	static bool_t inmsg = FALSE;
	static uint8 u8Idx = 0;

.
402,405c
	vPortSetLo(PORT_LED_SEND);
	vPortAsOutput(PORT_LED_SEND);
.
334,338c
		// Serialから読み込んだLED制御コマンドは、5秒間有効
   		if (sAppData.i16ValidCountDown > 0) {
			sAppData.i16ValidCountDown--;
		} else if (sAppData.i16ValidCountDown == 0) {
			sAppData.i16ValidCountDown--;
			// 5秒以上データ読み込み無しの時にクリアする
			memset(sAppData.auLedData, ' ', LEDREQ_LEN);
.
331,332c
   		// LED ON when send
		if (sAppData.i16LedCountDown > 0) {
			sAppData.i16LedCountDown--;
		} else if (sAppData.i16LedCountDown == 0) {
			sAppData.i16LedCountDown--;
  			vPortSetHi(PORT_LED_SEND); // LED OFF
		}
.
287,290c
		tsTx.auData[tsTx.u8Len] = '\0';
		vfPrintf(&sSerStream, LB "Send Message: %s", tsTx.auData);
.
284c
		sAppData.i16LedCountDown = SENDLED_COUNT;
		vPortSetLo(PORT_LED_SEND); // LED ON
.
276,279c
		memcpy(tsTx.auData, sAppData.auLedData, LEDREQ_LEN);
		tsTx.u8Len = LEDREQ_LEN;
.
270c
		tsTx.u8Retry = 2;
.
262c
		// LED制御コマンドを返信
.
258c
		&& !memcmp(pRx->auData, "P", 1) // パケットの先頭は P の場合
.
256c
	// LED制御コマンド要求メッセージに対し、LED制御コマンドを返信する
.
128a
		memset(sAppData.auLedData, ' ', LEDREQ_LEN);
.
100a
const uint8 PORT_LED_SEND = 16; // DIO16 red LED of ToCoStick

.
60c
    int16 i16LedCountDown;

	// Serialから読み込み、TWE-Liteから要求があった時に返信するLED制御コマンド
	uint8 auLedData[LEDREQ_LEN];

	// Serialから読み込んだLED制御コマンドの残り有効時間。1カウント=4ms
	int16 i16ValidCountDown;
.
48a
#define LEDREQ_LEN 15

// TWE-Lite  ToCoStick   LininoONE        server
//                            --------------> トイレ使用中状況HTTP GET
//              <------------- SerialでLED制御コマンド書き込み
//             ...
//    ----------> LED制御コマンド要求SEND
//    <---------- LED制御コマンド
#define SENDLED_COUNT (300/4) // TWE-Liteから受信時にLED点灯をする時間。300ms
#define VALIDCOUNT (5000/4) // Serialから読み込んだLED制御コマンドの有効期間

.
22c
#include "Serial2Send.h"
.
x
DIFF
# use ':source' to avoid mojibake
echo 'so Serial2Send.c.diff' | vim -e -s Serial2Send.c
#vim -e -S toiletled.c.diff toiletled.c
rm Serial2Send.c.diff

cd ../../toiletled/Source
mv PingPong.h toiletled.h
mv PingPong.c toiletled.c
# no 'cat' command
head -n 999 >toiletled.c.diff << "DIFF"
605,608d
580,601c
   		// LED制御コマンド要求メッセージを、2秒に1回送信
		if (sAppData.i16NextTxCountDown > 0) {
			sAppData.i16NextTxCountDown--;
		} else if (sAppData.i16NextTxCountDown == 0) {
			sAppData.i16NextTxCountDown--;
			vSendLedReqCmd();
			sAppData.i16RxTimeout = RXTIMEOUT;
.
578d
575,576c
	if (eEvent == E_EVENT_TICK_TIMER) {
		if (sAppData.i16RxTimeout > 0) {
			// LED制御コマンド受信待ち。
			// 受信時はcbToCoNet_vRxEvent()でi16RxTimeout = -1される
			sAppData.i16RxTimeout--;
			return;
		} else if (sAppData.i16RxTimeout == 0) {
			sAppData.i16RxTimeout--;
			V_PRINTF(LB"! TIMEOUT");
			// 次回コマンド要求の送信は短くして500ms後
			sAppData.i16NextTxCountDown = RETRY_INTERVAL;
			return;
.
571,572c
/**
 * イベント処理関数
 * @param pEv
 * @param eEvent
 * @param u32evarg
 */
static void vProcessEvCore(tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_START_UP) {
		return;
.
566,569c
	ToCoNet_bMacTxReq(&tsTx);
	vfPrintf(&sSerStream, LB "Fire PING");
}
.
563,564c
	sToCoNet_AppContext.bRxOnIdle = TRUE;
	ToCoNet_vRfConfig();
.
554,561c
	// 長さ0だと送信成功しないようなので
	tsTx.auData[0] = 'P';
	tsTx.u8Len = 1;
.
549,551c
	tsTx.u8Retry = 2;
	tsTx.u8CbId = sAppData.u16frame_count & 0xFF;
	tsTx.u8Seq = sAppData.u16frame_count & 0xFF;
.
546c
	tsTx.u32DstAddr = APP_ID; // XXX: 手元にあるToCoStickのアドレス
.
543c
	sAppData.u16frame_count++;
.
537,539c
static void vSendLedReqCmd()
{
.
535c
}
.
524,533c
		vfPrintf(&sSerStream, LB);
	    SERIAL_vFlush(sSerStream.u8Device);
.
522a
		}
.
493,521c
		default:
.
483,489c
				static uint8 ledidx = LEDIDX_OFFSET;
				ledidx++;
				if (ledidx >= NUMLEDS) {
					ledidx = LEDIDX_OFFSET;
				}
				vTlc5940_Set(ledidx, MAX_BRIGHTNESS*9/10); // DUTY 90%
				vTlc5940_Update();
				sAppData.i16ValidCountDown = VALIDCOUNT;
.
463,481c
		case 'l': // TLC5940制御の動作確認
.
438,449d
408,416d
401,405c
	vTlc5940_Init(1000); // 1 [sec]. use grayscale PWM for blinking
.
395,396d
382,393d
370,378d
347,365d
331,338c
		// 受信したLED制御コマンドは、5秒間有効
   		if (sAppData.i16ValidCountDown > 0) {
			sAppData.i16ValidCountDown--;
			vTlc5940_Refresh();
		} else if (sAppData.i16ValidCountDown == 0) {
			// 5秒以上受信無しの時にLED OFF
			sAppData.i16ValidCountDown--;
			int i;
			for (i = LEDIDX_OFFSET; i < NUMLEDS; i++) {
				vTlc5940_Set(i, 0);
			}
			vTlc5940_Update();
.
310,326d
294,305d
279,290c
				break;
			}
		}
		for (; i + LEDIDX_OFFSET < NUMLEDS; i++) {
			vTlc5940_Set(i + LEDIDX_OFFSET, 0);
		}
		vTlc5940_Update();
.
276,277c
		for (i = 0; i < pRx->u8Len && i + LEDIDX_OFFSET < NUMLEDS; i++) {
			uint8 c = pRx->auData[i];
			switch (c) {
			case LEDREQ_ON:
				vTlc5940_Set(i + LEDIDX_OFFSET, MAX_BRIGHTNESS);
				break;
			case LEDREQ_OFF:
				vTlc5940_Set(i + LEDIDX_OFFSET, 0);
				break;
			default:
				if (c >= LEDREQ_BLINK10 && c <= LEDREQ_BLINK90) {
					// use TLC5940 grayscale PWM as blink
					int dutyPercent10 = (c - LEDREQ_BLINK10 + 1); // 1-9
					vTlc5940_Set(i + LEDIDX_OFFSET, MAX_BRIGHTNESS * dutyPercent10 / 10);
.
269,274c
	if (pRx->u8Seq != u16seqPrev) { // シーケンス番号による重複チェック
		u16seqPrev = pRx->u8Seq;
.
262,267c
	sToCoNet_AppContext.bRxOnIdle = FALSE;
	ToCoNet_vRfConfig();
.
256,260c
	sAppData.i16RxTimeout = -1; // 受信待ちタイムアウトをクリア
	sAppData.i16NextTxCountDown = SEND_INTERVAL;
	sAppData.i16ValidCountDown = VALIDCOUNT;
.
236d
224,232d
218,221d
205,216d
187,198d
167,177d
151,161d
135c
		sToCoNet_AppContext.bRxOnIdle = FALSE; // SEND後受信待ち中のみTRUEにする
.
129d
112d
98,109d
88,90d
63,66c
    uint16 u16frame_count;
	// 受信したLED制御コマンドの残り有効時間。1カウント=4ms
	int16 i16ValidCountDown;
	// 次回送信までの残り時間
	int16 i16NextTxCountDown;
	// SEND後の受信待ちタイムアウト残り時間
	int16 i16RxTimeout;
.
55,61d
47a
#define V_PRINTF(...) vfPrintf(&sSerStream,__VA_ARGS__)

#define NUMLEDS 16
#define MAX_BRIGHTNESS 4095 // 0-4095
#define LEDIDX_OFFSET 1
#define LEDREQ_OFF     0x20 // ' '
#define LEDREQ_BLINK10 0x21 // '!' duty 10%
#define LEDREQ_BLINK90 0x29 // ')' duty 90%
#define LEDREQ_ON      0x2A // '*'

// TWE-Lite  ToCoStick+LininoONE
//    ----------> LED制御コマンド要求SEND
//    <---------- LED制御コマンド
#define SEND_INTERVAL (2000/4) // LED制御コマンド要求メッセージの送信間隔
#define RETRY_INTERVAL (500/4) // SEND後受信タイムアウト時再送間隔
#define VALIDCOUNT (5000/4) // 受信したLED制御コマンドの有効期間。5秒
#define RXTIMEOUT (64/4) // SEND後受信待ちタイムアウト時間
.
22c
#include "toiletled.h"
#include "tlc5940.h"
.
x
DIFF
echo 'so toiletled.c.diff' | vim -e -s toiletled.c
rm toiletled.c.diff
head -n 999 >tlc5940.h << "EOF"
// tlc5940.h: library to control TLC5940 LED driver IC for TWE-Lite.
//
// TWE-Lite           --- TLC5940
// SPIMOSI=DIO18(DO1) --- SIN
// SPICLK=C(PWM2)     --- SCLK
// DIO4(DO3)          --- XLAT
// DIO9(DO4)          --- BLANK
// DIO8(PWM4)         --- GSCLK
// TODO: customizable XLAT,BLANK,GSCLK pins
#ifndef  TLC5940_H_INCLUDED
#define  TLC5940_H_INCLUDED

/**
 * Initialize.
 * @param gspwmcycle_ms grayscale PWM cycle in [ms]. consists of 4096 pulses.
 */
void     vTlc5940_Init(uint16 gspwmcycle_ms);
void     vTlc5940_Set(uint8 channel, uint16 brightness);
void     vTlc5940_Update(void);
void     vTlc5940_Refresh(void);

#endif  /* TLC5940_H_INCLUDED */
EOF
head -n 999 >tlc5940.c << "EOF"
#include <string.h>
#include "jendefs.h"
#include <AppHardwareApi.h>
#include "tlc5940.h"
#include "utils.h"
#include "ToCoNet.h"

// set 0 to avoid unexpected refresh for use of GS PWM as blink
#define REFRESH_ON_UPDATE 0

#define PORT_XLAT  4 // DIO4(DO3)
#define PORT_BLANK 9 // DIO9(DO4)

static tsTimerContext sTimerPWM; // GSCLK PWM
static uint16 u16Gsdata[16];
static uint16 u16GsPwmCycle_ms = 0;
static uint32 u32PrevRefresh_ms = 0;

void vTlc5940_Init(uint16 gspwmcycle_ms)
{
    vAHI_SpiConfigure(1, E_AHI_SPIM_MSB_FIRST, 0,
                      0, 1, E_AHI_SPIM_INT_DISABLE,
                      E_AHI_SPIM_AUTOSLAVE_DSABL);

    u16GsPwmCycle_ms = gspwmcycle_ms;
    // TIMER0 の各ピンを解放。PWM1..4 は使用する
    vAHI_TimerFineGrainDIOControl(0x7);
    vAHI_TimerSetLocation(E_AHI_TIMER_4, TRUE, FALSE); // set DIO8 for PWM4
    memset(&sTimerPWM, 0, sizeof(tsTimerContext));
    sTimerPWM.u16Hz = 4096000 / gspwmcycle_ms; // 4096 pulses in one GS cycle
    sTimerPWM.u8PreScale = 0;
    sTimerPWM.u16duty = 512;
    sTimerPWM.bPWMout = TRUE;
    sTimerPWM.bDisableInt = TRUE;
    sTimerPWM.u8Device = E_AHI_DEVICE_TIMER4;
    vTimerConfig(&sTimerPWM);
    vTimerStart(&sTimerPWM);

    memset(u16Gsdata, 0, sizeof(u16Gsdata));
    vPortSetLo(PORT_XLAT);
    vPortAsOutput(PORT_XLAT);
    vPortSetLo(PORT_BLANK);
    vPortAsOutput(PORT_BLANK);

    vAHI_SpiSelect(2); // Select SPI_SLAVE #1
    int i;
    for (i = 0; i < 16; i++) {
        vAHI_SpiStartTransfer(11, u16Gsdata[i]); // 11: 12-bit data
        vAHI_SpiWaitBusy();
    }
    vAHI_SpiStop();
    vPortSetHi(PORT_XLAT);
    vPortSetLo(PORT_XLAT);
}

void vTlc5940_Set(uint8 channel, uint16 brightness)
{
    u16Gsdata[15-channel] = brightness;
}

void vTlc5940_Update(void)
{
    int i;
    uint32 u32ReadWord;

    vAHI_SpiSelect(2); // Select SPI_SLAVE #1
    for (i = 0; i < 16; i++) {
        vAHI_SpiStartTransfer(11, u16Gsdata[i]); // 11: 12-bit data
        vAHI_SpiWaitBusy();
        //u32ReadWord = u32AHI_SpiReadTransfer32();
    }
    vAHI_SpiStop();

#if REFRESH_ON_UPDATE
    vPortSetHi(PORT_BLANK);
#endif
    vPortSetHi(PORT_XLAT);
    vPortSetLo(PORT_XLAT);
#if REFRESH_ON_UPDATE
    vPortSetLo(PORT_BLANK);
#endif
}

void vTlc5940_Refresh(void)
{
    if (u32TickCount_ms - u32PrevRefresh_ms > u16GsPwmCycle_ms) {
        vPortSetHi(PORT_BLANK);
        u32PrevRefresh_ms = u32TickCount_ms;
        vPortSetLo(PORT_BLANK);
    }
}
EOF
