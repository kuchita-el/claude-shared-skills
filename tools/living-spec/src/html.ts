// 設計の可視化の HTML の文字列を作る。材料は view.ts の buildView が組む。
// 図は Mermaid の flowchart で描く（stateDiagram は破線と辺ごとの強調を持てない）。Mermaid は jsdelivr から版を固定して読む。
import type {
  NamedView,
  ReferenceView,
  RequirementLineView,
  ScenarioView,
  StateModelView,
  TransitionView,
  UseCaseView,
  View,
} from './view.ts';

const MERMAID_URL = 'https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs';
const UNKNOWN_MARK = '⚠';
const HIGHLIGHT = 'stroke:#d9480f,stroke-width:3px,color:#d9480f';
const DIMMED = 'stroke:#adb5bd,color:#868e96';

export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Mermaid の "…" で囲んだ名札の中身。# を先に逃がす（Mermaid の実体参照 #…; の始まりのため）
function mermaidText(s: string): string {
  return s
    .replace(/#/g, '#35;')
    .replace(/&/g, '#amp;')
    .replace(/"/g, '#quot;')
    .replace(/</g, '#lt;')
    .replace(/>/g, '#gt;')
    .replace(/`/g, '#96;')
    .replace(/\s+/g, ' ');
}

function marked(name: string, known: boolean): string {
  return known ? name : `${UNKNOWN_MARK} ${name}`;
}

// 状態モデル1つの Mermaid の文字列。highlightUc を渡すと、その UC が遷移 UC の辺だけを強調し、他の辺を薄くする
export function stateChart(model: StateModelView, highlightUc: string | null): string {
  const id = new Map(model.states.map((s, i) => [s, `s${i}`] as const));
  const out = ['flowchart LR'];
  const drawn = model.transitions.filter((t) => t.from !== null || t.to !== null);
  if (drawn.some((t) => t.from === null)) out.push('  start0(("開始")):::terminal');
  for (const s of model.states) {
    const known = !model.transitions.some((t) => t.to === s && !t.toKnown);
    out.push(`  ${id.get(s)}["${mermaidText(marked(s, known))}"]`);
  }
  if (drawn.some((t) => t.to === null)) out.push('  end0(("終端")):::terminal');
  const styles: string[] = [];
  drawn.forEach((t: TransitionView, i) => {
    const from = t.from === null ? 'start0' : id.get(t.from)!;
    const to = t.to === null ? 'end0' : id.get(t.to)!;
    const arrow = t.hypothesis ? '-.->' : '-->';
    const label = t.uc === null ? '' : `|"${mermaidText(marked(t.uc, t.ucKnown))}"|`;
    out.push(`  ${from} ${arrow}${label} ${to}`);
    if (highlightUc !== null) {
      const dash = t.hypothesis ? ',stroke-dasharray:5 5' : '';
      styles.push(`  linkStyle ${i} ${t.uc === highlightUc ? HIGHLIGHT : DIMMED}${dash}`);
    }
  });
  out.push(...styles);
  out.push('  classDef terminal fill:#495057,stroke:#495057,color:#fff');
  return out.join('\n');
}

function chartBlock(model: StateModelView, highlightUc: string | null): string {
  return `<pre class="mermaid">${escapeHtml(stateChart(model, highlightUc))}</pre>`;
}

function nameHtml(n: NamedView): string {
  return n.known
    ? escapeHtml(n.name)
    : `<span class="unknown" title="表に無い名前">${escapeHtml(marked(n.name, false))}</span>`;
}

function ucLink(name: string | null, known: boolean, view: View): string {
  if (name === null) return '';
  const uc = view.useCases.find((u) => u.name === name);
  if (uc === undefined) return nameHtml({ name, known });
  return `<a href="#${uc.anchor}">${escapeHtml(name)}</a>`;
}

function hypothesisBadge(h: string[] | null): string {
  if (h === null) return '';
  const ids = h.length > 0 ? `: ${escapeHtml(h.join('、'))}` : '';
  return `<span class="badge">仮説${ids}</span>`;
}

function scenarioList(scenarios: ScenarioView[]): string {
  const items = scenarios.map(
    (s) => `<li>${escapeHtml(s.name)}${s.count === 1 ? '' : `<span class="note">（${s.count} 件）</span>`}</li>`,
  );
  return `<ul class="scenarios">${items.join('')}</ul>`;
}

function stateModelSection(model: StateModelView, view: View): string {
  const rows = model.transitions.map((t) => {
    const from = t.from === null ? '<span class="note">（開始）</span>' : escapeHtml(t.from);
    const to =
      t.to === null ? '<span class="note">（終端）</span>' : nameHtml({ name: t.to, known: t.toKnown });
    return `<tr><td>${from}</td><td>${to}</td><td>${ucLink(t.uc, t.ucKnown, view)}</td><td>${escapeHtml(t.description)}</td><td>${t.hypothesis ? '仮説' : ''}</td></tr>`;
  });
  return `<h3>${escapeHtml(model.name)}</h3>
${chartBlock(model, null)}
<table><thead><tr><th>元の状態</th><th>遷移先</th><th>遷移 UC</th><th>説明</th><th>仮説</th></tr></thead>
<tbody>${rows.join('\n')}</tbody></table>`;
}

function presence(n: number, unit: string): string {
  return n === 0 ? '<span class="missing">無い</span>' : `あり（${n} ${unit}）`;
}

function useCaseIndex(view: View): string {
  const rows = view.useCases.map((uc) => {
    const lines = uc.requirements.reduce((n, r) => n + r.lines.length, 0);
    const scenarios =
      uc.requirements.reduce((n, r) => n + r.lines.reduce((m, l) => m + l.scenarios.length, 0), 0) +
      uc.unlinkedRules.reduce((n, r) => n + r.scenarios.length, 0) +
      uc.looseScenarios.length;
    return `<tr><td><a href="#${uc.anchor}">${escapeHtml(uc.name)}</a></td><td>${uc.actors.map(nameHtml).join('、')}</td><td>${hypothesisBadge(uc.hypothesis)}</td><td>${uc.requirements.length === 0 ? presence(0, '') : presence(lines, '行')}</td><td>${uc.exampleFiles.length === 0 ? presence(0, '') : presence(scenarios, 'シナリオ')}</td></tr>`;
  });
  return `<table><thead><tr><th>UC</th><th>アクター</th><th>仮説</th><th>要求票</th><th>例</th></tr></thead>
<tbody>${rows.join('\n')}</tbody></table>`;
}

// 中身を持つ参照（条件・バリエーション・情報）。名前ごとに1つ
function definedReferences(line: RequirementLineView): (ReferenceView & { name: string })[] {
  const seen = new Set<string>();
  return line.references.filter((r): r is ReferenceView & { name: string } => {
    if (r.definition === null || r.name === null || seen.has(r.name)) return false;
    seen.add(r.name);
    return true;
  });
}

function definitionTitle(r: ReferenceView): string {
  const d = r.definition!;
  const extra = [
    d.values.length > 0 ? `値: ${d.values.join('、')}` : '',
    d.attributes.length > 0 ? `属性: ${d.attributes.join('、')}` : '',
  ].filter((x) => x !== '');
  return extra.length > 0 ? `${d.description}（${extra.join('。')}）` : d.description;
}

// 要求文の中の条件・バリエーション・情報の名前に印を付け、重ねると中身が出るようにする（CSS のツールチップ。
// ブラウザ標準の title は出るまで待たされ、気付かれないため使わない）。クリックすると行の直下の中身を開閉する。
// 名前が他の名前を含む（経費／経費申請、インボイスの扱い／インボイスの扱いの決め方）ため、表にある名前すべてを
// 長い名前から先に1回で照合し、照合した名前が行の参照のときだけ印を付ける
function sentenceHtml(line: RequirementLineView, tableNames: string[]): string {
  const refs = definedReferences(line);
  if (refs.length === 0) return escapeHtml(line.text);
  const byName = new Map(refs.map((r) => [r.name, r] as const));
  const names = [...new Set([...tableNames, ...byName.keys()])].sort((a, b) => b.length - a.length);
  const pattern = new RegExp(names.map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'g');
  let out = '';
  let last = 0;
  for (const m of line.text.matchAll(pattern)) {
    const ref = byName.get(m[0]);
    if (ref === undefined) continue;
    out += escapeHtml(line.text.slice(last, m.index));
    out += `<span class="term" tabindex="0" data-tip="${escapeHtml(definitionTitle(ref))}">${escapeHtml(m[0])}</span>`;
    last = m.index + m[0].length;
  }
  return out + escapeHtml(line.text.slice(last));
}

// 行の直下に出す、条件・バリエーション・情報の中身。既定で隠し、隠している間は何も見せない
function definitionsHtml(line: RequirementLineView): string {
  const refs = definedReferences(line);
  const items = refs.map((r) => {
    const d = r.definition!;
    const values = d.values.length > 0 ? `<div class="sub">値: ${escapeHtml(d.values.join('、'))}</div>` : '';
    const attributes =
      d.attributes.length > 0 ? `<div class="sub">属性: ${escapeHtml(d.attributes.join('、'))}</div>` : '';
    const variations = d.variations
      .map(
        (v) =>
          `<div class="sub">${nameHtml(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join('、'))}` : ''}</div>`,
      )
      .join('');
    return `<li><span class="kind">${escapeHtml(r.kind ?? '')}</span><strong>${escapeHtml(r.name)}</strong>: ${escapeHtml(d.description)}${values}${attributes}${variations}</li>`;
  });
  if (items.length === 0) return '';
  return `<div class="defs" hidden><ul>${items.join('')}</ul></div>`;
}

function requirementBlock(uc: UseCaseView, view: View): string {
  if (uc.requirements.length === 0) {
    const why = uc.hypothesis !== null ? '（仮説の UC。検査は要求票を求めない）' : '';
    return `<p class="missing">要求票が無い${why}</p>`;
  }
  return uc.requirements
    .map((r) => {
      const lines = r.lines.map((l) => {
        const refs = l.references
          .map((ref) =>
            ref.known
              ? escapeHtml(ref.raw)
              : `<span class="unknown" title="表に無い、または読めない参照">${escapeHtml(marked(ref.raw, false))}</span>`,
          )
          .join('、');
        const examples =
          l.scenarios.length > 0
            ? scenarioList(l.scenarios)
            : uc.exampleFiles.length > 0
              ? '<p class="missing">この行に結び付く例が無い</p>'
              : '';
        return `<li><p class="sentence">${sentenceHtml(l, view.tableNames)}</p>
${definitionsHtml(l)}
<dl class="fields"><dt>理由</dt><dd>${escapeHtml(l.reason ?? '（欄が無い）')}</dd><dt>RDRA</dt><dd>${refs === '' ? 'なし' : refs}</dd></dl>
${examples}</li>`;
      });
      const reason = r.reason === null ? '（節が無い）' : escapeHtml(r.reason).replace(/\n/g, '<br>');
      return `<p class="file">${escapeHtml(r.file)}</p>
<p><strong>理由:</strong> ${reason}</p>
<ol class="lines">${lines.join('\n')}</ol>`;
    })
    .join('\n');
}

function exampleBlock(uc: UseCaseView): string {
  const parts: string[] = [];
  if (uc.exampleFiles.length === 0) {
    parts.push('<p class="missing">例が無い</p>');
  } else {
    parts.push(`<p class="file">${uc.exampleFiles.map(escapeHtml).join('、')}</p>`);
  }
  if (uc.unlinkedRules.length > 0 || uc.looseScenarios.length > 0) {
    const rules = uc.unlinkedRules.map(
      (r) => `<li><p class="sentence">ルール: ${escapeHtml(r.name)}</p>${scenarioList(r.scenarios)}</li>`,
    );
    if (uc.looseScenarios.length > 0) {
      rules.push(`<li><p class="sentence">ルールの外のシナリオ</p>${scenarioList(uc.looseScenarios)}</li>`);
    }
    parts.push(`<div class="unlinked"><h4>要求票の行に結び付かない例</h4><ul>${rules.join('\n')}</ul></div>`);
  }
  return parts.join('\n');
}

function sliceSection(uc: UseCaseView, view: View): string {
  const roles = (xs: (NamedView & { role: string })[]) =>
    xs.map((x) => `<li>${nameHtml(x)}${x.role === '' ? '' : `（${escapeHtml(x.role)}）`}</li>`).join('');
  const charts =
    uc.stateModels.length === 0
      ? '<p class="note">この UC が動かす遷移は無い</p>'
      : uc.stateModels
          .map((name) => view.stateModels.find((m) => m.name === name)!)
          .map((m) => `<p class="caption">${escapeHtml(m.name)}</p>${chartBlock(m, uc.name)}`)
          .join('\n');
  const information =
    uc.information.length === 0
      ? '<p class="note">なし</p>'
      : `<table><thead><tr><th>情報</th><th>説明</th><th>属性</th></tr></thead><tbody>${uc.information
          .map(
            (i) =>
              `<tr><td>${nameHtml(i)}</td><td>${escapeHtml(i.description)}</td><td>${escapeHtml(i.attributes.join('、'))}</td></tr>`,
          )
          .join('')}</tbody></table>`;
  const conditions =
    uc.conditions.length === 0
      ? '<p class="note">なし</p>'
      : `<table><thead><tr><th>条件</th><th>条件の説明</th><th>バリエーション</th></tr></thead><tbody>${uc.conditions
          .map((c) => {
            const vs = c.variations
              .map(
                (v) =>
                  `<div>${nameHtml(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join('、'))}` : ''}</div>`,
              )
              .join('');
            return `<tr><td>${nameHtml(c)}</td><td>${escapeHtml(c.description)}</td><td>${vs}</td></tr>`;
          })
          .join('')}</tbody></table>`;
  return `<section class="slice" id="${uc.anchor}">
<h2>${escapeHtml(uc.name)} ${hypothesisBadge(uc.hypothesis)}</h2>
<p>${escapeHtml(uc.description)}</p>
<div class="cols">
<div><h4>アクター</h4>${uc.actors.length === 0 ? '<p class="note">なし</p>' : `<ul>${roles(uc.actors)}</ul>`}</div>
<div><h4>外部システム</h4>${uc.externalSystems.length === 0 ? '<p class="note">なし</p>' : `<ul>${roles(uc.externalSystems)}</ul>`}</div>
</div>
<h3>状態の遷移</h3>
${charts}
<h3>情報</h3>
${information}
<h3>条件</h3>
${conditions}
<h3>要求票</h3>
${requirementBlock(uc, view)}
<h3>例</h3>
${exampleBlock(uc)}
<p class="top"><a href="#top">先頭へ</a></p>
</section>`;
}

function strayBlock(view: View): string {
  const items = [
    ...view.strayRequirements.map(
      (r) =>
        `<li>要求票 ${escapeHtml(r.file)}: ${r.ucName === null ? '表題から UC 名を読めない' : `UC『${nameHtml({ name: r.ucName, known: false })}』が UC の表に無い`}</li>`,
    ),
    ...view.strayExamples.map(
      (e) =>
        `<li>例 ${escapeHtml(e.file)}: ${e.name === '' ? '機能の名前が空' : `機能名『${nameHtml({ name: e.name, known: false })}』が UC の表に無い`}</li>`,
    ),
    ...view.unreadableExamples.map((e) => `<li>例 ${escapeHtml(e.file)}: 読めない（${escapeHtml(e.message)}）</li>`),
  ];
  if (items.length === 0) return '';
  return `<section id="stray"><h2>どの UC にも結び付かない要求票・例</h2><ul>${items.join('\n')}</ul></section>`;
}

function timestamp(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  const offset = -d.getTimezoneOffset();
  const sign = offset >= 0 ? '+' : '-';
  const tz = `${sign}${p(Math.floor(Math.abs(offset) / 60))}:${p(Math.abs(offset) % 60)}`;
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())} ${tz}`;
}

const STYLE = `
:root { --fg:#212529; --bg:#ffffff; --muted:#6c757d; --line:#dee2e6; --panel:#f8f9fa; --warn:#c92a2a; --accent:#1c7ed6; --tip-bg:#343a40; --tip-fg:#f8f9fa; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e9ecef; --bg:#1e1f22; --muted:#adb5bd; --line:#3a3d42; --panel:#26282c; --warn:#ff8787; --accent:#74c0fc; --tip-bg:#f1f3f5; --tip-fg:#212529; }
}
body { margin:0; padding:16px 24px 48px; color:var(--fg); background:var(--bg); font:15px/1.6 system-ui, sans-serif; }
a { color:var(--accent); }
header { border-bottom:1px solid var(--line); margin-bottom:16px; }
header p { margin:4px 0; color:var(--muted); font-size:13px; }
nav a { margin-right:12px; }
table { border-collapse:collapse; margin:8px 0 16px; width:100%; }
th, td { border:1px solid var(--line); padding:4px 8px; text-align:left; vertical-align:top; }
th { background:var(--panel); }
pre.mermaid { background:#fff; border:1px solid var(--line); border-radius:6px; padding:8px; overflow-x:auto; }
section.slice { border-top:2px solid var(--line); margin-top:32px; padding-top:8px; }
.cols { display:flex; gap:32px; flex-wrap:wrap; }
.badge { display:inline-block; font-size:12px; padding:1px 8px; border-radius:10px; background:#fff3bf; color:#5c3c00; vertical-align:middle; }
.unknown { color:var(--warn); font-weight:600; }
.missing { color:var(--warn); }
.note, .file, .caption { color:var(--muted); font-size:13px; }
ol.lines > li { margin-bottom:12px; }
.sentence { margin:0; font-weight:600; }
dl.fields { display:grid; grid-template-columns:max-content 1fr; gap:0 8px; margin:4px 0; font-size:13px; }
dl.fields dt { color:var(--muted); }
dl.fields dd { margin:0; }
ul.scenarios { margin:4px 0; padding-left:20px; font-size:13px; }
ul.scenarios li::marker { content:'▸ '; }
.term { border-bottom:2px dotted var(--accent); cursor:help; }
.term { position:relative; }
.term:hover::after, .term:focus::after {
  content:attr(data-tip); position:absolute; left:0; top:100%; z-index:10; margin-top:4px;
  width:max-content; max-width:min(32em, 80vw); white-space:normal; font-weight:normal; font-size:13px; line-height:1.5;
  padding:6px 10px; border-radius:6px; background:var(--tip-bg); color:var(--tip-fg); box-shadow:0 2px 8px rgba(0,0,0,.25);
}
div.defs { margin:2px 0 4px; font-size:13px; }
div.defs ul { list-style:none; margin:4px 0; padding:6px 10px; background:var(--panel); border-left:3px solid var(--accent); }
div.defs li + li { margin-top:4px; }
div.defs .kind { color:var(--muted); margin-right:6px; }
div.defs .sub { color:var(--muted); padding-left:1em; }
nav button { font-size:12px; margin-left:4px; }
.unlinked { border:1px dashed var(--warn); border-radius:6px; padding:4px 12px; margin:8px 0; }
.top { text-align:right; font-size:13px; }
`;

export function renderHtml(view: View, generatedAt: Date): string {
  const models =
    view.stateModels.length === 0
      ? '<p class="note">状態の表に状態モデルが無い</p>'
      : view.stateModels.map((m) => stateModelSection(m, view)).join('\n');
  const stray = strayBlock(view);
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RDRA の設計の可視化</title>
<style>${STYLE}</style>
</head>
<body id="top">
<header>
<h1>RDRA の設計の可視化</h1>
<p>生成時刻: ${escapeHtml(timestamp(generatedAt))}</p>
<p>根: ${escapeHtml(view.root)}</p>
<nav><a href="#states">状態遷移図</a><a href="#use-cases">UC の一覧</a>${stray === '' ? '' : '<a href="#stray">結び付かない要求票・例</a>'}
要求の行の中身（名前のクリックでも開閉）: <button type="button" data-defs="open">すべて開く</button><button type="button" data-defs="close">すべて閉じる</button></nav>
</header>
<section id="states"><h2>状態遷移図</h2>
<p class="note">実線は事実、破線は仮説の遷移。${UNKNOWN_MARK} は表に無い名前。</p>
${models}
</section>
<section id="use-cases"><h2>UC の一覧</h2>
${useCaseIndex(view)}
</section>
${stray}
${view.useCases.map((uc) => sliceSection(uc, view)).join('\n')}
<script>
for (const b of document.querySelectorAll('button[data-defs]')) {
  b.addEventListener('click', () => {
    for (const d of document.querySelectorAll('div.defs')) d.hidden = b.dataset.defs !== 'open';
  });
}
for (const t of document.querySelectorAll('.term')) {
  t.addEventListener('click', () => {
    const d = t.closest('li')?.querySelector('div.defs');
    if (d) d.hidden = !d.hidden;
  });
}
</script>
<script type="module">
import mermaid from '${MERMAID_URL}';
const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
mermaid.initialize({ startOnLoad: true, securityLevel: 'strict', theme: dark ? 'neutral' : 'default' });
</script>
</body>
</html>
`;
}
