// 設計の可視化の HTML の文字列を作る。材料は view.ts の buildView が組む。
// 図は Mermaid の flowchart で描く（stateDiagram は破線と辺ごとの強調を持てない）。Mermaid は jsdelivr から版を固定して読む。
// 基準の版との描き分けの材料（diffview.ts の buildDiffView）では、区分のある要素の出現位置に印を1つ付ける。
// 印・図の class と linkStyle・見出しの行・凡例・描き分けの CSS は、区分か基準の版があるときだけ出し、
// 区分の無い材料（基準の版なし）からは描き分けを足す前と同じ文字列を作る。
import type {
  DiffStatus,
  Marked,
  NamedView,
  OpenView,
  Origin,
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

// 描き分けの区分。図では名札の先頭の印と、色と太さで示す。破線（stroke-dasharray）は使わない
// （破線は凡例のとおり仮説の遷移だけを示すため。仮説の辺の linkStyle には破線の指定を後ろに足して保つ）
const DIFF_STATUSES: readonly DiffStatus[] = ['added', 'changed', 'removed'];
const CHART_MARK: Record<DiffStatus, string> = { added: '［足された］', changed: '［変わった］', removed: '［外された］' };
// 全体図の区分のある辺の linkStyle。縦串の図の強調（stroke-width:3px）と見分けられる太さにする
const DIFF_LINK: Record<DiffStatus, string> = {
  added: 'stroke:#2f9e44,stroke-width:2px,color:#2f9e44',
  changed: 'stroke:#7048e8,stroke-width:2px,color:#7048e8',
  removed: 'stroke:#e03131,stroke-width:2px,color:#e03131',
};
// 区分のある状態の節点の classDef
const DIFF_NODE: Record<DiffStatus, string> = {
  added: 'fill:#ebfbee,stroke:#2f9e44,stroke-width:2px,color:#2b8a3e',
  changed: 'fill:#f3f0ff,stroke:#7048e8,stroke-width:2px,color:#5f3dc4',
  removed: 'fill:#fff5f5,stroke:#e03131,stroke-width:2px,color:#c92a2a',
};

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

// 描き分けの印。区分の無い要素には何も出さない。変わった要素は変わった欄の名前を添える
// （欄名は表の定義に無いキーの名前でもありうるので逃がす）
function diffMark(x: Marked): string {
  if (x.diff === undefined) return '';
  const text =
    x.diff === 'changed' ? `変わった（${(x.changed ?? []).join('・')}）` : x.diff === 'added' ? '足された' : '外された';
  return `<span class="diff" data-diff="${x.diff}">${escapeHtml(text)}</span>`;
}

// 描き分けで、容れ物の欠けの注記・警告の様式と件数を決めるときに数える子か。残る容れ物（自身もその上の容れ物も
// 作業ツリーの材料から来た物）は作業ツリーにある子だけを数え（作業ツリーの姿）、基準の版から加えた容れ物は全ての子を数える
// （基準の版の姿）。作業ツリーにある子かは、区分ではなく、基準の版から加えた子でないか（fromBase を持たないか）で決める。
// 表から外した名前を作業ツリーの UC がまだ挙げていれば、その子は区分が「外された」でも作業ツリーにある子である。
// 基準の版から加えた子は、数えるかどうかによらず印付きで並べる。ただし印を付けない位置の UC の一覧のアクター欄には、
// 数える子だけを並べる。区分の無い材料では全ての子を数える（今と同じ）
function liveIn(...containers: Origin[]): (x: Origin) => boolean {
  const gone = containers.some((c) => c.fromBase === true);
  return (x) => gone || x.fromBase !== true;
}

// 状態の区分。区分は状態の名前をキーにした物なので、自分の欄だけを見る（Object の継承した欄の名前の状態で誤らないため）
function stateStatus(model: StateModelView, state: string): DiffStatus | undefined {
  return model.stateDiff !== undefined && Object.hasOwn(model.stateDiff, state) ? model.stateDiff[state] : undefined;
}

// 状態モデル1つの Mermaid の文字列。highlightUc を渡すと、その UC が遷移 UC の辺だけを強調し、他の辺を薄くする。
// 描き分けの材料では、区分のある状態の節点と遷移の辺の名札の先頭に印を付け、節点には区分の class を付ける。
// 区分の linkStyle は全体図（highlightUc が null）だけに付け、縦串の図では強調・薄めの linkStyle だけを辺ごとに1本出す
// （区分の linkStyle を重ねると、同じ辺へ2本目の style が付き、UC の強調が読めなくなるため）
export function stateChart(model: StateModelView, highlightUc: string | null): string {
  const id = new Map(model.states.map((s, i) => [s, `s${i}`] as const));
  const out = ['flowchart LR'];
  const drawn = model.transitions.filter((t) => t.from !== null || t.to !== null);
  const classes = new Set<DiffStatus>();
  if (drawn.some((t) => t.from === null)) out.push('  start0(("開始")):::terminal');
  for (const s of model.states) {
    const known = !model.transitions.some((t) => t.to === s && !t.toKnown);
    const status = stateStatus(model, s);
    if (status === undefined) {
      out.push(`  ${id.get(s)}["${mermaidText(marked(s, known))}"]`);
    } else {
      classes.add(status);
      out.push(`  ${id.get(s)}["${mermaidText(`${CHART_MARK[status]} ${marked(s, known)}`)}"]:::${status}`);
    }
  }
  if (drawn.some((t) => t.to === null)) out.push('  end0(("終端")):::terminal');
  const styles: string[] = [];
  drawn.forEach((t: TransitionView, i) => {
    const from = t.from === null ? 'start0' : id.get(t.from)!;
    const to = t.to === null ? 'end0' : id.get(t.to)!;
    const arrow = t.hypothesis ? '-.->' : '-->';
    // 遷移 UC の無い辺も、区分があれば印だけの名札を持つ
    const text = (t.diff === undefined ? '' : CHART_MARK[t.diff]) + (t.uc === null ? '' : marked(t.uc, t.ucKnown));
    const label = text === '' ? '' : `|"${mermaidText(text)}"|`;
    out.push(`  ${from} ${arrow}${label} ${to}`);
    const dash = t.hypothesis ? ',stroke-dasharray:5 5' : '';
    if (highlightUc !== null) {
      styles.push(`  linkStyle ${i} ${t.uc === highlightUc ? HIGHLIGHT : DIMMED}${dash}`);
    } else if (t.diff !== undefined) {
      styles.push(`  linkStyle ${i} ${DIFF_LINK[t.diff]}${dash}`);
    }
  });
  out.push(...styles);
  out.push('  classDef terminal fill:#495057,stroke:#495057,color:#fff');
  for (const status of DIFF_STATUSES) if (classes.has(status)) out.push(`  classDef ${status} ${DIFF_NODE[status]}`);
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

// 未決の印。仮説の印（破線・黄色の「仮説」バッジ）と見分けるため、実線の枠の「未決（<欄>）: <内容>」で出す。
// 印を持たない要素には何も出さない
function openHtml(open: OpenView[]): string {
  return open
    .map((m) => `<span class="open">未決（${escapeHtml(m.key)}）: ${escapeHtml(m.content)}</span>`)
    .join('');
}

function hypothesisBadge(h: string[] | null): string {
  if (h === null) return '';
  const ids = h.length > 0 ? `: ${escapeHtml(h.join('、'))}` : '';
  return `<span class="badge">仮説${ids}</span>`;
}

function scenarioList(scenarios: ScenarioView[]): string {
  const items = scenarios.map(
    (s) =>
      `<li>${escapeHtml(s.name)}${diffMark(s)}${s.count === 1 ? '' : `<span class="note">（${s.count} 件）</span>`}</li>`,
  );
  return `<ul class="scenarios">${items.join('')}</ul>`;
}

function stateModelSection(model: StateModelView, view: View): string {
  const rows = model.transitions.map((t) => {
    const from = t.from === null ? '<span class="note">（開始）</span>' : escapeHtml(t.from);
    const to =
      t.to === null ? '<span class="note">（終端）</span>' : nameHtml({ name: t.to, known: t.toKnown });
    // 遷移の区分の印は、行の元の状態の欄の先頭に付ける
    return `<tr><td>${diffMark(t)}${from}</td><td>${to}</td><td>${ucLink(t.uc, t.ucKnown, view)}</td><td>${escapeHtml(t.description)}${openHtml(t.open)}</td><td>${t.hypothesis ? '仮説' : ''}</td></tr>`;
  });
  return `<h3>${escapeHtml(model.name)}</h3>
${chartBlock(model, null)}
<table><thead><tr><th>元の状態</th><th>遷移先</th><th>遷移 UC</th><th>説明</th><th>仮説</th></tr></thead>
<tbody>${rows.join('\n')}</tbody></table>`;
}

function presence(n: number, unit: string): string {
  return n === 0 ? '<span class="missing">無い</span>' : `あり（${n} ${unit}）`;
}

// 残る要求票の残る行が1つ以上あり、どれも例を求めない行か。そうした UC は例のファイルが無くても検査の example-missing に
// 当たらないので、例の欠けとして示さない
function onlyExampleFreeLines(uc: UseCaseView): boolean {
  const counted = liveIn(uc);
  const lines = uc.requirements.filter(counted).flatMap((r) => r.lines.filter(counted));
  return lines.length > 0 && lines.every((l) => l.exampleNotRequired);
}

function useCaseIndex(view: View): string {
  const rows = view.useCases.map((uc) => {
    // 描き分けの材料では、残る UC の行は基準の版から加えた票・行・例を数えず（作業ツリーの数）、外された UC の行は基準の版で
    // 持っていた数（縦串に残る外された行・例の数）を出す。外された UC の行を作業ツリーの数にすると0になり、
    // 要求票を欠いた欠陥のように「無い」が出るため。区分の無い材料では全てを数える（今と同じ）。
    // アクターの欄も同じ規則で絞る（残る UC の行は作業ツリーの UC が挙げるアクターだけ、外された UC の行は全て）。
    // この欄は印を付けない位置なので、基準の版から加えたアクターを並べると今のアクターに見えるため。
    // 表から外して UC にだけ残るアクターは作業ツリーの UC が挙げるので並べ、基準の版なしと同じく表に無い名前として示す
    const counted = liveIn(uc);
    const requirements = uc.requirements.filter(counted);
    const lines = requirements.flatMap((r) => r.lines.filter(counted));
    const scenarios =
      lines.reduce((n, l) => n + l.scenarios.filter(counted).length, 0) +
      uc.unlinkedRules.reduce((n, r) => n + r.scenarios.filter(counted).length, 0) +
      uc.looseScenarios.filter(counted).length;
    return `<tr><td><a href="#${uc.anchor}">${escapeHtml(uc.name)}</a>${diffMark(uc)}</td><td>${uc.actors.filter(counted).map(nameHtml).join('、')}</td><td>${hypothesisBadge(uc.hypothesis)}</td><td>${requirements.length === 0 ? presence(0, '') : presence(lines.length, '行')}</td><td>${uc.exampleFiles.length === 0 ? (onlyExampleFreeLines(uc) ? '無い（求めない）' : presence(0, '')) : presence(scenarios, 'シナリオ')}</td></tr>`;
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
          `<div class="sub">${nameHtml(v)}${diffMark(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join('、'))}` : ''}</div>`,
      )
      .join('');
    return `<li><span class="kind">${escapeHtml(r.kind ?? '')}</span><strong>${escapeHtml(r.name)}</strong>${diffMark(r)}: ${escapeHtml(d.description)}${openHtml(d.open)}${values}${attributes}${variations}</li>`;
  });
  if (items.length === 0) return '';
  return `<div class="defs" hidden><ul>${items.join('')}</ul></div>`;
}

function requirementBlock(uc: UseCaseView, view: View): string {
  const why = uc.hypothesis !== null ? '（仮説の UC。検査は要求票を求めない）' : '';
  const missing = `<p class="missing">要求票が無い${why}</p>`;
  if (uc.requirements.length === 0) return missing;
  const blocks = uc.requirements
    .map((r) => {
      const lines = r.lines.map((l) => {
        const refs = l.references
          .map((ref) =>
            ref.known
              ? escapeHtml(ref.raw)
              : `<span class="unknown" title="表に無い、または読めない参照">${escapeHtml(marked(ref.raw, false))}</span>`,
          )
          .join('、');
        // 例の欠けの注記は、残る行では作業ツリーにある例だけで決め、基準の版から加えた例はその後ろに印付きで並べる。
        // 例を求めない行（検査の example-missing と同じ判定）には出さない
        const note =
          !l.scenarios.some(liveIn(uc, r, l)) && uc.exampleFiles.length > 0 && !l.exampleNotRequired
            ? '<p class="missing">この行に結び付く例が無い</p>'
            : '';
        const examples = note + (l.scenarios.length > 0 ? scenarioList(l.scenarios) : '');
        // 要求文の区分の印は行の先頭に付ける。RDRA 欄の文字列とツールチップには付けない
        return `<li><p class="sentence">${diffMark(l)}${sentenceHtml(l, view.tableNames)}</p>
${definitionsHtml(l)}
<dl class="fields"><dt>理由</dt><dd>${escapeHtml(l.reason ?? '（欄が無い）')}</dd><dt>RDRA</dt><dd>${refs === '' ? 'なし' : refs}</dd></dl>
${examples}</li>`;
      });
      const reason = r.reason === null ? '（節が無い）' : escapeHtml(r.reason).replace(/\n/g, '<br>');
      return `<p class="file">${escapeHtml(r.file)}${diffMark(r)}</p>
<p><strong>理由:</strong> ${reason}</p>
<ol class="lines">${lines.join('\n')}</ol>`;
    })
    .join('\n');
  // 残る UC で作業ツリーにある票が無い（票を全て外した）ときは、「要求票が無い」を出し、外された票を後ろに印付きで並べる
  return uc.requirements.some(liveIn(uc)) ? blocks : `${missing}\n${blocks}`;
}

// 例の欄。「例が無い」は exampleFiles で決まる。残る UC の exampleFiles は作業ツリーの、外された UC のものは基準の版の
// ファイルなので、件数と同じ原則（残る容れ物は作業ツリー、外された容れ物は基準の版）に既に沿う
function exampleBlock(uc: UseCaseView): string {
  const parts: string[] = [];
  if (uc.exampleFiles.length === 0) {
    parts.push(onlyExampleFreeLines(uc) ? '<p>例が無い（例を求めない行だけの UC）</p>' : '<p class="missing">例が無い</p>');
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
    // 警告の様式は、作業ツリーにある子（結び付かないルールとルールの外の例）があるときだけ付ける。作業ツリーにある
    // 結び付かないルールは、例の有無によらず検査の example-rule-mismatch に当たる（例を全て外して残したルールも同じ）。
    // 残る UC で基準の版から加えた外された例だけが残る枠は、作業ツリーに無い欠陥を示さないよう、警告の様式を付けずに出す
    const live = liveIn(uc);
    const warn = uc.unlinkedRules.some(live) || uc.looseScenarios.some(live);
    parts.push(
      `<div class="${warn ? 'unlinked' : 'unlinked-gone'}"><h4>要求票の行に結び付かない例</h4><ul>${rules.join('\n')}</ul></div>`,
    );
  }
  return parts.join('\n');
}

function sliceSection(uc: UseCaseView, view: View): string {
  const roles = (xs: (NamedView & { role: string; open: OpenView[] })[]) =>
    xs
      .map((x) => `<li>${nameHtml(x)}${diffMark(x)}${x.role === '' ? '' : `（${escapeHtml(x.role)}）`}${openHtml(x.open)}</li>`)
      .join('');
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
              `<tr><td>${nameHtml(i)}${diffMark(i)}</td><td>${escapeHtml(i.description)}${openHtml(i.open)}</td><td>${escapeHtml(i.attributes.join('、'))}</td></tr>`,
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
                  `<div>${nameHtml(v)}${diffMark(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join('、'))}` : ''}</div>`,
              )
              .join('');
            return `<tr><td>${nameHtml(c)}${diffMark(c)}</td><td>${escapeHtml(c.description)}${openHtml(c.open)}</td><td>${vs}</td></tr>`;
          })
          .join('')}</tbody></table>`;
  return `<section class="slice" id="${uc.anchor}">
<details>
<summary><h2>${escapeHtml(uc.name)}${diffMark(uc)} ${hypothesisBadge(uc.hypothesis)}</h2></summary>
<p>${escapeHtml(uc.description)}${openHtml(uc.open)}</p>
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
</details>
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

// 表の全ての未決の印の一覧。縦串に現れない要素（どの UC からも指されない条件・バリエーション・アーキテクチャ特性など）の未決もここで読める。
// 並びと所在は check --open と同じ。印が1つも無ければ節を出さない
function openBlock(view: View): string {
  if (view.open.length === 0) return '';
  const rows = view.open.map(
    (e) =>
      `<tr><td>${escapeHtml(e.target)}</td><td>${escapeHtml(e.key)}</td><td><span class="open">未決: ${escapeHtml(e.content)}</span></td><td class="file">${escapeHtml(`${e.file}:${e.line}`)}</td></tr>`,
  );
  return `<section id="open"><h2>未決の一覧</h2>
<p class="note">表の『未決』キーの項目。決まったら項目を外す。</p>
<table><thead><tr><th>要素</th><th>欄</th><th>未決の内容</th><th>所在</th></tr></thead>
<tbody>${rows.join('\n')}</tbody></table>
</section>`;
}

function timestamp(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  const offset = -d.getTimezoneOffset();
  const sign = offset >= 0 ? '+' : '-';
  const tz = `${sign}${p(Math.floor(Math.abs(offset) / 60))}:${p(Math.abs(offset) % 60)}`;
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())} ${tz}`;
}

const STYLE = `
:root { --fg:#212529; --bg:#ffffff; --muted:#6c757d; --line:#dee2e6; --panel:#f8f9fa; --warn:#c92a2a; --accent:#1c7ed6; --tip-bg:#343a40; --tip-fg:#f8f9fa; --open:#d9480f; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e9ecef; --bg:#1e1f22; --muted:#adb5bd; --line:#3a3d42; --panel:#26282c; --warn:#ff8787; --accent:#74c0fc; --tip-bg:#f1f3f5; --tip-fg:#212529; --open:#ffa94d; }
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
section.slice { border-top:1px solid var(--line); margin-top:0; padding:6px 0; }
section.slice > details > summary { cursor:pointer; }
section.slice > details > summary h2 { display:inline; margin:0; }
.cols { display:flex; gap:32px; flex-wrap:wrap; }
.open { display:inline-block; margin:2px 4px; padding:0 6px; border:1px solid var(--open); border-radius:4px; color:var(--open); font-size:12px; font-weight:normal; vertical-align:middle; }
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

// 描き分けの印の規則。基準の版があるときだけ STYLE の後ろに足す
const DIFF_STYLE = `span.diff { display:inline-block; margin:0 4px; padding:0 6px; border-radius:4px; font-size:12px; font-weight:600; vertical-align:middle; }
span.diff[data-diff="added"] { background:#ebfbee; color:#2b8a3e; }
span.diff[data-diff="changed"] { background:#f3f0ff; color:#5f3dc4; }
span.diff[data-diff="removed"] { background:#fff5f5; color:#c92a2a; }
.unlinked-gone { border:1px solid var(--line); border-radius:6px; padding:4px 12px; margin:8px 0; }
`;

// 状態遷移図の凡例の後ろに足す、描き分けの区分の説明
const DIFF_LEGEND =
  '基準の版との違い: 状態の節点と遷移の辺は、名札の先頭の印（［足された］・［変わった］・［外された］）と色（緑・紫・赤）で示す。' +
  '破線は今どおり仮説の遷移だけを示す。UC の縦串の図では、辺の色は UC の強調を示し、辺の区分は名札の印だけで示す。' +
  '表と縦串では、違いのある要素の名前に「足された」「変わった（変わった欄）」「外された」の印を付ける。';

export function renderHtml(view: View, generatedAt: Date): string {
  const models =
    view.stateModels.length === 0
      ? '<p class="note">状態の表に状態モデルが無い</p>'
      : view.stateModels.map((m) => stateModelSection(m, view)).join('\n');
  const stray = strayBlock(view);
  const open = openBlock(view);
  // 基準の版の行・凡例・CSS は、基準の版があるときだけ出す
  const base =
    view.base === undefined
      ? ''
      : `\n<p>基準の版: ${escapeHtml(view.base.ref)}（${escapeHtml(view.base.commit.slice(0, 12))}）</p>`;
  const legend = view.base === undefined ? '' : `\n<p class="note">${DIFF_LEGEND}</p>`;
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RDRA の設計の可視化</title>
<style>${STYLE}${view.base === undefined ? '' : DIFF_STYLE}</style>
</head>
<body id="top">
<header>
<h1>RDRA の設計の可視化</h1>
<p>生成時刻: ${escapeHtml(timestamp(generatedAt))}</p>
<p>根: ${escapeHtml(view.root)}</p>${base}
<nav><a href="#states">状態遷移図</a><a href="#use-cases">UC の一覧</a>${open === '' ? '' : '<a href="#open">未決の一覧</a>'}${stray === '' ? '' : '<a href="#stray">結び付かない要求票・例</a>'}
要求の行の中身（名前のクリックでも開閉）: <button type="button" data-defs="open">すべて開く</button><button type="button" data-defs="close">すべて閉じる</button></nav>
</header>
<section id="states"><h2>状態遷移図</h2>
<p class="note">実線は事実、破線は仮説の遷移。${UNKNOWN_MARK} は表に無い名前。</p>${legend}
${models}
</section>
<section id="use-cases"><h2>UC の一覧</h2>
${useCaseIndex(view)}
</section>
${open}
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
// アンカーが指す UC の縦串を開く。開くだけで閉じず、他の縦串の開閉に触れない
function openSlice(hash) {
  if (!hash || hash.length < 2 || hash.charAt(0) !== '#') return;
  let target = null;
  try {
    target = document.getElementById(decodeURIComponent(hash.slice(1)));
  } catch (e) {
    return;
  }
  if (!target) return;
  const d = target.matches('section.slice') ? target.querySelector(':scope > details') : target.closest('details');
  if (d) d.open = true;
}
openSlice(location.hash);
window.addEventListener('hashchange', () => openSlice(location.hash));
// # 以下が変わらない再訪（開いて閉じた縦串へのリンクをもう一度押す）は hashchange が起きないため、押下で拾う
for (const a of document.querySelectorAll('a[href^="#"]')) {
  a.addEventListener('click', () => openSlice(a.getAttribute('href')));
}
</script>
<script type="module">
import mermaid from '${MERMAID_URL}';
const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: dark ? 'neutral' : 'default' });
// 閉じた縦串の中の図は、その縦串を開いたときに描く（閉じた中の寸法が取れないブラウザで図が崩れないように）。
// 描画は1本の連鎖で順に行う。描画を重ねると、同じミリ秒に作った図の ID が重なって別の図へ描き込まれ、
// まだ手を付けていない要素が二重に渡りうるため、各段は前の描画が終わってから描く対象を選ぶ。
let chain = Promise.resolve();
function draw() {
  chain = chain
    .then(async () => {
      const nodes = [...document.querySelectorAll('pre.mermaid:not([data-processed])')].filter(
        (n) => !n.closest('details:not([open])'),
      );
      if (nodes.length > 0) await mermaid.run({ nodes });
    })
    .catch((e) => console.error(e));
}
draw();
// toggle は泡立たないため、捕捉の段で受ける。閉じたときは何もしない
document.addEventListener(
  'toggle',
  (e) => {
    if (e.target instanceof HTMLDetailsElement && e.target.open) draw();
  },
  true,
);
</script>
</body>
</html>
`;
}
