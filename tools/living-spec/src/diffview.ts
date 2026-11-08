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
  DefinitionView,
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
  // 基準の版の容れ物の中で、区分が「外された」の要素
  const gone = <T extends NamedView>(kind: ElementKind, xs: T[]): T[] => xs.filter((x) => removed(kind, [x.name]));
  const named =
    <T extends NamedView>(kind: ElementKind) =>
    (x: T): T => ({ ...x, ...mark(kind, [x.name]) });

  const markVariation = named<VariationView>('バリエーション');
  // extra は基準の版の同じ条件にあって外されたバリエーション（作業ツリーの並びの後ろに足す）
  const markCondition = (c: ConditionView, extra: VariationView[] = []): ConditionView => ({
    ...c,
    ...mark('条件', [c.name]),
    variations: [...c.variations, ...extra].map(markVariation),
  });
  const markDefinition = (d: DefinitionView | null): DefinitionView | null =>
    d === null ? null : { ...d, variations: d.variations.map(markVariation) };
  // 行の参照の中身（条件・バリエーション・情報）には、参照先の要素の区分を付ける
  const markReference = (r: ReferenceView): ReferenceView => {
    const kind = DEFINED_KINDS.find((k) => k === r.kind);
    if (kind === undefined || r.name === null) return r;
    return { ...r, ...mark(kind, [r.name]), definition: markDefinition(r.definition) };
  };
  const markScenario =
    (uc: string, rule: string) =>
    (s: ScenarioView): ScenarioView => ({ ...s, ...mark('例', [uc, rule, s.name]) });
  const markLine =
    (uc: string) =>
    (l: RequirementLineView): RequirementLineView => ({
      ...l,
      ...mark('要求文', [uc, l.text]),
      references: l.references.map(markReference),
      scenarios: l.scenarios.map(markScenario(uc, l.text)),
    });
  const markRequirement =
    (uc: string) =>
    (r: RequirementView): RequirementView => ({ ...r, ...mark('要求票', [uc]), lines: r.lines.map(markLine(uc)) });
  const markRule =
    (uc: string) =>
    (r: RuleView): RuleView => ({ ...r, scenarios: r.scenarios.map(markScenario(uc, r.name)) });

  // 状態モデル。状態と遷移は作業ツリーの並びの後ろに、外された状態と外された遷移の記録（その4つ組を持つ記録の全て）を足す。
  // 遷移の区分は記録ごとに、その記録の（状態モデル・遷移元・遷移先・遷移UC）の要素から引く
  const overlayModel = (name: string, now: StateModelView | undefined, was: StateModelView | undefined): StateModelView => {
    const key = (t: TransitionView): Parts => [name, t.from, t.to, t.uc];
    const states = [...(now?.states ?? []), ...(was?.states ?? []).filter((s) => removed('状態', [name, s]))];
    const stateDiff: Record<string, DiffStatus> = {};
    for (const s of states) {
      const status = find('状態', [name, s])?.status;
      if (status !== undefined) stateDiff[s] = status;
    }
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
  // 外された UC は old を渡さずに呼び、中の要素の全てに子自身の区分を付ける
  const overlayUseCase = (uc: UseCaseView, anchor: string, old: UseCaseView | undefined): UseCaseView => {
    const name = uc.name;
    const withGone = <T extends NamedView>(kind: ElementKind, heads: T[], bases: T[] | undefined): T[] =>
      [...heads, ...gone(kind, bases ?? [])].map(named<T>(kind));

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
      ...uc.requirements.map((r, i) => ({
        ...r,
        lines: [
          ...r.lines.map((l) => ({ ...l, scenarios: [...l.scenarios, ...goneScenarios(l.text)] })),
          ...(i === 0 ? goneLines : []),
        ],
      })),
      ...(removed('要求票', [name]) ? (old?.requirements ?? []) : []),
    ].map(markRequirement(name));

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
        ...uc.conditions.map((c) =>
          markCondition(c, gone('バリエーション', old?.conditions.find((x) => x.name === c.name)?.variations ?? [])),
        ),
        ...gone('条件', old?.conditions ?? []).map((c) => markCondition(c)),
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
    ...after.useCases.map((uc) => overlayUseCase(uc, uc.anchor, before.useCases.find((u) => u.name === uc.name))),
    ...before.useCases
      .filter((u) => removed('UC', [u.name]))
      .map((u, i) => overlayUseCase(u, `uc-${after.useCases.length + i + 1}`, undefined)),
  ];

  // 表にある名前・結び付かない要求票と例の枠は作業ツリーの物をそのまま使い、区分を付けない
  return { ...after, stateModels, useCases, base: { ref: base.ref, commit: base.commit } };
}
