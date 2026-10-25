#!/bin/bash
# Daily Quota vòng 2 — phần user KHÔNG gói (sub cũ hết hạn, còn topup). RC ép trong code: grandfather = hôm nay.
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD = scratchpad/dd290}
RUN=scripts/run-genius-290-device-suite.sh
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"   # thẻ style ảnh trên feed Home (dò bằng test10_findI2IStyle)
while pgrep -f "xcodebuild test-without-building" >/dev/null; do sleep 15; done
"$RUN" build || { echo "BUILD FAIL"; exit 1; }
# Tiền đề các test sau: ví topup = 0. test02 lỗi máy (cài app hỏng…) thì chạy lại, quá 2 lần thì dừng.
for i in 1 2 3; do
  "$RUN" RUN_G290_R2 "Genius290QuotaRound2UITests/test02_spendTopupToZero" "r2free-test02_spendTopupToZero"
  grep -h "^SPEND|xong|topup=0" "$G290_OUT"/r2free-test02_spendTopupToZero-*.log 2>/dev/null | grep -q . && break
  [ "$i" = 3 ] && { echo "TOPUP_NOT_ZERO — dừng"; exit 1; }
done
for t in test03_freeNoTopupHeader test04_offlineBlocksBeforeChain test05_enhanceChain test06_killAtTopupOffer; do
  "$RUN" RUN_G290_R2 "Genius290QuotaRound2UITests/$t" "r2free-$t"
done
echo "== xong phần free"
