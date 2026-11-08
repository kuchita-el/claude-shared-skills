// 基準の版（git の版）から読んだ正本の中身。読み出しを持つこのモジュールが、自分の結果の型を持つ。
// 描画のモジュール（view.ts・diffview.ts・html.ts・render.ts）に依存しない。基準の版との差分の一覧（#935）が、
// このモジュールと diff.ts だけを使うときに、描画の側への依存が付いてこないようにするため。
import type { Sources } from './sources.ts';

export interface BaseVersion {
  // 利用者が指定した版の文字列
  ref: string;
  // 版が指すコミット
  commit: string;
  // 基準の版の木から、その版の置き場の設定どおりに読んだ表・要求票・例
  sources: Sources;
}
