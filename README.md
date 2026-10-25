# Genius iOS 2.9.0 — Autotest Daily Quota & Topup (credit) · IIP055.1.16 · vòng 2

Autotest XCUITest trên iPhone 12 (iOS 26.5.2), build DEBUG `.prod`, sandbox IAP — 24–25/10/2026.
File TC: `TC_IIP055.1.16_Daily_Quota_Topup.xlsx` (bản sửa 24/10, **159 TC**). Kết quả: `results/TC_IIP055.1.16_Daily_Quota_Topup_ket_qua_v2.xlsx` (cột I status · J thực tế · K nguồn/ghi chú · L link ảnh).

## Kết quả

| Status | Số TC | Ghi chú |
|---|---|---|
| PASS | 71 | |
| FAIL | 24 | |
| Lệch spec | 12 | app khác spec, có thể dev cố ý → hỏi PO |
| Cần xem | 4 | N041, N087, N126, N138 |
| Pending | 11 | user cho Pending: nhóm reset 07:00 (N011, N108–N112, N115) · chờ BE auto-release 10′ (N048–N050, N100) |
| Chờ | 37 | 14 cần BE/Infra giả lập · 2 proxy · máy thứ 2 · tài khoản sandbox khác · PO đổi CMS · server lỗi 25/10 — lý do từng TC ở cột K |

- 75 TC đã chạy 22/10 giữ kết quả + ảnh 22/10, **chấm lại theo Expected mới** (N° đổi → map theo nội dung). 84 TC còn lại chạy vòng 2.
- Remote Config: **ép giá trị trong code rồi build lại** (`RemoteConfigRepositoryImpl.codeOverrides`, áp trong `syncAllKeys` để đi đúng luật parse của Firebase) — xem `app-patches/`.
- 25/10 Home lỗi server → lượt gen chạy qua **Enhance (tab Create)**; đo thêm trừ lượt trên các tab còn chạy.

## Phát hiện chính

| TC | Kết quả | Mô tả |
|---|---|---|
| N005, N012 | FAIL | Badge số lượt vẫn hiện với user không gói / sub hết hạn còn topup (`HomeView.swift:912`) |
| N004 | FAIL | Nút Upgrade hiển thị "Pro ✨" (spec cấm) |
| N022, N117 | PASS (PO chốt 25/10) | Grandfather bị ẩn My Balance là **đúng** — Expected TC cần cập nhật |
| N125 | FAIL | `quota_grandfather_until` rỗng (đo cả khi **cài mới**): app bỏ qua chuỗi rỗng → dùng default code `2026-08-11` → `creditV3`, vẫn áp quota (hết lượt → 481); spec "không áp quota cho ai" |
| N147 | Lệch spec | `enable_topup=false`: 481 ẩn nhưng offer topup ở chuỗi free & Get More 413 vẫn hiện (`PaywallView.swift:290`) |
| N078, N099, N105 | Lệch spec / FAIL | Không có màn 482 — mua xong gen chạy tiếp ngay |
| N155 | FAIL | Mô tả App Store còn "unlimited" + gói Monthly, không có "Q lần tạo/ngày" |
| N098 | PASS (ghi chú) | Sub hết hạn → 413=0, chuỗi paywall; app đang mở **~11′ sau** mới nhận hết hạn |
| N034 / N035 | PASS | Trừ đúng 1 lượt: Enhance 19→18 · Restore 18→17 · Remove Object 16→15 · Chat 17→16 (Try On bị chặn: CMS lỗi) |
| N063, N119, N120 | PASS | Grandfather gen 21/21 > Q, không 481, ví không trừ |
| N167 | PASS | Badge giảm dần → 481 ở lượt Q+1 → mua → gen tự chạy tiếp → 413=0 |

Câu hỏi PO (đã trả lời: mua lại gói trong ngày cấp đủ 20 — đúng; grandfather ẩn My Balance — đúng): `notes/po-questions.txt`. Bài học automation: `notes/lessons-24-10.txt`.

## Cấu trúc

```
results/      xlsx kết quả · results-round2.json · manual-regrade.json (chấm tay + lý do)
evidence/     ảnh bằng chứng theo TC (N0xx/, JPG thu nhỏ — bản PNG gốc ở máy test)
tests/        XCUITest vòng 2 (Genius290QuotaRound2*, Genius290QuotaDeductPerToolUITests) + helper
scripts/      queue chạy (run-genius-290-quota-round2-*.sh) · ép RC trong code · build_round2_results.py
app-patches/  diff bản vá DEBUG cho test (RC ép trong code, dòng appUserID trên màn Debug)
notes/        handoff · câu hỏi PO · bài học · việc còn lại
```

## Chạy lại

Ở thư mục source app (`IIP055-Genius-IOS-2.9.0`, đã có các file trong `tests/` + bản vá `app-patches/`):

```bash
export G290_DD=<derived data> TEST_RUNNER_R2_GEN_VIA=enhance        # bỏ GEN_VIA khi Home chạy lại
python3 scripts/set-genius-290-rc-code-override.py quota_grandfather_until=2026-10-24T00:00:00Z
scripts/run-genius-290-device-suite.sh build
scripts/run-genius-290-device-suite.sh RUN_G290_R2SUB Genius290QuotaDeductPerToolUITests/test03_removeObject demo
python3 build_round2_results.py      # gộp verdict → xlsx + thư mục ảnh
```
Máy test phải mở khoá, Auto-Lock = Never; mua gói sandbox hiện sheet Apple — test tự bấm "Subscribe".
