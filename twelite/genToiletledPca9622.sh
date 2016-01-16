#!/bin/sh
cp -r Samp_PingPong toiletledPca9622
cd toiletledPca9622
rm PingPong/Build/Samp_PingPong_*.bin
cp -r PingPong toiletled
mv PingPong Serial2Send
cp ../Samp_I2C/Main/Source/SMBus.* toiletled/Source/
sed -ie '/^DIRS/s/=.*$/= Serial2Send toiletled/' Makefile
sed -ie '/^APPSRC/s/$/ pca9622.c SMBus.c/' toiletled/Build/Makefile
# TWESDK/Tools/cygwin does not have 'patch' command
vim -u NONE --noplugin -e -s Common/Source/config.h << "DIFF"
32c
#define APP_ID              0x81012CB8 // XXX: set 0x80000000 + server TWE-Lite S/N
.
x
DIFF
vim -u NONE --noplugin -e -s Common/Source/app_event.h << "DIFF"
29,34c
	E_STATE_APP_WAIT_RX,
	E_STATE_APP_SLEEP,
.
16,22d
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
574,576d
569,572d
535,567c
				sAppData.auLedData[u8Idx++] = i16Char;
			} else if (i16Char == 't' || i16Char == 's') { // LED制御コマンド開始
				inmsg = TRUE;
				vClearLedData();
				u8Idx = 0;
				sAppData.auLedData[u8Idx++] = i16Char;
.
522,533c
				if (u8Idx >= LEDREQ_LEN) {
					continue;
.
491,520c
					inmsg = FALSE;
					continue;
.
457,489c
		if (i16Char >= 0 && i16Char <= 0xff) {
			if (inmsg) {
				if (i16Char == '\n' || i16Char == '\r') { // 終端
					if (bIsSleepLedData()) {
						sAppData.i16ValidCountDown = VALIDFOREVER;
					} else {
						sAppData.i16ValidCountDown = VALIDCOUNT;
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
			sAppData.i16ValidCountDown = VALIDFOREVER;
			// 5秒以上データ読み込み無しの時にクリアする
			vClearLedData();
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
		vClearLedData();
.
100a
const uint8 PORT_LED_SEND = 16; // DIO16 red LED of ToCoStick

static void vClearLedData()
{
	memset(sAppData.auLedData, ' ', LEDREQ_LEN);
	sAppData.auLedData[0] = 't';
}

static bool_t bIsSleepLedData()
{
	return sAppData.auLedData[0] == 's';
}

.
60c
    int16 i16LedCountDown;

	// Serialから読み込み、TWE-Liteから要求があった時に返信するLED制御コマンド
	uint8 auLedData[LEDREQ_LEN];

	// Serialから読み込んだLED制御コマンドの残り有効時間。1カウント=4ms
	int16 i16ValidCountDown;
.
48a
#define LEDREQ_LEN 16

// TWE-Lite  ToCoStick   LininoONE        server
//                            --------------> トイレ使用中状況HTTP GET
//              <------------- SerialでLED制御コマンド書き込み
//             ...
//    ----------> LED制御コマンド要求SEND
//    <---------- LED制御コマンド
#define SENDLED_COUNT (300/4) // TWE-Liteから受信時にLED点灯をする時間。300ms
#define VALIDCOUNT (5000/4) // Serialから読み込んだLED制御コマンドの有効期間
#define VALIDFOREVER (-1)

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
606,608c
/**
 * イベント処理関数リスト
 */
static const tsToCoNet_Event_StateHandler asStateFuncTbl[] = {
	PRSEV_HANDLER_TBL_DEF(E_STATE_IDLE),
	PRSEV_HANDLER_TBL_DEF(E_STATE_RUNNING),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_WAIT_RX),
	PRSEV_HANDLER_TBL_DEF(E_STATE_APP_SLEEP),
	PRSEV_HANDLER_TBL_TRM
};

/**
 * イベント処理関数
 * @param pEv
 * @param eEvent
 * @param u32evarg
 */
static void vProcessEvCore(tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	ToCoNet_Event_StateExec(asStateFuncTbl, pEv, eEvent, u32evarg);
}
.
602a
		V_PRINTF(LB"Sleeping...(ms=%d,ramoff=%d)", sAppData.u32Sleepms, bRamOff);
		SERIAL_vFlush(UART_PORT_SLAVE);
		ToCoNet_vSleep(E_AHI_WAKE_TIMER_0, sAppData.u32Sleepms, FALSE, bRamOff);
.
600,601c
			sAppData.u32SpentFromRecv += sAppData.u32Sleepms;
.
595,598c
}

PRSEV_HANDLER_DEF(E_STATE_APP_SLEEP, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_NEW_STATE) {
		bool_t bRamOff = FALSE;
		if (sAppData.u32Sleepms >= RAMOFF_SLEEPMS) {
			bRamOff = TRUE;
.
580,593c
// LED制御コマンド受信待ち。
// 受信時はcbToCoNet_vRxEvent()からE_ORDER_KICKされる
PRSEV_HANDLER_DEF(E_STATE_APP_WAIT_RX, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_ORDER_KICK) {
		ToCoNet_Event_SetState(pEv, E_STATE_APP_SLEEP);
	} else if (ToCoNet_Event_u32TickFrNewState(pEv) > RXTIMEOUT) {
		V_PRINTF(LB"! TIMEOUT");
		sAppData.u32SpentFromRecv += ToCoNet_Event_u32TickFrNewState(pEv);
		if (sAppData.u32SpentFromRecv > VALIDTIME) {
			vOffAllLed(); // 5秒以上受信無しの時にLED OFF
		}
		// 次回コマンド要求の送信は短くして500ms後
		sAppData.u32Sleepms = RETRY_INTERVAL;
		ToCoNet_Event_SetState(pEv, E_STATE_APP_SLEEP);
.
575,576c
PRSEV_HANDLER_DEF(E_STATE_RUNNING, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_NEW_STATE) {
   		// LED制御コマンド要求メッセージを、起床時に送信
		vSendLedReqCmd();
		ToCoNet_Event_SetState(pEv, E_STATE_APP_WAIT_RX);
.
573a
}
.
569,572d
566,567c
PRSEV_HANDLER_DEF(E_STATE_IDLE, tsEvent *pEv, teEvent eEvent, uint32 u32evarg) {
	if (eEvent == E_EVENT_START_UP) {
		if (u32evarg & EVARG_START_UP_WAKEUP_RAMHOLD_MASK) {
			V_PRINTF(LB "*** Warm starting. SpentFromRecv=%d", sAppData.u32SpentFromRecv);
			ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
		} else {
			V_PRINTF(LB "*** Cold starting.");
			ToCoNet_Event_SetState(pEv, E_STATE_RUNNING);
.
563,564c
	ToCoNet_bMacTxReq(&tsTx);
	vfPrintf(&sSerStream, LB "Fire PING");
}
.
560,561c
	sToCoNet_AppContext.bRxOnIdle = TRUE;
	ToCoNet_vRfConfig();
.
554,558c
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
				PCA9622_vSet(ledidx, MAX_BRIGHTNESS*9/10); // DUTY 90%
				bool_t bOk = PCA9622_bUpdate();
				V_PRINTF(LB"PCA9622_bUpdate: %d", bOk);
.
463,481c
		case 'l': // PCA9622制御の動作確認
.
438,449d
408,416d
401,405c
	bool_t bOk = PCA9622_bInit(1000);
	V_PRINTF(LB"PCA9622_bInit: %d", bOk);
.
395,396d
382,393d
370,378d
347,365d
330,340d
310,326d
294,305d
291a

	// E_STATE_APP_WAIT_RX側処理に移る
	ToCoNet_Event_Process(E_ORDER_KICK, 0, vProcessEvCore);
.
279,290d
276,277c
		switch (pRx->auData[0]) {
		case 't': // led request
			vParseMsgAndUpdateLed(pRx->auData, pRx->u8Len);
			break;
		case 's': // sleep request
			vParseSleepMsg(pRx->auData, pRx->u8Len);
			break;
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
	sAppData.u32SpentFromRecv = 0;
	sAppData.u32Sleepms = SEND_INTERVAL;
.
236d
224,232d
221a
	}
	for (; j < NUMLEDS; j++) {
		PCA9622_vSet(j, 0);
	}
	PCA9622_bUpdate();
}

static void vOffAllLed()
{
	int i;
	for (i = LEDIDX_OFFSET; i < NUMLEDS; i++) {
		PCA9622_vSet(i, 0);
	}
	PCA9622_bUpdate();
}

static void vParseSleepMsg(uint8 *pMsg, uint8 u8Len)
{
	int i;
	uint32 min = 0;

	vOffAllLed();
	for (i = 1; i < u8Len; i++) {
		uint8 c = *(pMsg + i);
		if (c < '0' || c > '9') {
			break;
		}
		min = min * 10 + c - '0';
	}
	sAppData.u32Sleepms = min * 60 * 1000;
.
219a
			if (c >= LEDREQ_BLINK10 && c <= LEDREQ_BLINK90) {
				int dutyPercent10 = (c - LEDREQ_BLINK10 + 1); // 1-9
				PCA9622_bSetBlink(j, MAX_BRIGHTNESS * dutyPercent10 / 10);
			}
.
218c
}

static void vParseMsgAndUpdateLed(uint8 *pMsg, uint8 u8Len)
{
	int i, j;
	for (i = 1, j = LEDIDX_OFFSET; i < u8Len && j < NUMLEDS; i++, j++) {
		uint8 c = *(pMsg + i);
		switch (c) {
		case LEDREQ_ON:
			PCA9622_vSet(j, MAX_BRIGHTNESS);
			break;
		case LEDREQ_OFF:
			PCA9622_vSet(j, 0);
			break;
.
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
	// スリープする時間
	uint32 u32Sleepms;
	// 前回LED制御コマンド受信時からの経過時間
	uint32 u32SpentFromRecv;
.
55,61d
47a
#define V_PRINTF(...) vfPrintf(&sSerStream,__VA_ARGS__)

#define NUMLEDS 16
#define MAX_BRIGHTNESS 0xff // 0-0xff
#define LEDIDX_OFFSET 1
#define LEDREQ_OFF     0x20 // ' '
#define LEDREQ_BLINK10 0x21 // '!' duty 10%
#define LEDREQ_BLINK90 0x29 // ')' duty 90%
#define LEDREQ_ON      0x2A // '*'

// TWE-Lite  ToCoStick+LininoONE
//    ----------> LED制御コマンド要求SEND
//    <---------- LED制御コマンド
#define SEND_INTERVAL 2000 // LED制御コマンド要求メッセージの送信間隔[ms]
#define RETRY_INTERVAL 500 // SEND後受信タイムアウト時再送間隔[ms]
#define VALIDTIME 5000 // 受信したLED制御コマンドの有効期間[ms]。5秒
#define RXTIMEOUT 64 // SEND後受信待ちタイムアウト時間[ms]
#define RAMOFF_SLEEPMS 60000 // この値以上sleepする際はメモリ保持しない [ms]
.
22c
#include "toiletled.h"
#include "SMBus.h"
#include "pca9622.h"
.
x
DIFF
echo 'so toiletled.c.diff' | vim -e -s toiletled.c
rm toiletled.c.diff
head -n 999 >pca9622.h << "EOF"
#ifndef __PCA9622_H__
#define __PCA9622_H__

bool_t PCA9622_bInit(uint16 blinkms);
void PCA9622_vSet(uint8 idx, uint8 duty);
bool_t PCA9622_bSetBlink(uint8 idx, uint8 duty);
bool_t PCA9622_bUpdate(void);

#endif // __PCA9622_H__
EOF
head -n 999 >pca9622.c << "EOF"
#include "jendefs.h"
#include "SMBus.h"
#include "pca9622.h"
#include "string.h" // for memset()

#define PCA9622_ADDRESS		0x70 // 7-bit address

static const uint8 LEDOUT0 = 0x14;
static const uint8 LEDOUT1 = 0x15;
static const uint8 LEDOUT2 = 0x16;
static const uint8 LEDOUT3 = 0x17;
static const uint8 LDR_PWM = 0x2; // 0x2: PWM

static uint8 au8Duty[16];

static bool_t PCA9622_bInitBlink(uint16 blinkms)
{
	bool_t bOk = TRUE;
	const uint8 MODE2 = 1;
	const uint8 DMBLNK = 5;
	uint8 data2 = 1 << DMBLNK; // DMBLNK=1: グループ制御=ブリンク
	bOk = bSMBusWrite(PCA9622_ADDRESS, MODE2, 1, &data2);

	const uint8 GRPFREQ = 0x13;
	int n = blinkms * 24 / 1000 - 1;
	uint8 datagf = n;
	if (n < 0) {
		datagf = 0;
	} else if (n > 0xff) {
		datagf = 0xff;
	}
	bOk &= bSMBusWrite(PCA9622_ADDRESS, GRPFREQ, 1, &datagf);
	return bOk;
}

static bool_t PCA9622_bInitLedoutPwm(void)
{
	const uint8 AIF = 0x80; // auto increment flag
	uint8 ALLPWM = (LDR_PWM << 6) | (LDR_PWM << 4) | (LDR_PWM << 2) | LDR_PWM;
	uint8 data[4] = {ALLPWM, ALLPWM, ALLPWM, ALLPWM}; // LEDOUT0-3
	return bSMBusWrite(PCA9622_ADDRESS, LEDOUT0 | AIF, 4, data);
}

bool_t PCA9622_bInitLedoutGrpPwm(uint8 idx, bool_t bGrp)
{
	const uint8 au8Cmd[] = {LEDOUT0, LEDOUT1, LEDOUT2, LEDOUT3};
	uint8 u8Cmd = au8Cmd[idx / 4];
	const uint8 LDR_GRPPWM = 0x3; // 0x3: PWM + GRPPWM
	const uint8 au8GrpPwm[] = {
		LDR_GRPPWM, LDR_GRPPWM << 2, LDR_GRPPWM << 4, LDR_GRPPWM << 6,
	};
	uint8 data = LDR_PWM | LDR_PWM << 2 | LDR_PWM << 4 | LDR_PWM << 6;
	if (bGrp) {
		data |= au8GrpPwm[idx % 4];
	}
	return bSMBusWrite(PCA9622_ADDRESS, u8Cmd, 1, &data);
}

bool_t PCA9622_bInit(uint16 blinkms)
{
	bool_t bOk = TRUE;
	memset(au8Duty, 0, sizeof(au8Duty));

	vSMBusInit();

	const uint8 MODE1 = 0;
	uint8 data1 = 0; // SLEEP off
	bOk = bSMBusWrite(PCA9622_ADDRESS, MODE1, 1, &data1);

	if (blinkms > 0) {
		bOk &= PCA9622_bInitBlink(blinkms);
	}
	bOk &= PCA9622_bInitLedoutPwm();
	return bOk;
}

void PCA9622_vSet(uint8 idx, uint8 duty)
{
	au8Duty[idx] = duty;
}

bool_t PCA9622_bSetBlink(uint8 idx, uint8 duty)
{
	PCA9622_vSet(idx, 0xff); // ON

	bool_t bOk = PCA9622_bInitLedoutGrpPwm(idx, TRUE);

	const uint8 GRPPWM = 0x12;
	bOk &= bSMBusWrite(PCA9622_ADDRESS, GRPPWM, 1, &duty);
	return bOk;
}

bool_t PCA9622_bUpdate(void)
{
	const uint8 PWM0 = 0x2;
	const uint8 AIF = 0x80; // auto increment flag
	return bSMBusWrite(PCA9622_ADDRESS, PWM0 | AIF, 16, au8Duty);
}
EOF
