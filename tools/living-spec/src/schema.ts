// RDRA の表の定義と各層の置き場。検査器の正本。表やキーを足し引きするときはここだけを直す。
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// 各層の置き場（根からの相対パス）。根の .living-spec.json で上書きできる（configureLayout）
export interface Layout {
  tables: string;
  requirements: string;
  examples: string;
  // 設計の可視化の書き出し先
  output: string;
  // false なら PostToolUse フックが検査も描画もしない
  hook: boolean;
}

export const CONFIG_FILE = '.living-spec.json';

const DEFAULT_LAYOUT: Layout = {
  tables: 'docs/rdra',
  requirements: 'docs/requirements',
  examples: 'docs/examples',
  output: '.cache/living-spec/index.html',
  hook: true,
};

export const LAYOUT: Layout = { ...DEFAULT_LAYOUT };

// 根の .living-spec.json を読んで LAYOUT を差し替える。無ければ既定に戻す。読めない・型が違うときは例外
export function configureLayout(root: string): Layout {
  Object.assign(LAYOUT, DEFAULT_LAYOUT);
  const path = join(root, CONFIG_FILE);
  if (!existsSync(path)) return LAYOUT;
  const data: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new Error(`${CONFIG_FILE} はオブジェクトで書く`);
  }
  for (const [key, value] of Object.entries(data)) {
    if (!Object.hasOwn(DEFAULT_LAYOUT, key)) throw new Error(`${CONFIG_FILE} の未知のキー『${key}』`);
    const want = typeof DEFAULT_LAYOUT[key as keyof Layout];
    if (typeof value !== want || value === '') throw new Error(`${CONFIG_FILE} の『${key}』は${want === 'boolean' ? '真偽値' : '空でない文字列'}で書く`);
    (LAYOUT as unknown as Record<string, unknown>)[key] = typeof value === 'string' ? value.replace(/\/+$/, '') : value;
  }
  return LAYOUT;
}

// string: YAML のスカラー文字列。list: 文字列のシーケンス。
export type ValueType = 'string' | 'list';

export interface TableDef {
  // 表の識別子（ファイル名から拡張子を除いたもの）
  id: string;
  // 根からの相対パス（LAYOUT.tables の下の <id>.yaml）
  readonly file: string;
  // 違反の target に使う種類名。state 表は個々のレコードを「状態」、名前キーを「状態モデル」として扱う
  kind: string;
  // 名前キー（必須・空不可の文字列）
  nameKey: string;
  // 許すキーと値の型。名前キーと仮説を含む
  keys: Record<string, ValueType>;
  // 値が「、」区切りの1文字列であるキー（参照の解決では分割して扱う）
  splitKeys: string[];
  // 省略・空（null・空文字）を許すキー
  emptyOkKeys: string[];
}

const HYPOTHESIS = '仮説';

export const TABLES: TableDef[] = [
  {
    id: 'actor',
    get file() {
      return `${LAYOUT.tables}/actor.yaml`;
    },
    kind: 'アクター',
    nameKey: 'アクター',
    keys: { アクター: 'string', 役割: 'string', 社内外: 'string', [HYPOTHESIS]: 'list' },
    splitKeys: [],
    emptyOkKeys: [],
  },
  {
    id: 'external-system',
    get file() {
      return `${LAYOUT.tables}/external-system.yaml`;
    },
    kind: '外部システム',
    nameKey: '外部システム',
    keys: { 外部システム: 'string', 役割: 'string', [HYPOTHESIS]: 'list' },
    splitKeys: [],
    emptyOkKeys: [],
  },
  {
    id: 'information',
    get file() {
      return `${LAYOUT.tables}/information.yaml`;
    },
    kind: '情報',
    nameKey: '情報',
    keys: {
      情報: 'string',
      属性: 'string',
      関連情報: 'string',
      状態モデル: 'string',
      バリエーション: 'string',
      説明: 'string',
      [HYPOTHESIS]: 'list',
    },
    splitKeys: ['属性', '関連情報', '状態モデル', 'バリエーション'],
    emptyOkKeys: [],
  },
  {
    id: 'state',
    get file() {
      return `${LAYOUT.tables}/state.yaml`;
    },
    kind: '状態',
    nameKey: '状態モデル',
    keys: {
      状態モデル: 'string',
      状態: 'string',
      遷移UC: 'string',
      遷移先状態: 'string',
      '状態モデル・状態の説明': 'string',
      [HYPOTHESIS]: 'list',
    },
    splitKeys: [],
    // 初期遷移は 状態 を、終端の状態は 遷移UC・遷移先状態 を省略または空にする
    emptyOkKeys: ['状態', '遷移UC', '遷移先状態'],
  },
  {
    id: 'use-case',
    get file() {
      return `${LAYOUT.tables}/use-case.yaml`;
    },
    kind: 'UC',
    nameKey: 'UC',
    keys: {
      UC: 'string',
      アクター: 'list',
      外部システム: 'list',
      情報: 'list',
      条件: 'list',
      説明: 'string',
      [HYPOTHESIS]: 'list',
    },
    splitKeys: [],
    emptyOkKeys: [],
  },
  {
    id: 'condition',
    get file() {
      return `${LAYOUT.tables}/condition.yaml`;
    },
    kind: '条件',
    nameKey: '条件',
    keys: {
      条件: 'string',
      条件の説明: 'string',
      バリエーション: 'string',
      状態モデル: 'string',
      [HYPOTHESIS]: 'list',
    },
    splitKeys: ['バリエーション', '状態モデル'],
    emptyOkKeys: [],
  },
  {
    id: 'variation',
    get file() {
      return `${LAYOUT.tables}/variation.yaml`;
    },
    kind: 'バリエーション',
    nameKey: 'バリエーション',
    keys: { バリエーション: 'string', 値: 'string', 説明: 'string', [HYPOTHESIS]: 'list' },
    splitKeys: ['値'],
    emptyOkKeys: [],
  },
  {
    id: 'architecture-characteristic',
    get file() {
      return `${LAYOUT.tables}/architecture-characteristic.yaml`;
    },
    kind: 'アーキテクチャ特性',
    nameKey: 'アーキテクチャ特性',
    keys: {
      アーキテクチャ特性: 'string',
      分類: 'string',
      説明: 'string',
      検証方法: 'string',
      [HYPOTHESIS]: 'list',
    },
    splitKeys: [],
    emptyOkKeys: [],
  },
];

export function tableById(id: string): TableDef {
  const t = TABLES.find((x) => x.id === id);
  if (!t) throw new Error(`未知の表: ${id}`);
  return t;
}

// 要求票の RDRA 欄で使える種類の語彙。名前の突き合わせ先の表を持つ
// （状態モデルは state 表の 状態モデル 値、状態は state 表の 状態 値）。
export const REQUIREMENT_KINDS = [
  'アクター',
  '外部システム',
  '情報',
  '状態モデル',
  '状態',
  'UC',
  '条件',
  'バリエーション',
  'アーキテクチャ特性',
] as const;

// 要求票（<requirements>/*.md）と例（<examples>/*.feature）の読み方。
// 表題は「# 要求票: <UC 名>」。UC 名が UC の表との照合のキー
export const REQUIREMENT_TITLE_LABEL = '要求票';
// 仕様の行は「## 仕様」節の番号つきの行。直後の字下げされた「- RDRA: 」の行が参照の欄
export const REQUIREMENT_SPEC_HEADING = '仕様';
export const REQUIREMENT_RDRA_FIELD = 'RDRA';
// 表題の直後の「## 理由」節と、仕様の行の「- 理由: 」の欄。検査は読まず、描画（render.ts）だけが使う
export const REQUIREMENT_REASON_HEADING = '理由';
export const REQUIREMENT_REASON_FIELD = '理由';
// 参照の欄で「参照なし」を表す値
export const REQUIREMENT_NO_REFERENCE = 'なし';
// 状態の参照は「状態「<状態モデル>/<状態>」」の形
export const REQUIREMENT_STATE_SEP = '/';
// 例は1ルールあたり3件まで
export const EXAMPLE_LIMIT = 3;
