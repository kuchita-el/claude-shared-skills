// 描き分けの材料を組む。作業ツリーの材料（buildView）を土台に、差分（diff.ts）で区分が「外された」の要素だけを
// 基準の版の材料から加え、全ての要素に区分を付ける。HTML の文字列は html.ts が作る。
// 基準の版の容れ物（UC・条件）の中身を全て加えないのは、容れ物から外れただけで表に残る要素（UC のアクターから外した上長等）に
// 「外された」が付き、変わっていない要素に印を付けることになるためである。容れ物から外れたことは、容れ物の「変わった」と欄名が示す。
// 加えた要素の中の子の要素（外された UC のアクター等）には、子自身の区分を付ける。
import type { BaseVersion } from './base.ts';
import { diffIndex, diffSources, OUTSIDE_RULE } from './diff.ts';
import type { ElementKind } from './diff.ts';
import type { Sources } from './sources.ts';
import { buildView } from './view.ts';
import type {
  DiffStatus,
  Marked,
  NamedView,
  ReferenceView,
  RequirementLineView,
  RequirementView,
  RuleView,
  ScenarioView,
  StateModelView,
  TransitionView,
  UseCaseView,
  VariationView,
  View,
} from './view.ts';

type Parts = (string | null)[];
type ConditionView = UseCaseView['conditions'][number];

// 行の参照のうち、行の直下に畳む中身を持ちうる種類。他の種類（RDRA 欄の文字列としてだけ出る）には区分を付けない
const DEFINED_KINDS: readonly ElementKind[] = ['条件', 'バリエーション', '情報'];

export function buildDiffView(root: string, base: BaseVersion, head: Sources): View {
  const find = diffIndex(diffSources(base.sources, head));
  const before = buildView(root, base.sources);
  const after = buildView(root, head);

  // 要素の区分の欄。差分に無い（変わっていない）要素には欄を作らない
  const mark = (kind: ElementKind, parts: Parts): Marked => {
    const e = find(kind, parts);
    if (e === undefined) return {};
    return e.status === 'changed' ? { diff: e.status, changed: e.changed } : { diff: e.status };
  };
  const removed = (kind: ElementKind, parts: Parts): boolean => find(kind, parts)?.status === 'removed';
  // 基準の版の容れ物 xs の中で区分が「外された」の要素のうち、作業ツリーの同じ容れ物の並び heads に同じ名前が無いもの。
  // 表から外した名前を作業ツリーの UC・条件がまだ挙げている（検査の undefined-reference に当たる）とき、
  // その名前は heads に残るので、基準の版から同じ名前を足さない（同じ要素を二重に並べない）
  const gone = <T extends NamedView>(kind: ElementKind, xs: T[], heads: readonly NamedView[]): T[] =>
    xs.filter((x) => removed(kind, [x.name]) && !heads.some((h) => h.name === x.name));
  const named =
    <T extends NamedView>(kind: ElementKind) =>
    (x: T): T => ({ ...x, ...mark(kind, [x.name]) });

  const markVariation = named<VariationView>('バリエーション');
  // 基準の版の条件 → そのバリエーションの並び。条件のバリエーションは条件の表の記録から決まり、UC の条件の表にも
  // 行の直下の中身にも同じ並びで出るので、基準の版の材料のどちらに出た物からでも条件の名前で引く
  // （条件を UC が挙げず、行の RDRA 欄からだけ指す形を落とさないため）
  const baseVariations = new Map<string, VariationView[]>();
  for (const uc of before.useCases) {
    for (const c of uc.conditions) if (!baseVariations.has(c.name)) baseVariations.set(c.name, c.variations);
    for (const ref of uc.requirements.flatMap((r) => r.lines.flatMap((l) => l.references))) {
      if (ref.kind === '条件' && ref.name !== null && ref.definition !== null && !baseVariations.has(ref.name)) {
        baseVariations.set(ref.name, ref.definition.variations);
      }
    }
  }
  // 条件のバリエーションの並びに区分を付ける。作業ツリーの条件（fromHead）には、基準の版の同じ条件にあって区分が「外された」の
  // バリエーションを後ろに足す。基準の版から加えた条件（外された条件・外された行の中身）は基準の版の並びのままなので足さない。
  // UC の条件の表と行の直下の条件の中身が共用する
  const conditionVariations = (condition: string, variations: VariationView[], fromHead: boolean): VariationView[] =>
    [
      ...variations,
      ...(fromHead ? gone('バリエーション', baseVariations.get(condition) ?? [], variations) : []),
    ].map(markVariation);
  const markCondition =
    (fromHead: boolean) =>
    (c: ConditionView): ConditionView => ({
      ...c,
      ...mark('条件', [c.name]),
      variations: conditionVariations(c.name, c.variations, fromHead),
    });
  // 行の参照の中身（条件・バリエーション・情報）には、参照先の要素の区分を付ける。中身のバリエーションは条件だけが持つ
  const markReference =
    (fromHead: boolean) =>
    (r: ReferenceView): ReferenceView => {
      const kind = DEFINED_KINDS.find((k) => k === r.kind);
      const name = r.name;
      if (kind === undefined || name === null) return r;
      const d = r.definition;
      const definition =
        d === null || kind !== '条件' ? d : { ...d, variations: conditionVariations(name, d.variations, fromHead) };
      return { ...r, ...mark(kind, [name]), definition };
    };
  const markScenario =
    (uc: string, rule: string) =>
    (s: ScenarioView): ScenarioView => ({ ...s, ...mark('例', [uc, rule, s.name]) });
  const markLine =
    (uc: string, fromHead: boolean) =>
    (l: RequirementLineView): RequirementLineView => ({
      ...l,
      ...mark('要求文', [uc, l.text]),
      references: l.references.map(markReference(fromHead)),
      scenarios: l.scenarios.map(markScenario(uc, l.text)),
    });
  const markRequirement =
    (uc: string, fromHead: boolean) =>
    (r: RequirementView): RequirementView => ({
      ...r,
      ...mark('要求票', [uc]),
      lines: r.lines.map(markLine(uc, fromHead)),
    });
  const markRule =
    (uc: string) =>
    (r: RuleView): RuleView => ({ ...r, scenarios: r.scenarios.map(markScenario(uc, r.name)) });

  // 状態モデル。状態と遷移は作業ツリーの並びの後ろに、外された状態と外された遷移の記録（その4つ組を持つ記録の全て）を足す。
  // 遷移の区分は記録ごとに、その記録の（状態モデル・遷移元・遷移先・遷移UC）の要素から引く
  const overlayModel = (name: string, now: StateModelView | undefined, was: StateModelView | undefined): StateModelView => {
    const key = (t: TransitionView): Parts => [name, t.from, t.to, t.uc];
    const states = [...(now?.states ?? []), ...(was?.states ?? []).filter((s) => removed('状態', [name, s]))];
    // Object.fromEntries は各々の状態の名前を自分の欄として定義する。代入（stateDiff[s] = …）で組むと、
    // __proto__ という名前の状態の区分が継承の差し替えとして扱われ、黙って消える
    const stateDiff: Record<string, DiffStatus> = Object.fromEntries(
      states.flatMap((s): [string, DiffStatus][] => {
        const status = find('状態', [name, s])?.status;
        return status === undefined ? [] : [[s, status]];
      }),
    );
    const transitions = [
      ...(now?.transitions ?? []),
      ...(was?.transitions ?? []).filter((t) => removed('遷移', key(t))),
    ].map((t) => ({ ...t, ...mark('遷移', key(t)) }));
    return { name, states, transitions, stateDiff };
  };
  const stateModels = [
    ...after.stateModels.map((m) => overlayModel(m.name, m, before.stateModels.find((x) => x.name === m.name))),
    ...before.stateModels
      .filter((m) => !after.stateModels.some((x) => x.name === m.name))
      .map((m) => overlayModel(m.name, undefined, m)),
  ];

  // UC 1つ。uc の並びに区分を付け、基準の版の同じ UC（old）にあって区分が「外された」の要素を後ろに足す。
  // fromHead は uc が作業ツリーの材料か。外された UC は基準の版の材料を old なし・fromHead なしで渡し、
  // 中の要素の全てに子自身の区分を付ける
  const overlayUseCase = (uc: UseCaseView, anchor: string, old: UseCaseView | undefined, fromHead: boolean): UseCaseView => {
    const name = uc.name;
    const withGone = <T extends NamedView>(kind: ElementKind, heads: T[], bases: T[] | undefined): T[] =>
      [...heads, ...gone(kind, bases ?? [], heads)].map(named<T>(kind));

    // 基準の版でルール（＝要求文）rule に属した例のうち、外された例。行の下か結び付かないルールのどちらか一方にある
    const goneScenarios = (rule: string): ScenarioView[] => {
      if (old === undefined) return [];
      const line = old.requirements.flatMap((r) => r.lines).find((l) => l.text === rule);
      const scenarios =
        line !== undefined ? line.scenarios : old.unlinkedRules.filter((r) => r.name === rule).flatMap((r) => r.scenarios);
      return scenarios.filter((s) => removed('例', [name, rule, s.name]));
    };

    // 外された行は同じ UC の最初の票の後ろに足す。作業ツリーにこの UC の票が無ければ、
    // 票の区分が「外された」になり、基準の版の票が行ごと加わる
    const goneLines = (old?.requirements ?? []).flatMap((r) => r.lines).filter((l) => removed('要求文', [name, l.text]));
    const requirements = [
      ...uc.requirements.map((r, i): RequirementView => ({
        ...r,
        ...mark('要求票', [name]),
        lines: [
          ...r.lines.map((l) => ({ ...l, scenarios: [...l.scenarios, ...goneScenarios(l.text)] })).map(markLine(name, fromHead)),
          ...(i === 0 ? goneLines : []).map(markLine(name, false)),
        ],
      })),
      ...(removed('要求票', [name]) ? (old?.requirements ?? []) : []).map(markRequirement(name, false)),
    ];

    // 結び付かないルールは、作業ツリーの同じ名前の最初のルールに外された例を足し、
    // 作業ツリーのこの UC に同じ名前のルール（行か結び付かないルール）が無い基準の版のルールを後ろに足す
    const headRules = new Set([...uc.requirements.flatMap((r) => r.lines.map((l) => l.text)), ...uc.unlinkedRules.map((r) => r.name)]);
    const unlinkedRules = [
      ...uc.unlinkedRules.map((r, i) =>
        uc.unlinkedRules.findIndex((x) => x.name === r.name) === i
          ? { ...r, scenarios: [...r.scenarios, ...goneScenarios(r.name)] }
          : r,
      ),
      ...(old?.unlinkedRules ?? []).filter((r) => !headRules.has(r.name)),
    ].map(markRule(name));

    return {
      ...uc,
      ...mark('UC', [name]),
      anchor,
      actors: withGone('アクター', uc.actors, old?.actors),
      externalSystems: withGone('外部システム', uc.externalSystems, old?.externalSystems),
      information: withGone('情報', uc.information, old?.information),
      conditions: [
        ...uc.conditions.map(markCondition(fromHead)),
        ...gone('条件', old?.conditions ?? [], uc.conditions).map(markCondition(false)),
      ],
      // 遷移 UC になっている状態モデルは、重ね合わせた後の遷移から決め直す（外された UC は外された遷移から持つ）
      stateModels: stateModels.filter((m) => m.transitions.some((t) => t.uc === name)).map((m) => m.name),
      requirements,
      unlinkedRules,
      looseScenarios: [
        ...uc.looseScenarios,
        ...(old?.looseScenarios ?? []).filter((s) => removed('例', [name, OUTSIDE_RULE, s.name])),
      ].map(markScenario(name, OUTSIDE_RULE)),
    };
  };

  // 外された UC は作業ツリーの UC の後ろに並べ、アンカーを続き番号にする（作業ツリーの UC のアンカーを描き分けの有無で変えない）
  const useCases = [
    ...after.useCases.map((uc) => overlayUseCase(uc, uc.anchor, before.useCases.find((u) => u.name === uc.name), true)),
    ...before.useCases
      .filter((u) => removed('UC', [u.name]))
      .map((u, i) => overlayUseCase(u, `uc-${after.useCases.length + i + 1}`, undefined, false)),
  ];

  // 表にある名前・結び付かない要求票と例の枠は作業ツリーの物をそのまま使い、区分を付けない
  return { ...after, stateModels, useCases, base: { ref: base.ref, commit: base.commit } };
}
