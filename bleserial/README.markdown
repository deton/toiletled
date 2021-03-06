# BLESerial版トイレ使用中表示ランプ

![toiletled BLESerial版](../../img/toiletledbleserial.jpg)

Wi-Fi版での以下の課題を解決するため、
BLE経由でLED点灯・消灯を指示するようにした版です。

* 設置場所ではWi-Fiが切断されやすく、時々LEDが消えたままになる。
* バッテリ消費が大きく、毎日充電する必要がある。
* 設置前に、Wi-Fi接続用パスワードをストレージから消すのが手間。
* フルカラーLED 6個での表示では、色が識別しにくい人にとって不便。

ただし、現場では1時間以上経つとedison・BLESerial間のBLE通信がうまくいかなくなる現象が発生し、
一度両方の電源を入れ直さないと復活しないため、実適用は断念。

[BLE版](../ble)や[BLEアドバタイズ版](../bleadv)に移行。

## 構成

    LEDs === TLC5940 === Pro Trinket === BLESerial ---[BLE]--- edison ---[Wi-Fi]--- HTTPserver

## 部品
### BLESerial版
#### ソフトウェア
* toiletledble.js。HTTPでGETしたjsonをもとに、nobleライブラリでBLESerialに送信。
* toiletledble.ino。BLESerialが受信したデータをSerialで読んで、TLC5940ライブラリを使ってLED制御。

5階に置くので、遠くから5階の状況が判別しやすいように、5階用のLEDは点滅表示。

#### ハードウェア
* Intel edison
* BLESerial
* Pro Trinket
* TLC5940
* ブレッドボード
* LED 15個(緑黄赤を5セット)。
  どの階の状況かを判別しやすいように、階ごとに形の違うLEDを使用。
  (秋葉原で千石電商、マルツ、鈴商をまわって集めたもの。)
* 抵抗680Ω(小さすぎた。4.7kΩ程度が良さそう) 1個
* はさみで切れるユニバーサル基板
* ライトアングル ピンヘッダ 16ピン
* モバイルバッテリ
* microUSBケーブル
