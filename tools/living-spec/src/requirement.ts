// 要求票（docs/requirements/*.md）を読む。
// 見出し・欄の構造の検査は意図して作らない（README 参照）。読めない部分は「無い」ものとして寛容に扱い、
// 構造の違反は出さない（仕様節が無い票は仕様の行が0件の票、RDRA 欄が無い行は参照なしの行）。
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

export interface Requirement {
  // 表題「# 要求票: <UC 名>」から読んだ UC 名。読めなければ null
  ucName: string | null;
  // 「## 理由」節の本文（空行を除いた行を改行でつなぐ）。節が無ければ null（検査は読まない。描画が使う）
  reason: string | null;
  lines: RequirementLine[];
}

// 参照の欄の1要素。<種類>「<名前>」として読めなければ kind・name が null（raw は読もうとした文字列）
export interface Reference {
  raw: string;
  kind: string | null;
  name: string | null;
}

export function parseRequirement(source: string): Requirement {
  // HTML コメント（複数行にまたがる）の中は読まない。閉じていないコメントは末尾までをコメントとして扱う
  const text = source.replace(/^﻿/, '').replace(/<!--[\s\S]*?(?:-->|$)/g, '');
  const lines = text.split(/\r?\n/);
  let ucName: string | null = null;
  let titleSeen = false;
  let inSpec = false;
  let inReason = false;
  let reason: string[] | null = null;
  const out: RequirementLine[] = [];
  for (const line of lines) {
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
    const spec = line.match(/^\d+\.(?:\s+(.*?))?\s*$/);
    if (spec !== null) {
      out.push({ ordinal: out.length + 1, text: spec[1] ?? '', rdra: null, reason: null });
      continue;
    }
    const field = line.match(new RegExp(`^\\s+[-*]\\s+${REQUIREMENT_RDRA_FIELD}[:：]\\s*(.*?)\\s*$`));
    const current = out[out.length - 1];
    if (field !== null && current !== undefined && current.rdra === null) current.rdra = field[1];
    const reasonField = line.match(new RegExp(`^\\s+[-*]\\s+${REQUIREMENT_REASON_FIELD}[:：]\\s*(.*?)\\s*$`));
    if (reasonField !== null && current !== undefined && current.reason === null) current.reason = reasonField[1];
  }
  return { ucName, reason: reason === null ? null : reason.join('\n'), lines: out };
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
