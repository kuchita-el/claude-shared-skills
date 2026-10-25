// 要求票（<requirements>/*.md）を読む。
// 読めない部分は「無い」ものとして寛容に読む（仕様節が無い票は仕様の行が0件の票、RDRA 欄が無い行は参照なしの行）。
// そのうえで、雛形の構造から外れた箇所を issues に集める（requirement-structure が出す）。寛容に読んだ結果だけを見る
// 他の規則が、構造の誤りを黙って読み飛ばさないようにするため。
import {
  REQUIREMENT_NO_REFERENCE,
  REQUIREMENT_RDRA_FIELD,
  REQUIREMENT_REASON_FIELD,
  REQUIREMENT_REASON_HEADING,
  REQUIREMENT_SPEC_HEADING,
  REQUIREMENT_TITLE_LABEL,
} from './schema.ts';

export interface RequirementLine {
  // 仕様節の何番目の番号つきの行か（1始まり。書かれた番号ではなく並び順。番号は識別子ではない）
  ordinal: number;
  // 要求文（番号を除いた本文）
  text: string;
  // 直後の「- RDRA: 」の値。欄が無ければ null
  rdra: string | null;
  // 直後の「- 理由: 」の値。欄が無ければ null（検査は読まない。描画が使う）
  reason: string | null;
}

// 雛形の構造から外れた箇所。target は違反の target（見出し:<名>・仕様:<N>・行:<行番号>）
export interface StructureIssue {
  target: string;
  detail: string;
}

export interface Requirement {
  // 表題「# 要求票: <UC 名>」から読んだ UC 名。読めなければ null
  ucName: string | null;
  // 「## 理由」節の本文（空行を除いた行を改行でつなぐ）。節が無ければ null（検査は読まない。描画が使う）
  reason: string | null;
  lines: RequirementLine[];
  issues: StructureIssue[];
}

// 参照の欄の1要素。<種類>「<名前>」として読めなければ kind・name が null（raw は読もうとした文字列）
export interface Reference {
  raw: string;
  kind: string | null;
  name: string | null;
}

export function parseRequirement(source: string): Requirement {
  // HTML コメント（複数行にまたがる）の中は読まない。閉じていないコメントは末尾までをコメントとして扱う。
  // 行番号を保つため、コメントは中の改行だけを残して消す
  const text = source
    .replace(/^\uFEFF/, '')
    .replace(/<!--[\s\S]*?(?:-->|$)/g, (c) => c.replace(/[^\n]/g, ''));
  const lines = text.split(/\r?\n/);
  let ucName: string | null = null;
  let titleSeen = false;
  let inSpec = false;
  let inReason = false;
  let reason: string[] | null = null;
  const out: RequirementLine[] = [];
  const issues: StructureIssue[] = [];
  const headings = new Set<string>();
  // 仕様の行ごとに、欄を何回書いたか
  const fieldCount: { rdra: number; reason: number }[] = [];
  const fieldRe = (name: string) => new RegExp(`^\\s+[-*]\\s+${name}[:：]\\s*(.*?)\\s*$`);
  for (const [i, line] of lines.entries()) {
    if (/^#\s/.test(line)) {
      // 最初のレベル1見出しだけが表題
      if (!titleSeen) {
        titleSeen = true;
        const m = line.match(new RegExp(`^#\\s+${REQUIREMENT_TITLE_LABEL}[:：]\\s*(.*?)\\s*$`));
        ucName = m !== null && m[1] !== '' ? m[1] : null;
      }
      continue;
    }
    if (/^##\s/.test(line)) {
      const heading = line.replace(/^##\s+/, '').trim();
      if (heading !== REQUIREMENT_REASON_HEADING && heading !== REQUIREMENT_SPEC_HEADING) {
        issues.push({ target: `見出し:${heading}`, detail: `雛形に無い見出し「## ${heading}」（見出しは「## ${REQUIREMENT_REASON_HEADING}」「## ${REQUIREMENT_SPEC_HEADING}」に限る）` });
      } else if (headings.has(heading)) {
        issues.push({ target: `見出し:${heading}`, detail: `見出し「## ${heading}」が2回以上ある` });
      }
      headings.add(heading);
      inSpec = heading === REQUIREMENT_SPEC_HEADING;
      inReason = heading === REQUIREMENT_REASON_HEADING;
      if (inReason && reason === null) reason = [];
      continue;
    }
    if (inReason) {
      if (line.trim() !== '') reason!.push(line.trim());
      continue;
    }
    if (!inSpec) continue;
    if (line.trim() === '') continue;
    const spec = line.match(/^\d+\.(?:\s+(.*?))?\s*$/);
    if (spec !== null) {
      out.push({ ordinal: out.length + 1, text: spec[1] ?? '', rdra: null, reason: null });
      fieldCount.push({ rdra: 0, reason: 0 });
      if ((spec[1] ?? '') === '') issues.push({ target: `仕様:${out.length}`, detail: '要求文が空' });
      continue;
    }
    const current = out[out.length - 1];
    const field = line.match(fieldRe(REQUIREMENT_RDRA_FIELD));
    const reasonField = line.match(fieldRe(REQUIREMENT_REASON_FIELD));
    if (current === undefined || (field === null && reasonField === null)) {
      issues.push({
        target: `行:${i + 1}`,
        detail: `仕様の節に読めない行「${line.trim()}」（番号つきの要求文と、その直下に字下げした「- ${REQUIREMENT_RDRA_FIELD}: 」「- ${REQUIREMENT_REASON_FIELD}: 」の欄だけを書く）`,
      });
      continue;
    }
    const count = fieldCount[fieldCount.length - 1];
    if (field !== null) {
      count.rdra++;
      if (current.rdra === null) current.rdra = field[1];
    } else {
      count.reason++;
      if (current.reason === null) current.reason = reasonField![1];
    }
  }
  if (!headings.has(REQUIREMENT_REASON_HEADING)) {
    issues.push({ target: `見出し:${REQUIREMENT_REASON_HEADING}`, detail: `見出し「## ${REQUIREMENT_REASON_HEADING}」が無い` });
  }
  if (!headings.has(REQUIREMENT_SPEC_HEADING)) {
    issues.push({ target: `見出し:${REQUIREMENT_SPEC_HEADING}`, detail: `見出し「## ${REQUIREMENT_SPEC_HEADING}」が無い` });
  }
  for (const [k, c] of fieldCount.entries()) {
    for (const [name, n] of [[REQUIREMENT_RDRA_FIELD, c.rdra], [REQUIREMENT_REASON_FIELD, c.reason]] as const) {
      if (n === 0) issues.push({ target: `仕様:${k + 1}`, detail: `「- ${name}: 」の欄が無い（書くことが無ければ「なし」と書く）` });
      if (n > 1) issues.push({ target: `仕様:${k + 1}`, detail: `「- ${name}: 」の欄が2回以上ある（最初の欄だけを読む）` });
    }
  }
  return { ucName, reason: reason === null ? null : reason.join('\n'), lines: out, issues };
}

// 参照の欄を「、」区切りの要素へ分ける。名前の「」の中の「、」では分けない。
// 欄が無い・空・「なし」は参照なし
export function parseReferences(rdra: string | null): Reference[] {
  if (rdra === null) return [];
  const value = rdra.trim();
  if (value === '' || value === REQUIREMENT_NO_REFERENCE) return [];
  const parts: string[] = [];
  let depth = 0;
  let current = '';
  for (const ch of value) {
    if (ch === '「') depth++;
    if (ch === '」' && depth > 0) depth--;
    if (ch === '、' && depth === 0) {
      parts.push(current);
      current = '';
      continue;
    }
    current += ch;
  }
  parts.push(current);
  return parts.map((p) => {
    const raw = p.trim();
    const m = raw.match(/^([^「」]+)「(.+)」$/);
    if (m === null || m[2].trim() === '') return { raw, kind: null, name: null };
    return { raw, kind: m[1].trim(), name: m[2].trim() };
  });
}
