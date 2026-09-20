# Apple Developer機能の復元メモ

リモートプッシュ通知（APNs / Firebase Messaging）を外す前の完全な状態は、次のGitブランチへ保存しています。

`codex/apple-developer-features-backup`

このブランチには、Push Notifications capability、通知用entitlements、Firebase Messaging、端末トークン登録、通知タップ時の画面遷移が含まれます。

将来これらを戻す場合は、現在の変更を消さずに差分を確認したうえで、このブランチからApple Developer関連部分だけを再統合してください。

