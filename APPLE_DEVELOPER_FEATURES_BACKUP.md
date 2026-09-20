# Apple Developer機能の復元メモ

リモートプッシュ通知（APNs / Firebase Messaging）を外す前の完全な状態は、次のGitブランチへ保存しています。

`codex/apple-developer-features-backup`

このブランチには、Push Notifications capability、通知用entitlements、Firebase Messaging、端末トークン登録、通知タップ時の画面遷移が含まれます。

将来これらを戻す場合は、現在の変更を消さずに差分を確認したうえで、このブランチからApple Developer関連部分だけを再統合してください。

## 実機・署名対応

Apple Developerの署名を使う実機起動とApp Store向け設定を外す直前の状態は、次のGitHubブランチにも保存しています。

`codex/apple-signing-device-support-backup`

現在のプロジェクトはApple Developerアカウントなしで確認できるよう、iOS Simulator専用です。実機起動やApp Store公開を再開するときは、このブランチからiPhone実機向けSDK、対応プラットフォーム、コード署名設定を戻してください。
