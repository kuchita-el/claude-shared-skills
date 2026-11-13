// 検査器の互換の世代。`living-spec compat` で答える。
// 上げるときは同じ PR で、中継（plugins/living-spec/scripts/run.mjs）の REQUIRED_COMPAT も同じ値へ上げる（scripts/tests/living-spec-run.bats が照合する）。
// どの変更で上げるか・なぜ整数か・上げた後の Release の手順の正本は docs/development/living-spec-release.md の「互換の世代を上げる変更」。
export const COMPAT = 2;
