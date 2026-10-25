// 要求票（LAYOUT.requirements）と例（LAYOUT.examples）の名前照合・追跡の検査。
// RDRA の表から読んだ内容は check.ts が TraceContext として渡す。
// 違反は2つに分けて返す。名前照合・追跡の違反（checked）は全体検査に含め、書き漏らしの向きの違反（docMissing）は含めない。
import type { Violation } from './check.ts';
import { parseExample } from './example.ts';
import type { ExampleFeature, ExampleScenario } from './example.ts';
import { parseReferences, parseRequirement } from './requirement.ts';
import type { Reference, Requirement } from './requirement.ts';
import {
  EXAMPLE_LIMIT,
  LAYOUT,
  REQUIREMENT_KINDS,
  REQUIREMENT_STATE_SEP,
  tableById,
} from './schema.ts';
import type { Sources } from './sources.ts';

export interface TraceContext {
  // UC の表のレコード。hypothesis は『仮説』キーを持つか（値が空でも持つ扱い）
  useCases: { name: string; hypothesis: boolean; conditions: string[] }[];
  // 種類 → 表にある名前の集合。状態モデルは状態の表の状態モデル名。表のファイルが無ければ空
  names: Map<string, Set<string>>;
  // 状態モデル → その中に「状態」または「遷移先状態」として現れる状態名
  statesOf: Map<string, Set<string>>;
  // 遷移UC・遷移先状態がともに空でない状態の表のレコード。target は状態の表の作法の文字列
  transitions: { model: string; uc: string; next: string; target: string }[];
}

export interface TraceResult {
  // 名前照合・追跡の違反。全体検査（checkRepo）に含める
  checked: Violation[];
  // 書き漏らしの向き（下の層が追い付いていない）の違反: requirement-missing・requirement-coverage・example-missing。
  // 全体検査に含めず、checkDocMissing だけが返す
  docMissing: Violation[];
}

interface RequirementFile {
  file: string;
  req: Requirement;
  // req.lines と同じ並びの、各行の RDRA 欄から読んだ参照
  refs: { refs: Reference[] }[];
}

// 状態の参照「<状態モデル>/<状態>」を分ける。区切りが無ければ null
function splitState(name: string): { model: string; state: string } | null {
  const i = name.indexOf(REQUIREMENT_STATE_SEP);
  if (i < 0) return null;
  return { model: name.slice(0, i).trim(), state: name.slice(i + REQUIREMENT_STATE_SEP.length).trim() };
}

// 参照の名前の指す先が表にあるか。問題があればその説明、無ければ null
function referenceProblem(ref: Reference, ctx: TraceContext): string | null {
  if (ref.kind === null || ref.name === null) {
    return ref.raw === ''
      ? '空の要素がある（「、」の重複・末尾）'
      : `『${ref.raw}』が <種類>「<名前>」の形で読めない`;
  }
  if (!(REQUIREMENT_KINDS as readonly string[]).includes(ref.kind)) {
    return `種類『${ref.kind}』が語彙（${REQUIREMENT_KINDS.join('／')}）に無い`;
  }
  if (ref.kind === '状態') {
    const s = splitState(ref.name);
    if (s === null) return `状態の名前は『状態「<状態モデル>${REQUIREMENT_STATE_SEP}<状態>」』の形で書く`;
    const states = ctx.statesOf.get(s.model);
    if (states === undefined) return `状態モデル『${s.model}』が状態の表に無い（状態『${ref.name}』）`;
    if (!states.has(s.state)) {
      return `状態『${s.state}』が状態モデル『${s.model}』の「状態」「遷移先状態」のどちらにも無い`;
    }
    return null;
  }
  if (ctx.names.get(ref.kind)?.has(ref.name)) return null;
  return `${ref.kind}『${ref.name}』が表に無い`;
}

// 名前が要求文に現れるべき部分。状態は状態名の部分だけ。読めない参照・語彙に無い種類・区切りの無い状態は検査しない（null。
// requirement-reference が拾う。種類が誤っている参照に名前の出現まで問うと、同じ誤りを二重に出す）
function nameInText(ref: Reference): string | null {
  if (ref.kind === null || ref.name === null) return null;
  if (!(REQUIREMENT_KINDS as readonly string[]).includes(ref.kind)) return null;
  if (ref.kind === '状態') return splitState(ref.name)?.state ?? null;
  return ref.name;
}

// 参照を（種類, 名前）の鍵にする。状態は区切りの前後の空白を除いた形へそろえる
function refKey(kind: string, name: string): string {
  if (kind === '状態') {
    const s = splitState(name);
    if (s !== null) return `${kind}\u0000${s.model}${REQUIREMENT_STATE_SEP}${s.state}`;
  }
  return `${kind}\u0000${name}`;
}

function addTo<K, V>(map: Map<K, V[]>, key: K, value: V): void {
  const list = map.get(key);
  if (list === undefined) map.set(key, [value]);
  else list.push(value);
}

export function checkTrace(sources: Sources, ctx: TraceContext): TraceResult {
  const out: Violation[] = [];
  const missing: Violation[] = [];
  const ucNames = ctx.names.get('UC') ?? new Set<string>();

  // --- 要求票 ---
  const reqFiles: RequirementFile[] = sources.requirements.map(({ file, text }) => {
    const req = parseRequirement(text);
    return { file, req, refs: req.lines.map((l) => ({ refs: parseReferences(l.rdra) })) };
  });
  const filesOfUc = new Map<string, string[]>();
  for (const { file, req } of reqFiles) if (req.ucName !== null) addTo(filesOfUc, req.ucName, file);

  for (const { file, req, refs } of reqFiles) {
    if (req.ucName === null) {
      out.push({
        rule: 'requirement-uc',
        file,
        target: '表題',
        detail: '表題が「# 要求票: <UC 名>」の形で読めず、UC 名を取れない',
      });
    } else {
      const target = `UC:${req.ucName}`;
      if (!ucNames.has(req.ucName)) {
        out.push({
          rule: 'requirement-uc',
          file,
          target,
          detail: `UC『${req.ucName}』が表（${tableById('use-case').file}）に無い`,
        });
      }
      const same = filesOfUc.get(req.ucName)!;
      if (same.length > 1) {
        out.push({
          rule: 'requirement-uc',
          file,
          target,
          detail: `UC『${req.ucName}』の要求票が複数ある（${same.join('、')}）`,
        });
      }
    }
    for (const issue of req.issues) out.push({ rule: 'requirement-structure', file, ...issue });
    // 参照の検査は UC 名が読めない票でも行う（行は表題と独立に読める）
    for (const [i, line] of req.lines.entries()) {
      const lineTarget = `仕様:${line.ordinal}`;
      for (const ref of refs[i].refs) {
        const problem = referenceProblem(ref, ctx);
        if (problem !== null) {
          out.push({ rule: 'requirement-reference', file, target: lineTarget, detail: `RDRA 欄の${problem}` });
        }
        const part = nameInText(ref);
        if (part !== null && !line.text.includes(part)) {
          out.push({
            rule: 'requirement-name-absent',
            file,
            target: lineTarget,
            detail: `RDRA 欄の${ref.kind}『${ref.name}』の名前（『${part}』）が要求文に現れない`,
          });
        }
      }
    }
  }

  // 要求票が1つも無いリポジトリでは、票の有無・網羅は検査しない
  const ucDef = tableById('use-case');
  const useCaseOf = new Map(ctx.useCases.map((u) => [u.name, u] as const));
  if (reqFiles.length > 0) {
    for (const uc of ctx.useCases) {
      if (!uc.hypothesis && !filesOfUc.has(uc.name)) {
        missing.push({
          rule: 'requirement-missing',
          file: ucDef.file,
          target: `UC:${uc.name}`,
          detail: `『仮説』キーの無い UC の要求票が ${LAYOUT.requirements}/ に無い`,
        });
      }
    }
  }

  // 網羅: 仮説キーの無い UC の票は、UC の条件と、UC が遷移先にする状態を RDRA 欄に挙げる。票ごとに見る
  for (const { file, req, refs } of reqFiles) {
    if (req.ucName === null) continue;
    const uc = useCaseOf.get(req.ucName);
    if (uc === undefined || uc.hypothesis) continue;
    const listed = new Set<string>();
    for (const l of refs) {
      for (const r of l.refs) if (r.kind !== null && r.name !== null) listed.add(refKey(r.kind, r.name));
    }
    for (const c of uc.conditions) {
      if (!listed.has(refKey('条件', c))) {
        missing.push({
          rule: 'requirement-coverage',
          file,
          target: `条件:${c}`,
          detail: `UC『${uc.name}』の条件『${c}』が、どの仕様の行の RDRA 欄にも 条件「${c}」として現れない`,
        });
      }
    }
    for (const t of ctx.transitions) {
      if (t.uc !== uc.name) continue;
      const name = `${t.model}${REQUIREMENT_STATE_SEP}${t.next}`;
      if (!listed.has(refKey('状態', name))) {
        missing.push({
          rule: 'requirement-coverage',
          file,
          target: t.target,
          detail: `UC『${uc.name}』の遷移先状態『${name}』が、どの仕様の行の RDRA 欄にも 状態「${name}」として現れない`,
        });
      }
    }
  }

  // --- 例 ---
  const features: { file: string; feature: ExampleFeature }[] = [];
  let unreadable = false;
  for (const { file, text } of sources.examples) {
    const parsed = parseExample(text);
    if (!parsed.ok) {
      unreadable = true;
      out.push({
        rule: 'example-syntax',
        file,
        target: '構文',
        detail: `Gherkin として読めない: ${parsed.message}`,
      });
    } else if (parsed.feature === null) {
      out.push({ rule: 'example-feature', file, target: '機能', detail: '機能（Feature）が無い' });
    } else {
      features.push({ file, feature: parsed.feature });
    }
  }
  const featureFilesOfUc = new Map<string, string[]>();
  for (const { file, feature } of features) {
    if (feature.name !== '') addTo(featureFilesOfUc, feature.name, file);
  }
  for (const { file, feature } of features) {
    if (feature.name === '') {
      out.push({ rule: 'example-feature', file, target: '機能:（名前なし）', detail: '機能の名前が空' });
      continue;
    }
    const target = `機能:${feature.name}`;
    if (!ucNames.has(feature.name)) {
      out.push({
        rule: 'example-feature',
        file,
        target,
        detail: `機能名『${feature.name}』が UC の表（${ucDef.file}）に無い`,
      });
    }
    const same = featureFilesOfUc.get(feature.name)!;
    if (same.length > 1) {
      out.push({
        rule: 'example-feature',
        file,
        target,
        detail: `UC『${feature.name}』の機能が複数のファイルにある（${same.join('、')}）`,
      });
    }
  }

  // ルールと要求文の突き合わせ（両方向）。UC 名ごとに票の要求文とルールの名前を集める。
  // ルール側から見た食い違いは example-rule-mismatch、票の側から見た書き漏らしは example-missing（docMissing）
  const sentencesOfUc = new Map<string, Set<string>>();
  for (const { req } of reqFiles) {
    if (req.ucName === null) continue;
    if (!sentencesOfUc.has(req.ucName)) sentencesOfUc.set(req.ucName, new Set());
    for (const l of req.lines) sentencesOfUc.get(req.ucName)!.add(l.text);
  }
  const rulesOfUc = new Map<string, Set<string>>();
  for (const { feature } of features) {
    if (feature.name === '') continue;
    if (!rulesOfUc.has(feature.name)) rulesOfUc.set(feature.name, new Set());
    for (const r of feature.rules) rulesOfUc.get(feature.name)!.add(r.name);
  }
  for (const { file, feature } of features) {
    // 名前の無い機能は example-feature が拾う。どの UC の機能か分からず、ルールを突き合わせる先が無い
    if (feature.name === '') continue;
    const sentences = sentencesOfUc.get(feature.name);
    for (const r of feature.rules) {
      if (sentences === undefined) {
        out.push({
          rule: 'example-rule-mismatch',
          file,
          target: `ルール:${r.name}`,
          detail: `UC『${feature.name}』の要求票が無く、ルールの名前に対応する要求文が無い`,
        });
      } else if (!sentences.has(r.name)) {
        out.push({
          rule: 'example-rule-mismatch',
          file,
          target: `ルール:${r.name}`,
          detail: `ルールの名前が、UC『${feature.name}』の要求票の仕様の行の要求文のどれとも一致しない`,
        });
      }
    }
    for (const s of feature.looseScenarios) {
      out.push({
        rule: 'example-rule-mismatch',
        file,
        target: `シナリオ:${s.name}`,
        detail: 'シナリオがルールの外（機能の直下）に置かれている',
      });
    }
  }
  // 読めない feature ファイルがあると、どの UC の機能か分からず票の行に対応するルールの有無を判定できない。example-missing は行わない
  // （構文の誤りは example-syntax が拾う）
  if (!unreadable) {
    for (const { file, req } of reqFiles) {
      if (req.ucName === null) continue;
      const rules = rulesOfUc.get(req.ucName);
      for (const l of req.lines) {
        if (rules?.has(l.text)) continue;
        missing.push({
          rule: 'example-missing',
          file,
          target: `仕様:${l.ordinal}`,
          detail:
            rules === undefined
              ? `UC『${req.ucName}』の機能が ${LAYOUT.examples}/ に無く、要求文に対応するルールが無い`
              : `同じ UC の機能に、要求文と同じ名前のルールが無い`,
        });
      }
    }
  }

  // 例の件数と重複
  for (const { file, feature } of features) {
    for (const r of feature.rules) {
      const count = r.scenarios.reduce((n, s) => n + s.expansions.length, 0);
      if (count > EXAMPLE_LIMIT) {
        out.push({
          rule: 'example-limit',
          file,
          target: `ルール:${r.name}`,
          detail: `例が ${count} 件で上限 ${EXAMPLE_LIMIT} 件を超える（規則が束になっている。要求文を分ける）`,
        });
      }
    }
    // 同じ機能の中を、文書の並びで見る。同じ並びが2つ目以降に現れたものを報告する
    const all: ExampleScenario[] = [...feature.looseScenarios, ...feature.rules.flatMap((r) => r.scenarios)].sort(
      (a, b) => a.line - b.line,
    );
    const seen = new Map<string, string>();
    for (const s of all) {
      for (const e of s.expansions) {
        // 手順が0件の例は、重複と呼べる手順が無いため比べない
        if (e.steps.length === 0) continue;
        const key = JSON.stringify(e.steps);
        const first = seen.get(key);
        if (first === undefined) {
          seen.set(key, `『${s.name}${e.label}』（${s.line}行目）`);
        } else {
          out.push({
            rule: 'example-duplicate',
            file,
            target: `シナリオ:${s.name}${e.label}`,
            detail: `手順の文の並びが${first}と同じ`,
          });
        }
      }
    }
  }

  return { checked: out, docMissing: missing };
}
