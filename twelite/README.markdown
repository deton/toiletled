# TWE-Lite版トイレ使用中表示ランプ

![toiletled TWE-Lite版](../../img/toiletledtwelite.jpg)

BLE Nanoを使った[BLEアドバタイズ版](../bleadv)だと、
感度が悪く、受信に失敗する場合が多かったので、TWE-Lite版を作成。

また、BLEの場合、LED表示側が一定時間ごとに親側から
LED制御コマンドを受けとる動作が少し面倒。

+ BLEアドバタイズの場合は、アドバタイズとスキャンのタイミングによっては、
  スキャン時間が長くなって電力消費が増える。
+ コネクションを作る場合は、コネクション確立が必要なのと、
  コネクション維持のためのパケットが送られて電力を消費するような気がする。

## 構成

    LEDs === TLC5940 === TWE-Lite(子機) --- TWE-Lite(親機)+Edison ---[Wi-Fi]--- HTTPserver

情報の流れは以下。

    TWE-Lite(子機)  TWE-Lite(親機)   Edison        HTTPserver
                                        --------------> トイレ使用中状況HTTP GET
                          <------------- SerialでLED制御コマンド書き込み
                        ...
             ----------> LED制御コマンド要求SEND
             <---------- LED制御コマンド

## 部品
### ソフトウェア
* toiletled.py。2秒おきにトイレ使用中状況JSONをHTTP GETして、
  UART1(/dev/ttyMFD1)にLED制御コマンドとして書き出し。
* genToiletled.sh。TWE-Lite(親機、子機)用ファームウェアのソース生成スクリプト。

#### Edison側
TWE-Lite親機にSerialでLED制御コマンドを書き出すためpyserialを使っているので、
pipをインストール後、`pip install pyserial`

Edison起動時に自動起動するように、
twelite.serviceファイルを、/etc/systemd/system/にコピーして、
`systemctl enable twelite`

#### TWE-Lite用ファームウェア
ソースはSamp_PingPongをベースにしていますが、
Samp_PingPongのソースはTOCOSの許可が無いと公開禁止との記述があって面倒なので、
差分のみ公開。
[ToCoNet SDK](http://mono-wireless.com/jp/products/ToCoNet/TWESDK.html) 2014/8月号に対する差分です。

以下のように、TWESDK/Wks_ToCoNet/ディレクトリでgenToiletled.shを実行すると、
toiletledディレクトリを作ります。
TWESDK/Tools/cygwin/Cygwin.batで起動したcygwinのプロンプト上で、
```sh
cd /cygdrive/d/TWESDK/Wks_ToCoNet
/cygdrive/c/Users/deton/Downloads/genToiletled.sh
```

+ Serial2Send。親機用ファームウェア。
  シリアルからLED制御コマンドを読んで、子機からの問い合わせがあった時に返信。
+ toiletled。子機用ファームウェア。
  2秒おきに親機に対してLED制御コマンドを要求。
  返信を受けたら、TLC5940を使ってLED制御。

toiletled/Common/Source/config.hのAPP_IDは、
親機のシリアル番号(S/N)+0x80000000に変更する必要あり。

makeコマンドでのビルドのみ確認(Eclipseでは未確認)。

### ハードウェア
* TWE-Lite DIP 2個
* 親機側
 * Intel Edison
 * [スイッチサイエンス版Eaglet (MFTバージョン)](https://www.switch-science.com/catalog/2070/)。
   TWE-Lite(親機)に3.3Vを供給しつつ、EdisonのUART1と接続。
 * 細ピンヘッダ 4本
 * 丸ピンソケット 8個
* 子機側
 * TLC5940
 * モバイルバッテリ + モバイルバッテリのUSB 5V出力を3.3Vに変換するアダプタ。
   [ブレッドボード用5V/3.3V電源ボード Micro-B版](https://www.switch-science.com/catalog/2398/)
   または、[DIP化3.3/5V電源キット [brebo.jam.dc]](http://www.aitendo.com/product/12124)
                - または、単3形ニッケル水素電池2本 + 電池ケース。(1.2Vとの表記があるので3本にしたら充電直後4.1VあってTWE-Lite動かず)
 * ブレッドボード
 * LED 15個(緑黄赤を5セット)
 * 抵抗4.7kΩ 1個
 * ライトアングル ピンヘッダ 16ピン
* 両方で使用
 * はさみで切れるユニバーサル基板

## TWE-Lite+PCA9622版
LEDドライバとして、TLC5940のかわりにPCA9622を使用する版
(PCA9622だと各LED用抵抗が必要になるので、PCA9955の方が楽そう)。

LEDブリンクはPCA9622が行うので、通信しない間はTWE-Liteはスリープ可能。

genToiletled.shのかわりに、genToiletledPca9622.shで
TWE-Lite用ファームウェアを生成。

追加部品:

* [PCA9622DR I2C 16ch LEDドライバ基板](https://www.switch-science.com/catalog/2388/)
* 抵抗330Ω 15個
* 抵抗2.2kΩ 2個。I2Cプルアップ用

![toiletled TWE-Lite+PCA9622版](../../img/toiletledtwelitePca9622.jpg)

## はまった点
* 当初は、親機はToCoStick+LininoONE+dogUSBで作成していたが、
  電源によっては、LininoONEがWi-Fi接続できない場合があり、
  Edison+TWE-Liteに変更。

## 参考
* [マイコンにプラス! シリアル拡張IC サンプルブック[基板付き]](http://shop.cqpub.co.jp/hanbai/books/48/48121.html)。PCA9622DRの使い方等
* TWE-Liteを使った[PresenceLed (出退表示LED)](../../presenceled)
