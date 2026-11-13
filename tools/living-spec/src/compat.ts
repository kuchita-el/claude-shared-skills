// 検査器の互換の世代。プラグイン（plugins/living-spec）の手順・書式が前提とする振る舞いを、この値より古い検査器が満たせなくなる変更で1つ上げる。
// 上げるときは同じ PR で、中継（plugins/living-spec/scripts/run.mjs）の REQUIRED_COMPAT も同じ値へ上げる（scripts/tests/living-spec-run.bats が照合する）。
// どの変更で上げるかと、上げた後の Release の手順の正本は docs/development/living-spec-release.md の「互換の世代を上げる変更」。
// SHA や日時でなく PR の中で決まる整数にするのは、マージの後に決まる値では、前提をマージと同時に上げられないため
export const COMPAT = 1;
