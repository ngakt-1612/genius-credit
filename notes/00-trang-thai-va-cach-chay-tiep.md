# Handoff — Daily Quota vòng 2 (25/10 13:10) — ĐÃ XONG phần chạy được
Kết quả: 69 PASS · 26 FAIL · 12 Lệch spec · 4 Cần xem · 11 Pending · 37 Chờ. xlsx ~/Downloads/TC_IIP055.1.16_Daily_Quota_Topup_ket_qua_v2.xlsx · GitHub ngakt-1612/genius-credit (cc333f0).
Máy: iPhone 12 có gói Yearly sandbox (mua lại 25/10 ~11:13), ví 0/0 + có thể còn lượt giữ (N078). RC ép trong code = grandfather 2026-10-24. App có 2 bản vá DEBUG (app-backup/).
Chạy thêm được: N087 (khi máy free: scripts/run-genius-290-quota-round2-n087-when-free.sh) · N172 (khi Home hết lỗi server) · N171 Restore Purchases · N083/N122 (RC mốc giữa 2 lần gia hạn) · N057/N115 (đổi giờ máy — cần đồng ý).
Pending theo user: reset 07:00 · N048–N050/N100. Chờ BE: 14 TC.
Khôi phục app: cp app-backup/*.before-round2 về đúng đường dẫn (RemoteConfigRepositoryImpl.swift, DebugSubStateView.swift, project.pbxproj).
