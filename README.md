# zaim-report

## これは何？

[Zaim API](https://dev.zaim.net/) を使って支出の週間レポートを LINE Notify を使って送信します。

## 事前準備

1. Zaim developers からアプリケーションを登録する
1. Zaim developers で登録したアプリケーションの `コンシューマ ID` と `コンシューマシークレット` を `var/consumer.json` に保存する
1. [LINE Notify](https://notify-bot.line.me/ja/) のマイページから、トークンを発行する
1. LINE Notify で発行したトークンを `var/line_notify.json` に保存する

## セットアップ

1. perl をインストール
1. 必要な cpan モジュールをインストール
    1. cpanfile を参照
    1. `cpanm --installdeps .` など、お好みの方法で
1. `oauth_comsumer.psgi` を立ち上げて、 `https?://<YOUR_DOMAIN>/auth` へアクセスして OAuth 認証を実施する


## レポート実行

1. `perl report.pl` を実行する


## レポートサンプル

```
10/20(日) 〜 10/26(土)

美容・衣服　:  20,000円
食費　　　　:  10,724円
お小遣い　　:   7,949円
教育・教養　:   5,291円
日用雑貨　　:   4,621円
医療・保険　:   3,510円
```
