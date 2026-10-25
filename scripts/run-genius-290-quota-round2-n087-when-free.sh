#!/bin/bash
# N087 (Enhance: Analyze → paywall → phân tích → "Apply All Suggestions" → Last-chance → topup) — cần máy free.
# Chạy sau queue final; máy còn gói thì thử lại 15′/lần, tối đa 2h.
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD}
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"
RUN=scripts/run-genius-290-device-suite.sh
python3 scripts/set-genius-290-rc-code-override.py quota_grandfather_until=2026-10-24T00:00:00Z && "$RUN" build || exit 1
for i in $(seq 1 9); do
  "$RUN" RUN_G290_R2 "Genius290QuotaRound2UITests/test05_enhanceChain" "r2fin-n087-apply"
  L=$(ls -t "$G290_OUT"/r2fin-n087-apply-*.log | head -1)
  grep -q "^N087_SKIP" "$L" || { echo "== xong N087"; exit 0; }
  echo "máy còn gói — thử lại sau 15′ (lần $i)"; sleep 900
done
echo "N087: máy vẫn có gói sau 2h"
