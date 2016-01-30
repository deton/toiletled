# 赤色LED版トイレ使用中表示ランプ

各階1個のLED。全6階の建物の場合はLED 6個。

![toiletled接写](../../img/toiletled-closeupw.jpg)

下から5つ目のLEDだけずらしているのは、
ここが5階であることを示すためです(5階への設置用)。

## 部品
### ソフトウェア
* LininoIO (lininoIOイメージの20141014版)
* toiletled.py。sysfsでLED点灯制御
* MCU側はbathos-mcuio

### ハードウェア
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
* HTTPによる状況取得失敗時には失敗がわかるようなLED表示を行う。
  LininoONE本体の赤LED(D13)を点滅する等。

## WiFiの接続パスワードの抜き出し対策
丸ごと持ち去られて、WiFiの接続パスワード等を抜き出されると困るので、
メモリ上にのみ持つように設定して設置(電源を切ると消える)。

/etc/config/wirelessの設定を/usr/bin/wifi-reset-and-rebootと同様にresetする
wifi-resetコマンドを作っておいて実行し、
ストレージ上にはパスワードを持たないように設定。

* シリアル接続無効化:
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
* 2015-02-03版LininoIOイメージでは
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
