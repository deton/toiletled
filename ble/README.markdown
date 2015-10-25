# BLE版トイレ使用中表示ランプ

![toiletled BLE版](../../img/toiletledble.jpg)

[BLESerial](../bleserial)版だと、現場では1時間以上経つとうまく動かなくなる現象が発生したので、
mbed HRM1017を使用。

## 構成

    LEDs === TLC5940 === mbed HRM1017 ---[BLE]--- edison ---[Wi-Fi]--- HTTPserver

## 部品
### BLE版
#### ソフトウェア
* toiletledble.js。HTTPでGETしたjsonをもとに、nobleライブラリでmbed HRM1017に送信。
 * toiletledble.service等のファイルは、「[IoTっぽい温度ロガーを作った](http://www.kaoriya.net/blog/2015/08/02/)」の記事を参考に作成。
* [ToiletLED](https://developer.mbed.org/users/deton/code/ToiletLED/)。BLEでデータが書き込まれたら、TLC5940ライブラリを使ってLED制御。

#### ハードウェア
* Intel edison
* mbed HRM1017
* TLC5940
* ブレッドボード
* LED 15個(緑黄赤を5セット)
* 抵抗680Ω 1個
* はさみで切れるユニバーサル基板
* ライトアングル ピンヘッダ 16ピン
* モバイルバッテリ
* microUSBケーブル

## はまった点
* mbed HRM1017でのBLEは、BLE_API等を最新版にすると、edisonからhcitool lescanしても見えない模様。
  developer.mbed.orgサイトでHRM1017を使っているものを探して、そのうちの動くものを流用。
* mbed HRM1017(nRF51822)は、TLC5940制御で使う
  [SPIの12bit formatに対応していない](https://developer.mbed.org/questions/4085/SPI-on-nRF51822/)
  ようなので、TLC5940ライブラリをSWSPIを使うように変更する必要あり。
* 80分程度経つと動かなくなる。TLC5940ライブラリ内部でのTickerクラス使用をやめることで回避。
  (使っているmbedライブラリのバージョンがTickerクラスに問題のあるものなのかも)
  [参考](https://developer.mbed.org/questions/53738/wait_ms-and-Ticker-slow-to-a-crawl-but-o/)
