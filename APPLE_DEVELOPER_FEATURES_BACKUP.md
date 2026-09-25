# Apple Developer機能の復元メモ

リモートプッシュ通知（APNs / Firebase Messaging）を外す前の完全な状態は、次のGitブランチへ保存しています。

`codex/apple-developer-features-backup`

このブランチには、Push Notifications capability、通知用entitlements、Firebase Messaging、端末トークン登録、通知タップ時の画面遷移が含まれます。

将来これらを戻す場合は、現在の変更を消さずに差分を確認したうえで、このブランチからApple Developer関連部分だけを再統合してください。

## 実機・署名対応

Apple Developerの署名を使う実機起動とApp Store向け設定を外す直前の状態は、次のGitHubブランチにも保存しています。

`codex/apple-signing-device-support-backup`

現在のプロジェクトはiPhone実機向けビルド対応を維持しています。プッシュ通知などのApple Developer固有機能を再開するときは、このブランチから必要な設定を戻してください。なお、実機へのインストールと起動にはAppleの仕様上コード署名が必要です。

Apple Developerの申請待ち期間用として、現在のmainでは固定Team IDを設定していません。iOS SimulatorではApple Developerアカウントなしで開発を継続でき、iPhone実機向けSDKとターゲットは残しています。申請承認後に戻すTeam設定は、次のGitHubブランチへ保存しています。

`codex/apple-developer-approved-setup`

申請待ち中のDebug構成は、実機向けコードを含めて署名なしでコンパイルできるようにしています。これによりBuildは可能ですが、署名がないアプリをiPhoneへインストール・起動することはできません。承認後は上記ブランチを参照してDebugのコード署名とTeam IDを戻します。
