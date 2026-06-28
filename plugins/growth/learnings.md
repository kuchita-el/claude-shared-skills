# growth 学び置き場（パブリック/グローバル空間）

検証済みの汎用の振る舞いルール（規範）を1ファイルに集約した配布物。各エントリは `## <規範の見出し>` ＋本文の1欄（振る舞い差分）で、メタ欄を持たない。形式・スキーマ・ライフサイクルは [`references/learning-store-spec.md`](references/learning-store-spec.md) を、昇格 Issue からエントリへの変換規約は [`references/learning-promotion-spec.md`](references/learning-promotion-spec.md) を参照。

以下は形式を示す記入例。

## ファイル復元には git restore を使う

ファイルを復元するとき git checkout ではなく git restore を使う。git checkout はブランチ切り替えと復元が多重定義されており、誤操作で別ブランチへ移る事故を招くため。

## 長文は CLI 引数に直接渡さず一時ファイル経由にする

Markdown 等の長文を CLI オプションに直接渡さない。ファイルへ書き出し `--body-file` 等で渡す。シェルのクォート・ヒアドキュメント制約による破損と、許可プロンプトの中断を避けるため。
