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
 * ブレッドボード
 * LED 15個(緑黄赤を5セット)
 * 抵抗4.7kΩ 1個
 * ライトアングル ピンヘッダ 16ピン
 * モバイルバッテリ
* 両方で使用
 * はさみで切れるユニバーサル基板

## はまった点
* 当初は、親機はToCoStick+LininoONE+dogUSBで作成していたが、
  電源によっては、LininoONEがWi-Fi接続できない場合があり、
  Edison+TWE-Liteに変更。

## 参考
* TWE-Liteを使った[PresenceLed (出退表示LED)](../../presenceled)
