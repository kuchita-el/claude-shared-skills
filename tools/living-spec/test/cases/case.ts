// 規則の試験の1件。ファイルを置かず、根からの相対パス → 中身の対応だけを渡す。
// 表のファイルが無ければ空の表として扱うため、その件の判定に要るものだけを書く。
export interface Case {
  // 通る件は pass-、落ちる件は fail- で始める
  name: string;
  files: Record<string, string>;
  // 期待する違反の (rule, file, target)。pass は空。fail は、その規則の違反だけを並べる
  expected: { rule: string; file: string; target: string }[];
  // 対象（target）→ その対象への違反の件数。集合の比較は同じ対象に重なる違反の数を見ないので、
  // 重ねて出すこと・重ねて出さないことを確かめる件だけが書く。書いた件は、全違反の対象ごとの件数が一致することを見る
  counts?: Record<string, number>;
}

// テンプレート文字列の先頭の改行と、共通の字下げを除く（YAML・Markdown・Gherkin を字下げして書くため）
export function t(strings: TemplateStringsArray, ...values: unknown[]): string {
  const raw = strings.reduce((acc, s, i) => acc + s + (i < values.length ? String(values[i]) : ''), '');
  const lines = raw.replace(/^\n/, '').replace(/\n[ \t]*$/, '\n').split('\n');
  const indents = lines.filter((l) => l.trim() !== '').map((l) => l.match(/^ */)![0].length);
  const cut = indents.length === 0 ? 0 : Math.min(...indents);
  return lines.map((l) => l.slice(cut)).join('\n');
}
