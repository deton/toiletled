# フルカラーLED版トイレ使用中表示ランプ

![toiletledフルカラー版](../../img/toiletledfc.jpg)

NeoPixelフルカラーLEDを使用。

+ 赤色: 全て使用中
+ 黄色: 空きが1つ
+ 緑色: 空きが2つ以上
+ 消灯: 使用中状況取得不可(WiFi切断等)

緑色と消灯が分かれているので、
空きがあるのかWiFi切断されているのかを示せるのが、
赤色LED版と比べた利点の一つ。

### フルカラーLED版(Type2)
![toiletledフルカラー版2](../../img/toiletledfc2.jpg)

LininoONE本体内蔵WiFiだとつながりにくい場所に置きたかったので、
LininoONE用USBホスト拡張モジュール[dogUSB](http://akizukidenshi.com/catalog/g/gM-08903/)
を接続して、USB WiFiアダプタLogitec LAN-W300N/U2Sを使用。

#### [USB WiFiを使用する方法](http://www.lucadentella.it/en/2014/11/08/yun-adattatore-wifi-usb/)
rt2800usbドライバはLininoONEのパッケージには無いので、
Arduino Yun用のものを無理やり入れる。

/etc/opkg.confにyun用リポジトリを追加。
`option check_signature`をコメントアウト。

    src/gz yun http://downloads.arduino.cc/openwrtyun/1/packages

`opkg update`後、`--force-depends`付きでopkg install。

    opkg --force-depends install kmod-rt2800-lib kmod-rt2800-usb kmod-rt2x00-lib kmod-rt2x00-usb

これで、WLI-UC-GNMは刺せば認識されるようになる
(が、APとしては動かないようなので少し不便)。
LAN-W300N/U2Sは、/etc/hotplug.d/usb/に以下のファイル10-lanw300nu2sを作成。

```
#!/bin/sh
# Logitec LAN-W300N/U2S
PRODID="789/169/101"

# echo "$PRODUCT" > /tmp/lan-w300nu2s
if [ "$PRODUCT" = "$PRODID" ]; then
	case "$ACTION" in
		add)
			echo "0789 0169" > /sys/bus/usb/drivers/rt2800usb/new_id
			;;
		remove)
			;;
	esac	
fi
```

その他の設定は、
http://www.lucadentella.it/en/2014/11/08/yun-adattatore-wifi-usb/
の記述と同様。

* rebootしても/etc/config/wirelessにradio1が追加されない場合は、
  `wifi detect >> /etc/config/wireless`
* /usr/bin/wifi-live-or-reset内のIFACEをwlan1等に変更。

* LininoONEからの5V出力ピンがdogUSBで使われるので、
  LED用にはモバイルバッテリから供給。
  aitendoで売っていた、[USB-DCプラグケーブル](http://www.aitendo.com/product/4676)と、
  [DCジャック](http://www.aitendo.com/product/7373)を使用。
* モバイルバッテリQE-PL102(2700mAh)だと3時間程度しか持たなくなったので、
  大容量のモバイルバッテリcheero Energy Plus 12000mAhを使用。
* LininoONEは[外部アンテナ非対応](http://forum.arduino.cc/index.php?topic=188976.0)。
  実装されているのはテスト用コネクタ。外部アンテナを固定できない。
  ケースをうまく作れば固定できるかもしれないけど。

## 部品
### ソフトウェア
* LininoOS (`linup latest master`)
* toiletledfc.py。bridge.py経由でMCU側に色を指示。
* toiletledfc.ino。bridge.py経由で指定された色を、NeoPixelライブラリに指示

### ハードウェア
* [Linino ONE](https://www.switch-science.com/catalog/2152/)。
  [Arduino Yun](http://arduino.cc/en/Guide/ArduinoYun)の小型版。
  Arduino用マイコン(ATmega32u4, lininoのドキュメントではMCU)と、
  Linux(OpenWrt)用CPU(Atheros AR9331, MIPS)が載っていて、WiFi接続可能。5V IO
* [NeoPixel RGB Module 8mm 基板付き](http://www.akiba-led.jp/product/963) 6個
* ピンヘッダ 3ピン
* はさみで切れるユニバーサル基板
* モバイルバッテリ
* microUSBケーブル

## WiFiの接続パスワードの抜き出し追加対策
* bridge.pyの停止無効化(bridge.py.patch):
LininoONEのVinに電源を供給しながらmicroUSBケーブルをさしかえて、
MCU側にLininoOneSerialTerminalを書き込んで、
シリアル接続してLinux側に入られないようにするため、
/usr/lib/python2.7/bridge/bridge.pyが動き続けるように変更。
