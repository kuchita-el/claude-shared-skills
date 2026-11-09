# living-spec の検査器の Release

living-spec の検査器（`tools/living-spec`）の生成物を、GitHub の Release として切る契機と手順を定める。

## (1) この文書が定めること

配布の形（どこに、どう名指して置くか）は ADR-202611040012-01（検査器を Release の添付物として配る）が決める。この文書は、その Release をいつ・どのコミットで・誰が・どう切るかと、失敗したときの対処を定める。

Release を作る仕組みは `.github/workflows/living-spec-release.yml` である。この文書は、そのワークフローを起動する保守者の手順を持つ。

## (2) いつ切るか

利用者へ届けたい検査器の変更が main に入ったときに切る。検査器の変更とは、ビルドの入力の変更である。ビルドの入力は次の4つである。

- `tools/living-spec/src`
- `tools/living-spec/package.json`
- `tools/living-spec/pnpm-lock.yaml`
- `tools/living-spec/pnpm-workspace.yaml`

ワークフローは `workflow_dispatch` でだけ起動する。保守者が届けると決めたときだけ Release が増え、Release の一覧がそのまま版の候補になるためである。

main への push ごとに Release を作る形は採らない。検査器が変わらないコミットでも Release が増え、利用者が版を選ぶ手がかりにならないためである。

起動契機とその理由の正本は、この節である。

## (3) どのコミットで切るか

起動した時点の main の先頭で切る。保守者はコミットを選ばない。ワークフローは入力を取らず、起動したコミット（`github.sha`）をビルド・試験し、Release にする。起動を main の定義に限るので、このコミットは main の先頭になる（(5)）。

main の先頭に限る理由は、Release の作成の制約にある。対象のコミットが既定のブランチと比べて `.github/workflows/` の下を足すか変えていると、作成にはワークフローを変える権限が要る。ワークフローのトークンには、この権限を付けられない。制約の正本は、GitHub REST API の文書の「Create a release」の注記である。所在は <https://docs.github.com/rest/releases/releases#create-a-release> である。main の先頭で切れば、起動の時点で対象と既定のブランチが食い違わない。

代償は2つある。main の先頭より古いコミットでは切れない。Release の名前が、ビルドの入力を変えていないコミットの SHA になることがある。

公開を取り消した SHA は再び使わない。その SHA の名前は再利用できないためである（ADR-202611040012-01）。取り消した SHA が main の先頭にあるうちは起動しない。main に新しいコミットが入るのを待ってから起動する。

## (4) 誰が切るか

リポジトリへの書き込み権限を持つ保守者が切る。

AI が保守者に代わって起動する場合は、保守者の明示の承認を得てからにする。

## (5) どう切るか

### 起動の前に確かめること

1. リポジトリの Immutable Releases が有効であることを確かめる。

   ```bash
   gh api repos/kuchita-el/claude-shared-skills/immutable-releases --jq .enabled
   ```

   `true` を返せば有効である。この確認には管理者の読み取りの権限が要る。状態コードでは判断しない。GitHub の文書は無効なら 404 と書くが、2026-11-04 に本リポジトリで無効のまま確かめたところ、200 と `enabled: false` が返った。値で判断する。

   `false` なら起動しない。リポジトリの管理者が有効にしてから起動する。手段は2つある。Settings の「Releases」で「Enable release immutability」を選ぶか、次の命令を実行する。

   ```bash
   gh api -X PUT repos/kuchita-el/claude-shared-skills/immutable-releases
   ```

   これはリポジトリの設定の変更である。AI が行う場合は、保守者の明示の承認を得る。初回の Release より前に有効にしておく理由は、ADR-202611040012-01 の Consequences（変更不可が掛かる範囲）にある。

2. 同名の下書きの Release が残っていないことを確かめる。確かめる SHA は、起動する main の先頭である。`git fetch origin` の後に `git rev-parse origin/main` で取る。ワークフローの中の Release の有無の確認は、読み取りの権限で行うため、下書きが見えない。過去の失敗した実行が残した下書きは、その確認をすり抜ける。保守者の認証で次の命令を実行すれば、下書きもタグ名で引ける。gh の `release view` は、公開した Release に加えて、そのタグ名を予定する下書きも探すためである。この振る舞いは、gh 2.97.0 のソースの `pkg/cmd/release/shared/fetch.go` の `FetchRelease` で確かめた。

   ```bash
   gh release view living-spec-<40桁SHA> --repo kuchita-el/claude-shared-skills --json isDraft --jq .isDraft
   ```

   `release not found` で失敗すれば、同名の Release は無い。先へ進む。`true` なら下書きが残っている。(9) の「下書きが残ったとき」に従って消してから起動する。`false` なら、同じ SHA の Release は既に公開されている。その SHA では起動しない。

### 起動と見届け

ワークフローは、定義が既定のブランチ（main）にあるときだけ `workflow_dispatch` で起動できる。起動するときは `--ref` を付けない（UI では「Use workflow from」を main のままにする）。`--ref` で選んだブランチやタグにある版の定義が走るためである。

```bash
gh workflow run living-spec-release.yml --repo kuchita-el/claude-shared-skills
```

main 以外の ref から起動した実行は、ワークフローが止める（何をどう確かめるかは (6)）。この照合は、誤って main 以外の定義で起動したときに止めるためのものである。照合を外した定義をブランチに置いて起動すれば、照合は働かない。それを止めるのは、リポジトリへの書き込み権限を誰に渡すかである（(4)）。

起動した実行を `gh run watch` で見届ける。実行の題名は `living-spec release <40桁SHA>` で、SHA は起動した時点の main の先頭である。実行の ID は、題名で絞って次の命令で取る。一覧は新しい順に並ぶため、最初の1件が最新の実行である。

```bash
gh run list --workflow living-spec-release.yml --repo kuchita-el/claude-shared-skills --json databaseId,displayTitle,createdAt --jq 'map(select(.displayTitle == "living-spec release <40桁SHA>")) | first | {databaseId, createdAt}'
```

起動の直後は、実行が一覧にまだ載っていないことがある。`databaseId` が `null` なら、少し待って引き直す。待っても `null` なら、確認の後に main が動いたことを疑う。`git fetch origin` の後の `git rev-parse origin/main` の SHA で引き直し、その SHA で下書きの確認も行う。同じ SHA で起動し直したときは、前の実行を拾うことがある。`createdAt` が起動の後の時刻であることを確かめる。

```bash
gh run watch <実行の ID> --repo kuchita-el/claude-shared-skills --exit-status
```

### 起動の後に確かめること

1. Release と添付物を確かめる。タグは `living-spec-<40桁SHA>`、添付物は `living-spec-<40桁SHA>.mjs` の1件である。

   ```bash
   gh release view living-spec-<40桁SHA> --repo kuchita-el/claude-shared-skills --json tagName,isDraft,assets
   ```

2. Release が変更不可になったことを確かめる。

   ```bash
   gh api repos/kuchita-el/claude-shared-skills/releases/tags/living-spec-<40桁SHA> --jq .immutable
   ```

   `true` を返せばよい。`false` なら (9) に従う。

## (6) ワークフローが何を確かめるか

この文書には中身を書かない。検査の中身の正本は、ワークフローの定義（`.github/workflows/living-spec-release.yml`）である。構造の不変条件は、`scripts/tests/living-spec-release-workflow.bats` が固定する。

中身を文章へ写すと、ワークフローを変えるたびにこの文書も追随させる義務が増える。そのため、定義と bats を指すだけにする。

## (7) 構造の bats が覆わないもの

構造の bats（`scripts/tests/living-spec-release-workflow.bats`）が何を固定するかは、bats の定義を見る。次の7つは覆わない。ワークフローを変える PR のレビューで確かめる。

1. release job が実行する命令の中身。複合命令・パイプ・拡張の導入で、第三者のコードを走らせないこと
2. 試験した生成物と、受け渡す・添付する生成物が同じであること。置き場、途中の上書き、写す元がビルドの出力であることを見る
3. run の中で使う SHA の出所。SHA は env の SHA・TAG・ASSET から読み、run の中で別の出所から取らないこと
4. build job の中の step の順序。入口と描画の試験の step が存在し、ビルドの後・受け渡しの前にあること。試験の step の命令が、失敗を握りつぶさないこと（`|| true` 等）
5. smoke の中身。matrix の版と、終了コードと使い方の出力の確認
6. タグの照合
7. 起動した ref の照合の step のうち、照合の行と `exit 1` の行の外の中身。照合が外れたときに必ず `exit 1` へ至ること

覆わないものの正本は、この節である。

## (8) 版の名前

この文書の命令は、タグの名前を `living-spec-<40桁SHA>`、添付物の名前を `living-spec-<40桁SHA>.mjs` として書く。

名前の形、公開の後にタグと添付物を変えられないこと、公開を取り消した名前を再利用できないことは、ADR-202611040012-01 の決定が定める。その理由と却下した代替を含め、正本は同 ADR である。この文書には写さない。

## (9) 失敗したとき

保守者が取る対処を、失敗した段ごとに書く。ワークフローが何を確かめるかは、ここでは書き直さない（(6)）。

### build job か smoke job で止まったとき

release job は走らず、Release もタグも作られない。実行の記録で止まった step と理由を読み、原因を直す。main 以外の ref から起動したとして止まったなら、(5) に従い `--ref` を付けずに起動し直す。

同じ SHA の Release が既にあるとして止まったなら、その SHA では切り直さない。既にある Release を使う。

Node 22.0.0 でだけ起動の確認が落ちたら、`plugins/living-spec/README.md` が書く前提（Node 22 以上）の下限を改めるかを判断する。前提の下限は利用者の要求に関わるため、保守者が判断する。

### Release の作成が権限の不足で断られたとき

release job の Release の作成が `403 Resource not accessible by integration` で止まることがある（経路によっては 404）。実行中に、ワークフローのファイルを変えるコミットが main に入ったときに起きる。対象のコミットが、既定のブランチの先頭と比べて `.github/workflows/` の下で食い違い、(3) の制約に当たったためである。同じ実行を再実行しても通らない。

この失敗では、Release は公開されない。(5) の下書きの確認と、同名のタグの確認（`git ls-remote --tags origin refs/tags/living-spec-<40桁SHA>`）を行う。残っていれば、次の「下書きが残ったとき」と「タグの照合で止まったとき」に従う。そのうえで起動し直す。起動し直した実行は、新しい main の先頭で切る。

### 下書きが残ったとき

Release の作成の途中で失敗すると、下書きの Release が残ることがある。下書きを消してから起動し直す。変更不可は公開の後にだけ掛かるので、下書きは消せる。

```bash
gh release delete living-spec-<40桁SHA> --repo kuchita-el/claude-shared-skills --yes
```

下書きは同じ名前で複数残ることがあり、この命令は1件ずつ消す。消した後、(5) の下書きの確認をもう一度行い、下書きが出なくなるまで繰り返す。そのうえで、同名のタグが残っていないかを `git ls-remote --tags origin refs/tags/living-spec-<40桁SHA>` で確かめる。残っていれば、次の「タグの照合で止まったとき」に従う。

### タグの照合で止まったとき

Release の無い同名のタグが残っており、Release は作られていない。残ったタグがどのコミットを指すかを確かめる。

```bash
git ls-remote --tags origin refs/tags/living-spec-<40桁SHA>
```

そのうえで、Release の無いタグを消すかを判断する。消すなら `git push origin --delete refs/tags/living-spec-<40桁SHA>` で消し、起動し直す。

### 公開の後に止まったとき

公開した後の照合が一致しないとき、または Release の `immutable` が `false` のときは、公開を取り消すかを判断する。利用者が既にその名前を固定している可能性があるため、保守者が判断する。

`immutable` が `false` のときは、取り消すかどうかによらず、先に (5) の手段で設定を有効にする。

取り消すときは、タグも一緒に消し、タグと Release の一覧を一対一に保つ。

```bash
gh release delete living-spec-<40桁SHA> --repo kuchita-el/claude-shared-skills --cleanup-tag --yes
```

取り消した SHA では起動し直さない。その名前は再利用できないためである（ADR-202611040012-01）。(3) に従い、main に新しいコミットが入ってから切り直す。

## (10) この文書に書かないもの

個々の Release の記録（どの SHA をいつ切ったか）は書かない。記録の正本は、GitHub の Release の一覧である。
