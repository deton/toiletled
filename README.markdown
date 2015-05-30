# トイレ使用中表示ランプ

会社のトイレ前に置く、個室が全て使用中かどうかを表示するLEDです。

![toiletled写真](../img/toiletledw.jpg)

その階の全個室が使用中の場合は赤LEDを点灯します
(電車のトイレの使用中ランプと同様)。
各階1個のLED。全6階の建物の場合はLED 6個。

* トイレのドアを開けなくても、個室が全て使用中かどうかわかる
* どの階に空きがあるかが表示されるので、
  今いる階が全て使用中の場合に、上と下のどちらの階に向かえばいいかわかる

最近、他の部の人が、各個室の使用中状況をWebで取得できるようにしてくれました
(リードスイッチ、TWE-Lite、Raspberry Piを使っている模様)。

自席PCやスマホのWebブラウザで確認できて便利になったのですが、
確認せずに席を立ってしまったり、トイレまで移動する間に状況が変わる場合もあって、
結局トイレのドアを開けて確認することが多く、
トイレ前に使用中かどうかを表示するモノがあると便利そうだったので作成。

全て使用中の場合、他の階に行くことになるのですが、
上の階に行くか下の階に行くか判断したいので、他の階の使用中状況も表示します。

WiFi接続して2秒おきに状況取得を行います。

## フルカラーLED版
![toiletledフルカラー版](../img/toiletledfc.jpg)

NeoPixelフルカラーLEDを使用。

+ 赤色: 全て使用中
+ 黄色: 空きが1つ
+ 緑色: 空きが2つ以上
+ 消灯: 使用中状況取得不可(WiFi切断等)

緑色と消灯が分かれているので、
空きがあるのかWiFi切断されているのかを示せるのが、
赤色LED版と比べた利点の一つ。

### フルカラーLED版(Type2)
![toiletledフルカラー版2](../img/toiletledfc2.jpg)

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

これで、WLI-UC-GNMは刺せば認識されるようになる。
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

## 赤色LED版

![toiletled接写](../img/toiletled-closeupw.jpg)

下から5つ目のLEDだけずらしているのは、
ここが5階であることを示すためです(5階への設置用)。

## 部品
### フルカラーLED版
#### ソフトウェア
* LininoOS (`linup latest master`)
* toiletledfc.py。bridge.py経由でMCU側に色を指示。
* toiletledfc.ino。bridge.py経由で指定された色を、NeoPixelライブラリに指示

#### ハードウェア
* [Linino ONE](https://www.switch-science.com/catalog/2152/)。
  [Arduino Yun](http://arduino.cc/en/Guide/ArduinoYun)の小型版。
  Arduino用マイコン(ATmega32u4, lininoのドキュメントではMCU)と、
  Linux(OpenWrt)用CPU(Atheros AR9331, MIPS)が載っていて、WiFi接続可能。5V IO
* [NeoPixel RGB Module 8mm 基板付き](http://www.akiba-led.jp/product/963) 6個
* ピンヘッダ 3ピン
* はさみで切れるユニバーサル基板
* モバイルバッテリ
* microUSBケーブル

### 赤色LED版
#### ソフトウェア
* LininoIO (lininoIOイメージの20141014版)
* toiletled.py。sysfsでLED点灯制御
* MCU側はbathos-mcuio

#### ハードウェア
* [Linino ONE](http://akizukidenshi.com/catalog/g/gM-08902/)。
  sysfsでGPIO制御可。
* 赤色LED 6個
* 抵抗680Ω 6個
* ライトアングル ピンヘッダ 7ピン
* はさみで切れるユニバーサル基板
* モバイルバッテリ
* microUSBケーブル

## 改良案
* ぽん置きで使えるように、LininoONEから直接2秒おきに状況取得を行っているが、
  2秒おきの状況取得はサーバで行って、
  LininoONEに置いたLED点灯・消灯を行うCGIスクリプトをたたく方が、
  バッテリが持つかも。
  状況表示ランプ台数が増えた場合もサーバでやる方が良さそう。
  サーバ側でのsubscriber管理はPubSubHubbubやMQTTを使う方が楽かも。
* WiFiの接続パスワードの抜き出し対策を行うと不便になるので、
  ZigBee(TWE-Lite)やBluetoothで外部から
  LED点灯・消灯を指示する形の方が良いかも。
  一方で、ZigBeeやBluetoothの場合、送信側の設置が必要になって面倒な点も。
  (センシング情報を集める部分でTWE-LiteとRaspberry Piを使っているようなので、
  理想的には、そこに状況表示ランプ制御機能を追加。)
* (赤LED版)HTTPによる状況取得失敗時には失敗がわかるようなLED表示を行う。
  LininoONE本体の赤LED(D13)を点滅する等。

## WiFiの接続パスワードの抜き出し対策
丸ごと持ち去られて、WiFiの接続パスワード等を抜き出されると困るので、
メモリ上にのみ持つように設定して設置(電源を切ると消える)。

/etc/config/wirelessの設定を/usr/bin/wifi-reset-and-rebootと同様にresetする
wifi-resetコマンドを作っておいて実行し、
ストレージ上にはパスワードを持たないように設定。

* (赤色LED版)シリアル接続無効化:
LininoONEのVinに電源を供給しながらmicroUSBケーブルをさしかえて
シリアル接続されないように、/etc/inittabの/bin/ash --loginをコメントアウトして
reboot。

    (単にinit -qでinittabを読み直しても、
    ashが起動したままなのでシリアル接続可能。ashをkillしておく必要あり。
    また、sysfsのexport設定をしたままinit -qすると
    LED点灯ができなくなるようなので、rebootするのが確実)

    (シリアル接続時もパスワード入力要にできれば良いのだけど、
    LininoONEでは未対応の模様。
    [/bin/loginが無い](https://forum.openwrt.org/viewtopic.php?id=16900)ので。
    agettyパッケージを入れるといいかも)

* (フルカラーLED版)bridge.pyの停止無効化(bridge.py.patch):
LininoONEのVinに電源を供給しながらmicroUSBケーブルをさしかえて、
MCU側にLininoOneSerialTerminalを書き込んで、
シリアル接続してLinux側に入られないようにするため、
/usr/lib/python2.7/bridge/bridge.pyが動き続けるように変更。

* cron設定:
DHCPで割り当てられたIPアドレスを知るため、
cronで5分間隔で特定サーバにcurlでアクセスする設定をしておく。
httpdのアクセスログを見ればわかるように。

* モバイルバッテリが11時間程度しか持たない(QE-PL102 2700mAh)ので
  毎日設定し直す必要があり面倒。
    + 一番楽なのは、給電中も充電可能なモバイルバッテリを使用する方法
    + Vinからの電源供給に切り替えて起動したままにして、モバイルバッテリを充電。
    + 電源を落とす前に、ssh接続してWiFi接続パスワード等を再設定してhalt;exit
        - 起動するとstationモードでWPA2 Enterprise接続される
        - 割り当てられるIPアドレスを、cronで設定しておいたアクセス先サーバの
          ログから調べてsshしてwifi-reset
        - `python toiletled.py <url>`
    + 再設定しないで(wifi-reset後の状態で)電源を落とした場合や、
      WiFiリセットボタンを5秒以上30秒未満押し続けて離してWiFiリセットした場合は、
      APモードで起動するので、
        - APにWiFi接続して、192.168.240.1にsshしてWiFi設定してwifiコマンド。
        - stationモードでWPA2 Enterprise接続される。
        - sshしてwifi-resetしてpython toiletled.py

## はまった点
* (赤色LED版)2015-02-03版LininoIOイメージでは
  [WPA2 Enterprise接続](https://github.com/deton/phsringnotify#linino-one%E3%81%A7%E3%81%AEwpa2-enterprise%E3%81%B8%E3%81%AE%E6%8E%A5%E7%B6%9A%E6%96%B9%E6%B3%95)
  が成功せず。
  associatedの後10秒程度で、`deauthenticating from xx:xx:... by local choice (Reason: 3=DEAUTH_LEAVING)`。
  以前は問題なく接続できていたので、
  `linup 20141014.0 lininoIO`で2014-10-14版LininoIOイメージに戻して、
  opkg.confも20141014.0にしてwpadを入れて使ったら問題なし。
* /etc/config/wirelessのnetwork値はlanでなくmyNetwork等にした方がいいかも。
  lanだとDHCPサーバが動いて既存DHCPサーバとぶつかるかもしれないので。
  ただしその場合、/usr/bin/wifi-reset-and-rebootにもnetworkをlanにリセットする
  設定を追加する必要あり。
  でないと、WiFiリセットボタンでリセットしてAPモードになっても、
  DHCPサーバとして動作せず、
  APに接続したPCにIPアドレスが割り当てられなくて困るので。
* 社内ネットが10.0.0.0等の場合、
  dnsmasqサーバの設定(/etc/config/dhcp)でrebind_protectionは0にする必要あり。
  でないと上位DNSからの検索結果を通してくれない。
