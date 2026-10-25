import XCTest

/// Daily Quota & Topup vòng 2 — phần subscriber (mua gói sandbox hôm nay). RC `quota_grandfather_until`
/// ép trong code (`RemoteConfigRepositoryImpl.codeOverrides`): build A = hôm nay (áp quota),
/// build B = ngày mai (grandfather). Verdict `N<số>`; `N<số>-a` = phần đầu, chấm gộp khi xong.
/// Gate: `RUN_G290_R2SUB`.
final class Genius290QuotaRound2SubUITests: XCTestCase {

    private var app: XCUIApplication!
    private var r2: G290R2!
    private let env = ProcessInfo.processInfo.environment

    override func setUpWithError() throws {
        try XCTSkipUnless(env["RUN_G290_R2SUB"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_R2SUB=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        r2 = G290R2(app: app, tc: self)
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
    }

    private var dialog481: Bool { app.staticTexts["Daily limit reached"].exists }
    private func q(_ st: [String: String]) -> Int { Int(st["quotaLimit"] ?? "") ?? 20 }
    private func w(_ tag: String) -> (total: Int, topup: Int) {
        let x = G290Q.readWallet(app, tag); return (x.total ?? -1, x.topup ?? -1)
    }

    /// Mua gói từ nút Upgrade/Get Pro ở Home (sandbox tự xác nhận). Trả về rời paywall chưa.
    private func buyPlan(_ plan: String, _ tag: String) -> Bool {
        G290Q.showHomeHeader(app)
        guard app.buttons["home-upgrade-cta"].exists else { return false }
        app.buttons["home-upgrade-cta"].tap()
        guard r2.i2i.waitUntil(timeout: 10, { self.r2.i2i.paywall.exists }) else { return false }
        G290.pause(app, 3); snap("\(tag) — paywall trước khi mua \(plan)")
        let p = G290.anyLabeled(app, plan)
        if p.exists { p.tap(); G290.pause(app, 1) }
        G290Q.tapBuyCTA(app)
        let left = G290.waitUntil(app, timeout: 300) {
            self.r2.confirmStoreSheet()
            _ = SystemPermissionAlertHandler.tapButton("OK", timeout: 1)
            return !self.r2.i2i.paywall.exists
        }
        G290.pause(app, 4); _ = SystemPermissionAlertHandler.tapButton("OK", timeout: 2)
        snap("\(tag) — sau khi mua \(plan)")
        G290Q.backToTabs(app, 5)
        return left
    }

    private func genOnce(_ tag: String, attempt: Int) -> String {
        guard r2.readyToGenerate(attempt: attempt) else { return "upload-fail" }
        r2.tapGenerate()
        _ = r2.i2i.waitUntil(timeout: 8) { self.dialog481 || self.r2.i2i.paywall.exists || self.r2.screenKind() != "upload" }
        if dialog481 { snap("\(tag) — 481"); G290.anyLabeled(app, "Maybe later").tap(); G290Q.backToTabs(app, 5); return "481" }
        let o = r2.waitGenerateOutcome()
        print("GEN|\(tag)|\(o)")
        return o
    }

    /// Gói sandbox Yearly chỉ sống ~1h: máy về free thì mua lại Yearly từ Home trước khi chạy case cần gói.
    private func ensureSubscribed() {
        G290Q.showHomeHeader(app)
        guard G290Q.isFree(app) else { return }
        let ok = buyPlan("Yearly", "mua lại Yearly (gói cũ hết hạn)")
        print("ENSURESUB|mua lại Yearly=\(ok)")
    }

    /// Tiền đề "hết 2 ví": còn topup dư (lượt trước mua) thì gen tới khi 413 = 0 (tối đa 25 lượt).
    private func spendToZero(_ tag: String) -> (total: Int, topup: Int) {
        var x = w("\(tag)-trước")
        var n = 0
        while x.total > 0, n < 25 { n += 1; _ = genOnce("\(tag)-tiêu-\(n)", attempt: 160 + n); x = w("\(tag)-\(n)") }
        return x
    }

    // MARK: - S01 free 0/0 mua Weekly từ Home — N013 · N001 · N121-a · N116-a

    func test01_buyWeeklyFromHome() {
        let w0 = w("s01-trước")
        guard G290Q.isFree(app) else { G290.verdict("N013", "NA", "máy đang có gói"); return }
        let left = buyPlan("Weekly", "N013")
        let st = r2.debugState("s01-sau mua"), Q = q(st)
        let h = r2.header("N013 + N001 — header sau khi mua Weekly")
        let w1 = w("s01-sau")
        let quotaNow = w1.total - max(w1.topup, 0)
        let info = "Q(quotaLimit)=\(Q) · tier=\(st["tier"] ?? "?") · latestPurchase=\(st["latestPurchase"] ?? "?") · productId=\(st["productId"] ?? "?") · ví trước \(w0.total)/topup \(w0.topup)"
        G290.verdict("N013", pass: left && !h.upgrade && h.badge == Q && quotaNow == Q,
                     "mua Weekly rời paywall=\(left) · nút Upgrade/Get Pro còn=\(h.upgrade) · badge=\(h.badge.map(String.init) ?? "ẩn") · 413=\(w1.total) (quota \(quotaNow), topup \(w1.topup)) · \(info)")
        G290.verdict("N001", pass: !h.upgrade && h.badge == Q && w1.topup == 0, "subscriber còn lượt: badge=\(h.badge.map(String.init) ?? "ẩn") (Q=\(Q)) · nút Upgrade/Get Pro=\(h.upgrade) · topup=\(w1.topup)")
        G290.verdict("N121-a", pass: w1.total == Q && st["tier"]?.contains("credit") == true, "sub cũ (22/10) đã hết hạn, mua lại Weekly hôm nay: 413=\(w1.total) · \(info)")
        G290.verdict("N116-a", pass: !h.upgrade && h.badge == Q && w1.total == Q, "RC grandfather = hôm nay: header badge=\(h.badge.map(String.init) ?? "ẩn") · Upgrade=\(h.upgrade) · 413=\(w1.total) · \(info)")
    }

    // MARK: - S02 N098 gen 1 rồi chờ Weekly hết hạn thật

    func test02_genOneThenWaitExpiry() {
        let o = genOnce("N098-gen", attempt: 20)
        let w1 = w("s02-sau gen")
        var st = r2.debugState("s02-chờ-0"), waited = 0
        while st["isActive"] == "true", waited < 45 {
            Thread.sleep(forTimeInterval: 180); waited += 3
            st = r2.debugState("s02-chờ-\(waited)")
        }
        let expired = st["isActive"] != "true"
        let w2 = w("s02-sau hết hạn")
        guard r2.readyUpload(attempt: 21) else { G290.verdict("N098", "NA", "không vào Upload"); return }
        let chain = r2.runChain("N098", stopAt: "paywall")
        while r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
        G290.verdict("N098", pass: expired && w2.total == 0 && chain.first?.hasPrefix("paywall") == true,
                     "gen=\(o) → 413 \(w1.total) · chờ \(waited)′ hết hạn=\(expired) (isActive=\(st["isActive"] ?? "?")) · 413 sau hết hạn=\(w2.total) · Generate: \(chain.joined(separator: " → "))")
    }

    // MARK: - S03 mua Yearly (gói sống lâu cho phần còn lại)

    func test03_buyYearly() {
        // Còn Weekly thì Home không có nút Upgrade → chờ gói hết hạn thật (tối đa 30′), đo N098 lúc đó.
        let before = w("s03-trước")
        var waited = 0
        while !G290Q.isFree(app), waited < 30 {
            Thread.sleep(forTimeInterval: 60); waited += 1
            app.activate(); G290Q.showHomeHeader(app)
        }
        if waited > 0 || G290Q.isFree(app) {
            let st = r2.debugState("N098 sau hết hạn")
            let after = w("s03-sau hết hạn")
            var chain: [String] = []
            if r2.readyUpload(attempt: 22) { chain = r2.runChain("N098", stopAt: "paywall") }
            while r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
            G290Q.backToTabs(app, 5)
            G290.verdict("N098", pass: st["isActive"] != "true" && after.total == 0 && chain.first?.hasPrefix("paywall") == true,
                         "Weekly còn quota \(before.total) (topup \(before.topup)) · chờ \(waited)′ tới hết hạn (isActive=\(st["isActive"] ?? "?"), expiration=\(st["expiration"] ?? "?")) · 413 sau hết hạn=\(after.total) · Generate: \(chain.joined(separator: " → "))")
        }
        let left = buyPlan("Yearly", "s03")
        let st = r2.debugState("s03-sau mua Yearly")
        let x = w("s03")
        print("S03|rời paywall=\(left)|413=\(x.total)|topup=\(x.topup)|tier=\(st["tier"] ?? "?")|productId=\(st["productId"] ?? "?")")
    }

    // MARK: - S04 build B (grandfather = ngày mai) — N006 · N022 · N117-a · N123-b

    func test04_grandfatherState() {
        ensureSubscribed()
        let st = r2.debugState("s04-grandfather")
        let h = r2.header("N006 + N117 — header grandfather")
        // Grandfather: Setting ẩn hàng My Balance (SettingsView.swift:84) → ghi lại thay vì dừng test.
        var t: [String] = [], unlimited = false, getMore = false, rowHidden = false
        if G290Q.openMyBalanceFromSetting(app) {
            G290.pause(app, 3)
            t = G290.visibleTexts(app); unlimited = t.contains { $0.localizedCaseInsensitiveContains("Unlimited") }
            getMore = G290.anyLabeled(app, "Get More").exists
            snap("N022 — 413 grandfather")
        } else {
            rowHidden = !app.staticTexts["My Balance"].exists
            snap("N022 — Setting của grandfather (không có My Balance)")
            t = ["Setting không có hàng My Balance=\(rowHidden)"]
        }
        G290Q.backToTabs(app)
        let info = "RC=\(st["quota_grandfather_until"] ?? "?") · tier=\(st["tier"] ?? "?") · isUnlimitedGen=\(st["isUnlimitedGen"] ?? "?") · latestPurchase=\(st["latestPurchase"] ?? "?")"
        G290.verdict("N006", pass: h.badge == nil && !h.upgrade, "badge=\(h.badge.map(String.init) ?? "ẩn") · Upgrade/Get Pro=\(h.upgrade) · \(info)")
        G290.verdict("N022", pass: unlimited && getMore, "413: 'Unlimited'=\(unlimited) · Get More=\(getMore) · chữ: \(t.prefix(8).joined(separator: " · ")) · \(info)")
        G290.verdict("N117-a", pass: h.badge == nil && !h.upgrade && unlimited, "header badge=\(h.badge.map(String.init) ?? "ẩn") · Upgrade=\(h.upgrade) · 413 Unlimited=\(unlimited) · \(info)")
        G290.verdict("N123-b", "CHECK", "ngày tương lai: \(info) · activeProviders=\(st["activeProviders"] ?? "?") · hasActiveSub=\(st["hasActiveSub"] ?? "?")")
    }

    // MARK: - S05 build A (hôm nay) — N118 · N123-a, rồi gen 2 lượt (tiền đề N119, bắt đầu N167)

    func test05_todayStateThenGenTwo() {
        let st = r2.debugState("s05-hôm nay"), Q = q(st)
        let x = w("s05")
        G290.verdict("N118", pass: x.total == Q + max(x.topup, 0) && st["tier"]?.contains("credit") == true,
                     "đổi RC ngày mai → hôm nay, kill + mở lại: 413=\(x.total) (Q=\(Q), topup \(x.topup)) · tier=\(st["tier"] ?? "?") · RC=\(st["quota_grandfather_until"] ?? "?")")
        G290.verdict("N123-a", "CHECK", "ngày hôm nay: tier=\(st["tier"] ?? "?") · activeProviders=\(st["activeProviders"] ?? "?") · hasActiveSub=\(st["hasActiveSub"] ?? "?") · quotaEnforced=\(st["quotaEnforced"] ?? "?")")
        var badges: [String] = ["\(r2.header("N167 — badge đầu ngày").badge.map(String.init) ?? "ẩn")"]
        for i in 1...2 {
            let o = genOnce("N167-\(i)", attempt: 30 + i)
            badges.append("\(o):\(r2.header("N167 — badge sau gen \(i)").badge.map(String.init) ?? "ẩn")")
        }
        let y = w("s05-sau 2 gen")
        print("N167BADGE|\(badges.joined(separator: ","))")
        G290.verdict("N119-pre", pass: y.total == x.total - 2, "gen 2 lần ở build hôm nay: 413 \(x.total) → \(y.total) · badge \(badges.joined(separator: " → "))")
    }

    // MARK: - S06 build B — N119 · N082 · N120 · N063 · N117-b: gen Q+1 lần không bị chặn

    func test06_grandfatherGenBeyondQ() {
        ensureSubscribed()
        func dbg(_ tag: String) -> (st: [String: String], total: Int, topup: Int) {
            let st = r2.debugState(tag)
            return (st, Int(st["quota.total"] ?? "") ?? -1, Int(st["quota.topup"] ?? "") ?? -1)
        }
        let d0 = dbg("s06-grandfather"), Q = q(d0.st)
        let unlimited = d0.st["isUnlimitedGen"] == "true"
        // Grandfather không có hàng My Balance (SettingsView.swift:84) → không có đường mua topup chủ động.
        let oks: [Bool] = []
        let d1 = d0
        var outs: [String] = [], n481 = 0
        for i in 1...(Q + 1) {
            let o = genOnce("N063-\(i)", attempt: 40 + i)
            outs.append(o); if o == "481" { n481 += 1; break }
            if o == "upload-fail" || o == "timeout" { if outs.filter({ $0 == o }).count >= 3 { break } }
        }
        let h = r2.header("N082 — header grandfather sau \(outs.count) lần gen")
        let d2 = dbg("s06-sau gen")
        let ok = outs.filter { $0 == "result" }.count
        let summary = "\(ok)/\(outs.count) lượt result, 481=\(n481) · ví (Debug quota.total/topup) \(d0.total)/\(d0.topup) → sau thử mua \(d1.total)/\(d1.topup) → sau gen \(d2.total)/\(d2.topup) · tier=\(d0.st["tier"] ?? "?") · isUnlimitedGen=\(unlimited)"
        G290.verdict("N119", pass: unlimited && n481 == 0 && ok >= Q + 1, "đổi RC sang ngày mai → grandfather: \(summary) · 413: Setting ẩn My Balance với grandfather (SettingsView.swift:84) nên không thấy 'Unlimited'")
        G290.verdict("N063", pass: n481 == 0 && ok >= Q + 1, "grandfather gen > Q: \(summary)")
        G290.verdict("N117-b", pass: n481 == 0 && ok >= Q + 1, "lần Q+1 không 481: \(summary)")
        G290.verdict("N082", pass: h.badge == nil && n481 == 0 && ok >= 3,
                     "badge=\(h.badge.map(String.init) ?? "ẩn") · gen không giới hạn · mua topup chủ động=\(oks.isEmpty ? "không có đường (My Balance ẩn)" : "\(oks)") · \(summary)")
        G290.verdict("N120", pass: d2.total == d1.total && d2.topup == d1.topup, "grandfather gen không trừ ví: \(summary) (HOLD phía BE: không thấy từ app)")
    }

    // MARK: - S07 build A — N048 · N049 · N050 · N100: kill app giữa lúc gen, BE tự hoàn sau 10′

    func test07_killMidGenRefund() {
        let x0 = w("s07-trước")
        guard r2.readyUpload(attempt: 70) else { G290.verdict("N050", "NA", "không vào Upload"); return }
        r2.i2i.tap(r2.i2i.generateButton)
        let gen = r2.i2i.waitUntil(timeout: 20) { self.r2.screenKind() == "generating" }
        snap("N050 — đang Generating, sắp kill app")
        let killedAt = Date()
        app.terminate()
        Thread.sleep(forTimeInterval: 8 * 60 + 30)
        app.launch(); _ = G290.reachMain(app)
        let x9 = w("s07-sau 8′30″")
        let t9 = Int(Date().timeIntervalSince(killedAt))
        app.terminate()
        Thread.sleep(forTimeInterval: max(0, 11 * 60 - Double(Date().timeIntervalSince(killedAt))))
        app.launch()
        var toast = ""
        _ = G290.waitUntil(app, timeout: 20) {
            if let t = G290.visibleTexts(self.app).first(where: { $0.range(of: "Restored|restored|refund", options: .regularExpression) != nil }) { toast = t; self.snap("N100 — toast 483"); return true }
            return false
        }
        _ = G290.reachMain(app)
        let x11 = w("s07-sau 11′")
        let base = "ví trước \(x0.total) · đang gen=\(gen) · kill → \(t9)s mở lại: \(x9.total) · 11′: \(x11.total) · toast='\(toast.isEmpty ? "không thấy" : toast)'"
        G290.verdict("N049", pass: x9.total == x0.total - 1, "chưa đủ 10′ chưa hoàn: \(base)")
        G290.verdict("N050", pass: x11.total == x0.total, "kill giữa gen → hoàn sau 10′: \(base)")
        G290.verdict("N048", pass: x11.total == x0.total && !toast.isEmpty, "hold treo → auto-release + toast lần mở kế tiếp: \(base)")
        G290.verdict("N100", pass: !toast.isEmpty, "toast 483: \(base) (spec copy: xem Expected)")
    }

    // MARK: - S08 build A — N167 · N003 · N116-b · N121-b · N138: tiêu hết Q → 481 → mua → gen tiếp

    func test08_exhaustQuotaThenBuy() {
        let st = r2.debugState("s08"), Q = q(st)
        var x = w("s08-trước"), outs: [String] = [], badges: [String] = []
        var n = 0
        while x.total > 0, n < Q + 2 {
            n += 1
            let o = genOnce("N167-tiêu-\(n)", attempt: 80 + n); outs.append(o)
            badges.append(r2.header("N167 — badge sau tiêu \(n)").badge.map(String.init) ?? "ẩn")
            if o == "481" { break }
            x.total -= 1
            if n % 5 == 0 { x = w("s08-\(n)") }
        }
        x = w("s08-hết")
        let h = r2.header("N003 — header subscriber hết 2 ví")
        G290.verdict("N003", pass: x.total == 0 && h.badge == nil && !h.upgrade, "hết 2 ví: 413=\(x.total) · badge=\(h.badge.map(String.init) ?? "ẩn") · Upgrade/Get Pro=\(h.upgrade)")
        guard r2.readyUpload(attempt: 99) else { return }
        r2.i2i.tap(r2.i2i.generateButton)
        let got481 = r2.i2i.waitUntil(timeout: 10) { self.dialog481 }
        snap("N167 — 481 lần Q+1")
        G290.anyLabeled(app, "Get more").tap(); G290.pause(app, 4)
        if G290Q.onTopupScreen(app) { G290.anyLabeled(app, "Purchase").tap() } else { G290Q.tapBuyCTA(app) }
        G290.pause(app, 12)
        if r2.i2i.paywall.exists { G290Q.tapBuyCTA(app) }
        _ = G290.waitUntil(app, timeout: 300) { self.r2.confirmStoreSheet(); _ = SystemPermissionAlertHandler.tapButton("OK", timeout: 1); return !self.r2.i2i.paywall.exists && !G290Q.onTopupScreen(self.app) }
        let resumed = r2.i2i.waitUntil(timeout: 150) { self.r2.screenKind() == "result" }
        snap("N167 — gen tự chạy tiếp sau mua")
        _ = r2.waitGenerateOutcome(timeout: 5)
        let y = w("s08-sau mua")
        let s = "Q=\(Q) · \(n) lượt tiêu: \(outs.joined(separator: ",")) · badge: \(badges.joined(separator: "→")) · lần Q+1: 481=\(got481) · mua → gen tự chạy=\(resumed) · 413 sau=\(y.total)"
        G290.verdict("N167", pass: got481 && resumed && y.total == 0 && badges.dropLast().allSatisfy { $0 != "ẩn" }, s)
        G290.verdict("N116-b", pass: got481, "lần Q+1 hiện 481: \(s)")
        G290.verdict("N121-b", pass: got481, "lần Q+1 hiện 481: \(s)")
        G290.verdict("N138", "CHECK", "phía app: chặn ở lần Q+1 với Q=\(Q) từ BE (quotaLimit) · phía BE (ngưỡng CMS): cần BE xác nhận · \(s)")
    }

    // MARK: - S09 N078 mua xong kill app trước khi gen chạy tiếp

    func test09_buyThenKillBeforeResume() {
        ensureSubscribed()
        let x0 = spendToZero("s09")
        guard x0.total == 0, r2.readyToGenerate(attempt: 120) else { G290.verdict("N078", "NA", "cần hết 2 ví (đang \(x0.total))"); return }
        r2.tapGenerate()
        guard r2.i2i.waitUntil(timeout: 10, { self.dialog481 }) else { G290.verdict("N078", "NA", "không thấy 481"); return }
        G290.anyLabeled(app, "Get more").tap()
        var killed = false
        r2.buyOnTopupOffer("N078") { self.snap("N078 — mua xong, kill ngay"); self.app.terminate(); killed = true }
        app.launch(); _ = G290.reachMain(app)
        let x1 = w("s09-mở lại")
        G290.openTab(app, "Home")
        let restored = r2.screenKind() == "upload" || r2.screenKind() == "generating"
        snap("N078 — mở lại app")
        G290.verdict("N078", pass: killed && x1.total == 1 && !restored, "kill sau mua=\(killed) · 413 mở lại=\(x1.total) · flow gen dở được khôi phục=\(restored)")
    }

    // MARK: - S10 RC rỗng / sai định dạng (build C/D) — N125 · N144

    func test10_rcGrandfatherInvalid() {
        ensureSubscribed()
        let tag = env["R2_RC_CASE"] ?? "?"
        let st = r2.debugState("s10-\(tag)")
        let x = w("s10-\(tag)")
        let o = genOnce("s10-\(tag)", attempt: 130)
        let o2 = o == "result" ? genOnce("s10-\(tag)-2", attempt: 131) : "-"
        G290.verdict(tag == "empty" ? "N125" : "N144-\(tag)", "CHECK",
                     "RC ép='\(tag)' · giá trị app đang dùng=\(st["quota_grandfather_until"] ?? "?") · tier=\(st["tier"] ?? "?") · isUnlimitedGen=\(st["isUnlimitedGen"] ?? "?") · 413=\(x.total) · gen: \(o), \(o2)")
    }
    // MARK: - S11 N131 gỡ app cài lại — App User ID (Keychain) không đổi. Queue gỡ app giữa 2 lượt.

    func test11_appUserIdAcrossReinstall() {
        let id = r2.debugState("N131")["appUserID"] ?? "?"
        print("APPUSERID|\(id)")
        guard let prev = env["R2_PREV_ID"], !prev.isEmpty else { return }
        G290.verdict("N131", pass: id == prev && id != "?", "App User ID trước gỡ app=\(prev) · sau cài lại=\(id) (deviceId lưu Keychain — GetDeviceIdProvider.swift:8–21)")
    }

    // MARK: - S12 N172 gen video (Seedance) trừ 1 lượt, không còn UI credit cũ

    func test12_seedanceVideoGen() {
        ensureSubscribed()
        let x0 = w("s12-trước")
        let i2v = I2VJourneyDriver(app: app)
        guard i2v.enterVideoUploadAnyRoute() else { G290.verdict("N172", "NA", "không vào được Upload video (I2V)"); return }
        _ = i2v.openPicker(); _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4)
        guard PhotoPickerAutomator.pickPhoto(attempt: 140, in: app), i2v.waitUntil(timeout: 15, { i2v.isGenerateReady() }) else {
            G290.verdict("N172", "NA", "không chọn được ảnh cho I2V"); return
        }
        let creditUI = G290.visibleTexts(app).filter { $0.localizedCaseInsensitiveContains("credit") }
        snap("N172 — Upload video trước khi gen")
        i2v.generateButton.tap()
        let done = i2v.waitUntil(timeout: 300) { i2v.resultScreen.exists || i2v.generatingFailed.exists }
        let resultOK = i2v.resultScreen.exists
        snap("N172 — kết quả gen video")
        G290Q.backToTabs(app, 5)
        let x1 = w("s12-sau")
        G290.verdict("N172", pass: resultOK && x1.total == x0.total - 1 && creditUI.isEmpty,
                     "gen video xong=\(done) (result=\(resultOK)) · 413 \(x0.total) → \(x1.total) · chữ 'credit' ở màn upload: \(creditUI.isEmpty ? "không" : creditUI.joined(separator: " / "))")
    }
    // MARK: - S13 N167-b: hết 2 ví → 481 → Get more → mua → gen tự chạy tiếp → 413 = 0

    func test13_buyFrom481Resume() {
        ensureSubscribed()
        let x0 = spendToZero("s13")
        guard x0.total == 0, r2.readyToGenerate(attempt: 150) else { G290.verdict("N167-b", "NA", "cần hết 2 ví (đang \(x0.total))"); return }
        r2.tapGenerate()
        let got481 = r2.i2i.waitUntil(timeout: 10) { self.dialog481 }
        snap("N167 — 481 trước khi mua")
        G290.anyLabeled(app, "Get more").tap()
        let bought = r2.buyOnTopupOffer("N167-b")
        snap("N167 — sau khi mua từ 481")
        let resumed = r2.continueEnhanceAfterPurchase()
        snap("N167 — gen tự chạy tiếp")
        _ = r2.waitGenerateOutcome(timeout: 5)
        let x1 = w("s13-sau")
        G290.verdict("N167-b", pass: got481 && bought && resumed && x1.total == 0,
                     "hết 2 ví: 481=\(got481) · mua từ 481 xong=\(bought) · gen tự chạy tiếp với lượt vừa mua=\(resumed) · 413 sau=\(x1.total)")
    }
    // MARK: - Smoke: gen 1 lượt qua Enhance + đọc ví (khi Home lỗi server)

    func test15_smokeEnhanceGen() {
        let x0 = w("smoke-trước")
        let o = genOnce("smoke-enhance", attempt: 170)
        let x1 = w("smoke-sau")
        print("SMOKEENH|gen=\(o)|413 \(x0.total)/\(x0.topup) → \(x1.total)/\(x1.topup)")
    }
}
