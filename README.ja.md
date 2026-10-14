# Vignette

<p align="right"><a href="README.md">English</a> · <a href="README.ko.md">한국어</a></p>

マルチモニター環境向けの軽量な macOS メニューバーアプリです。ディスプレイ
ごとに明るさを調整でき、ワンクリックで切り替えられる「映画鑑賞モード」は、
今映像を再生している画面だけを残してほかのすべての画面を暗くし、視線が
そちらに集中できるようにします。

韓国語・英語・日本語に対応しています。

## 主な機能

- **ディスプレイごとの明るさ調整** — 接続されているすべての画面に対して、
  メニューバーからそのまま操作できるスライダーを用意しています。
- **映画鑑賞モード** — 再生中の画面を選ぶと、ほかの接続中の画面すべてに
  やわらかいグラデーションのオーバーレイがかかります。オフにすればすぐに
  元に戻ります。
- **可能な場合は実際のバックライトを制御** — 内蔵パネルや DDC/CI に対応した
  外部モニターなど、実際に制御できる画面では、画面の上にオーバーレイを
  重ねるだけでなく実際のバックライト輝度そのものを下げます。対応していない
  環境では自動的にオーバーレイにフォールバックするため、明るさスライダーは
  どのモニターでも必ず目に見える効果を発揮します。

## 動作環境

- macOS 13 Ventura 以降
- Apple Silicon または Intel Mac

## インストール

Vignette はディスプレイのバックライトを制御するために、非公開・非公式の
macOS フレームワークを使用しています
([非公開 API を使う理由](#非公開-apiを使う理由) 参照)。そのため Mac App
Store では配布できず、以下のビルドも Apple Developer ID では署名されて
いません。初回起動時に Gatekeeper がブロックすることがあります — この
セクション末尾の案内を参照してください。

### Homebrew

```sh
brew tap mrKangHo/vignette https://github.com/mrKangHo/vignette
brew install --cask vignette
```

（このリポジトリ名が `homebrew-vignette` ではないため、tap の URL を明示的に
指定する必要があります。）以降のアップデート:
`brew update && brew upgrade --cask vignette`。

### 直接ダウンロード

[Releases ページ](https://github.com/mrKangHo/vignette/releases)から最新の
`Vignette-*.dmg` を取得して開き、Vignette.app を Applications フォルダへ
ドラッグしてください。

### Gatekeeper について

これらのビルドは Developer ID ではなく ad-hoc 署名のみのため、macOS が
Vignette.app について「壊れているため開けません」と表示することがあります。
実際には壊れていません — そのメッセージを信じる代わりに、検疫
(quarantine) フラグを解除してください。

```sh
xattr -cr /Applications/Vignette.app
```

または Finder で Vignette.app を右クリック（Control-クリック）し、「開く」
を選んで「開発元が未確認」の警告を承認してください。

### ソースからビルドする

```sh
git clone https://github.com/mrKangHo/vignette.git
cd vignette
tuist generate
```

生成された Xcode プロジェクトが開くので、`Vignette` スキームをビルド・実行
してください。[Tuist](https://tuist.dev) が必要です（`brew install tuist`）。

コマンドラインから直接ビルドする場合:

```sh
tuist generate --no-open
xcodebuild -workspace Vignette.xcworkspace -scheme Vignette -configuration Debug -destination 'platform=macOS' build
```

## 使い方

Vignette はメニューバーに常駐します（Dock アイコンはなく、重なり合った
2 つのディスプレイの形をしたアイコンを探してください）。アイコンを
クリックすると:

- 接続されている各ディスプレイの明るさを調整できます。
- 映画鑑賞モードを切り替え、今再生中の画面を選べます。

ポップオーバーの歯車アイコンから開く「設定」ウィンドウでは、映画鑑賞モードの
暗さの強さを調整できます。

## 非公開 APIを使う理由

ディスプレイのバックライトを制御する公式の macOS API は存在しません —
内蔵パネルでも、DDC/CI を使う外部モニターでも同様です。Vignette は、
macOS の Control Center や MonitorControl、Lunar といったツールが使って
いるのと同じ非公開のメカニズムを、`dlopen`/`dlsym` によって実行時に動的に
解決して使用しています。こうしておくことで、将来 Apple がこれらの
メカニズムを削除しても、Vignette はクラッシュするのではなく「ソフトウェア
オーバーレイのみ動作」という状態に自然にフォールバックします。

このため:

- Mac App Store には対応できず、Developer ID による署名・公証を通じた配布
  のみとなります。(このプロジェクトにはまだ Developer ID アカウントが
  ないため、現在のリリースは ad-hoc 署名のみです — [インストール](#インストール)
  を参照。)
- 外部モニターの明るさ制御（DDC/CI）はベストエフォートです — モニター、
  ケーブル、間に挟まる USB-C/Thunderbolt ハブによっては、特定の環境で
  まったく動作しないことがあります。その場合でもソフトウェアオーバーレイは
  常に動作する代替手段です。

## ライセンス

[MIT](LICENSE)
