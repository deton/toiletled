# BLEアドバタイズ版トイレ使用中表示ランプ

![toiletled BLEアドバタイズ版現場写真](../../img/toiletledbleadvw.jpg)

![toiletled BLEアドバタイズ版](../../img/toiletledbleadv.jpg)

mbed HRM1017を使って作成した、[BLE版](../ble)だと、
コネクション確立のためのコードが必要なのと、
バッテリ使用量が多いような気がしたので、
コネクション無しで、BLE advertising packetにLED制御情報を入れて送る形の版を作成。

## 構成

    LEDs === TLC5940 === BLE nano---[BLE]--- edison ---[Wi-Fi]--- HTTPserver

edisonがBLE broadcaster、BLE nanoがBLE observer。

## 部品
### BLEアドバタイズ版
#### ソフトウェア
* toiletledbcast.js。HTTPでGETしたjsonをもとに、blenoライブラリでBLE advertising packetを定期的に送信。
 * hci.js.diff: node_modules/bleno/lib/hci-socket/hci.jsを変更して、advertising packetをADV_NONCONN_INDで送信するための差分。でないとWindowsのBluetooth管理画面に表示されて邪魔なので。
* [ToiletLED_observer](https://developer.mbed.org/users/deton/code/ToiletLED_observer/)。BLE advertising packetをscanして受信したら、TLC5940ライブラリを使ってLED制御。

#### ハードウェア
* Intel edison
* BLE nano
* TLC5940
* ブレッドボード
* LED 15個(緑黄赤を5セット)
* 抵抗680Ω 1個
* はさみで切れるユニバーサル基板
* ライトアングル ピンヘッダ 16ピン
* モバイルバッテリ
