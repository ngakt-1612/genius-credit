import XCTest

/// Daily Quota & Topup (IIP055.1.16) vòng 2 — bản TC sửa 24/10 (N° mới, verdict `N<số>`).
/// Phần user KHÔNG gói (sub cũ đã hết hạn / chưa mua). Gate: `RUN_G290_R2`.
final class Genius290QuotaRound2UITests: XCTestCase {

    private var app: XCUIApplication!
    private var r2: G290R2!
    private let env = ProcessInfo.processInfo.environment

    override func setUpWithError() throws {
        try XCTSkipUnless(env["RUN_G290_R2"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_R2=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        r2 = G290R2(app: app, tc: self)
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
    }

    func test00_debugState() { _ = r2.debugState("probe") }

    /// Smoke: vào Upload i2i + đọc Debug Sub state — chạy trước khi mở chuỗi dài.
    func test11_smokeUploadAndDebug() {
        let ok = r2.readyUpload(attempt: 1)
        snap("smoke — Upload i2i")
        print("SMOKE|upload=\(ok)")
        r2.i2i.leaveUpload()
        let st = r2.debugState("smoke")
        print("SMOKE|debug=\(st.count) key|tier=\(st["tier"] ?? "?")|appUserID=\(st["appUserID"] ?? "?")")
    }

    /// Tìm thẻ style ảnh (mở Upload i2i) trong feed Home: chạm lần lượt từng thẻ có tên, cuộn dần.
    func test10_findI2IStyle() {
        var tried = Set<String>()
        for chip in ["Trending", "New"] {
            for depth in 0..<8 {
                r2.goHomeTab(chip, scrolls: depth)
                let labels = r2.visibleCardLabels().filter { !tried.contains("\(chip)/\($0)") }
                for lbl in labels.prefix(3) {
                    tried.insert("\(chip)/\(lbl)")
                    r2.goHomeTab(chip, scrolls: depth)
                    guard r2.tapCard(lbl) else { continue }
                    G290.pause(app, 5)
                    let kind = r2.i2i.generateButton.exists ? "i2i" : r2.i2i.paywall.exists ? "paywall" : G290.visibleTexts(app).contains("Tap to use") ? "reel" : "khác:\(G290.visibleTexts(app).prefix(4).joined(separator: ","))"
                    print("FINDI2I|\(chip)|depth=\(depth)|\(lbl)|\(kind)")
                    if kind == "i2i" { snap("i2i style '\(lbl)'"); print("I2ISTYLE|\(chip)|\(depth)|\(lbl)"); return }
                    if r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
                    G290Q.backToTabs(app, 4)
                }
            }
        }
        print("I2ISTYLE|không thấy|đã thử \(tried.count) thẻ")
    }

    /// Dò tab feed Home (CMS đổi theo ngày): mỗi tab liệt kê thẻ + chạm thẻ đầu xem mở màn nào.
    func test09_probeHomeTabs() {
        for chip in ["Trending", "New", "Motion"] {
            G290.openTab(app, "Home"); G290Q.showHomeHeader(app)
            let c = G290.anyLabeled(app, chip)
            guard c.exists else { print("HOMETAB|\(chip)|không thấy"); continue }
            c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); G290.pause(app, 3)
            let cards = app.buttons.matching(identifier: "home-style-card").allElementsBoundByIndex.filter { $0.exists }
            print("HOMETAB|\(chip)|\(cards.count) card|" + cards.prefix(8).map { "\($0.label)@\(Int($0.frame.minY))" }.joined(separator: " · "))
            snap("probe tab \(chip)")
            for (i, card) in cards.prefix(3).enumerated() where card.isHittable {
                card.tap(); G290.pause(app, 4)
                print("HOMETAB|\(chip)|chạm thẻ \(i)='\(card.label)' → generate=\(r2.i2i.generateButton.exists) · paywall=\(r2.i2i.paywall.exists) · \(G290.visibleTexts(app).prefix(6).joined(separator: " · "))")
                snap("probe tab \(chip) thẻ \(i)")
                if r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
                G290Q.backToTabs(app, 4); G290.openTab(app, "Home"); c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); G290.pause(app, 2)
            }
        }
    }

    // MARK: - N012 / N005 / N097 — sub đã hết hạn, còn 2 topup

    func test01_expiredSubWithTopup() {
        var w = G290Q.readWallet(app, "r2-f01-trước")
        if let t = w.topup, t < 2 {
            _ = r2.buyPull("r2-f01", times: 2 - t)
            w = G290Q.readWallet(app, "r2-f01-sau mua")
        }
        let st = r2.debugState("N012")
        let h = r2.header("N012 + N005 — header sub hết hạn, topup \(w.topup ?? -1)")
        let headerOK = h.badge == nil && h.upgrade
        let pre = "tier=\(st["tier"] ?? "?") · apple isActive=\(st["isActive"] ?? "?") · topup=\(w.topup.map(String.init) ?? "?")"
        G290.verdict("N012", pass: headerOK, "sub hết hạn còn topup: badge=\(h.badge.map(String.init) ?? "ẩn") · nút Upgrade/Get Pro=\(h.upgrade) ('\(h.upgradeLabel)') · \(pre)")
        G290.verdict("N005", pass: headerOK, "user không gói có topup: badge=\(h.badge.map(String.init) ?? "ẩn") · nút Upgrade/Get Pro=\(h.upgrade) · \(pre) (user từng có sub, đã hết hạn)")

        guard r2.readyUpload(attempt: 1) else { G290.verdict("N097", "NA", "không vào được Upload i2i"); return }
        let before = w.topup ?? -1
        let chain = r2.runChain("N097", closeUntilGen: true)
        let gen = r2.waitGenerateOutcome()
        let after = G290Q.readWallet(app, "r2-f01-sau gen").topup ?? -1
        let sawPaywall = chain.contains { $0.hasPrefix("paywall") }, sawLast = chain.contains { $0.hasPrefix("lastchance") }
        let sawTopup = chain.contains { $0.hasPrefix("topup") }, saw481 = chain.contains { $0.hasPrefix("481") } || gen == "481"
        G290.verdict("N097", pass: sawPaywall && sawLast && !sawTopup && !saw481 && gen == "result" && after == before - 1,
                     "chuỗi: \(chain.joined(separator: " → ")) · gen=\(gen) · topup \(before) → \(after)")
    }

    // MARK: - Tiêu hết topup → free 0/0

    func test02_spendTopupToZero() {
        var t = G290Q.readWallet(app, "r2-f02").topup ?? 0, n = 0
        while t > 0, n < 6 {
            n += 1
            guard r2.readyUpload(attempt: 10 + n) else { break }
            _ = r2.runChain("spend-\(n)", closeUntilGen: true)
            print("SPEND|\(n)|\(r2.waitGenerateOutcome())")
            t = G290Q.readWallet(app, "r2-f02-\(n)").topup ?? 0
        }
        print("SPEND|xong|topup=\(t)")
    }

    // MARK: - N004 free 0 topup — header

    func test03_freeNoTopupHeader() {
        let w = G290Q.readWallet(app, "r2-f03")
        let h = r2.header("N004 — header free không topup")
        let sparkle = G290.visibleTexts(app).contains { $0.contains("Pro ✨") || $0.contains("✨") }
        G290.verdict("N004", pass: h.badge == nil && h.upgrade && !sparkle && w.topup == 0,
                     "badge=\(h.badge.map(String.init) ?? "ẩn") · nút Upgrade/Get Pro=\(h.upgrade) ('\(h.upgradeLabel)') · chữ 'Pro ✨'=\(sparkle) · topup=\(w.topup.map(String.init) ?? "?")")
    }

    // MARK: - N095 offline — chặn trước chuỗi paywall

    func test04_offlineBlocksBeforeChain() {
        guard r2.readyUpload(attempt: 2) else { G290.verdict("N095", "NA", "không vào được Upload i2i"); return }
        let net = SettingsNetworkDriver { self.app }
        defer { print("🌐 trả mạng = \(net.ensureOn())") }
        guard net.setAirplaneMode(true) else { G290.verdict("N095", "NA", "không bật được Airplane Mode"); return }
        app.activate(); G290.pause(app, 3)
        r2.i2i.tap(r2.i2i.generateButton)
        var msg = "", paywall = false
        _ = G290.waitUntil(app, timeout: 6) {        // toast tắt sau ~3s → đọc liên tục
            paywall = paywall || self.r2.i2i.paywall.exists
            if let t = G290.visibleTexts(self.app).first(where: { $0.range(of: "internet|network|connection", options: [.regularExpression, .caseInsensitive]) != nil }) { msg = t; self.snap("N095 — offline bấm Generate (free)") }
            return false
        }
        G290.verdict("N095", pass: !msg.isEmpty && !paywall, "offline bấm Generate: thông báo='\(msg.isEmpty ? "không thấy" : msg)' · paywall/Last-chance/topup mở=\(paywall)")
        if r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2); r2.i2i.dismissPaywall() }
    }

    // MARK: - N087 Enhance — chuỗi paywall free

    func test05_enhanceChain() {
        // Tiền đề free 0/0: máy còn gói thì không có chuỗi bán → bỏ lượt (queue thử lại sau).
        G290Q.showHomeHeader(app)
        guard G290Q.isFree(app) else { print("N087_SKIP|máy đang có gói"); return }
        G290.openTab(app, "Create"); G290.pause(app, 2)
        let el = G290.anyLabeled(app, "Enhance Photo")
        guard el.exists else { G290.verdict("N087", "NA", "không thấy Enhance ở Create"); return }
        el.tap(); G290.pause(app, 4)
        if !r2.i2i.paywall.exists {
            // Màn Enhance: chọn ảnh qua nút "Gallery" (chạm khung "Tap to upload photo" không mở picker).
            let gallery = G290.anyLabeled(app, "Gallery")
            if gallery.exists { gallery.tap(); G290.pause(app, 2); _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4); _ = PhotoPickerAutomator.pickPhoto(attempt: 3, in: app); G290.pause(app, 3) }
            snap("N087 — Enhance sau chọn ảnh")
            let analyze = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Analyze Photo")).firstMatch
            _ = G290.waitUntil(app, timeout: 15) { analyze.exists && analyze.isEnabled }
            print("ENHANCE_CTA|Analyze Photo enabled=\(analyze.isEnabled)")
            if analyze.exists { analyze.tap() }
            _ = G290.waitUntil(app, timeout: 30) { self.r2.i2i.paywall.exists }
        }
        var chain = r2.closeChain("N087")
        // Đóng paywall gói → app có thể chạy tiếp bước phân tích ảnh: chờ xong rồi ghi tiếp chuỗi.
        if G290.visibleTexts(app).contains(where: { $0.contains("Scanning Photo") || $0.contains("Analyzing") }) {
            _ = G290.waitUntil(app, timeout: 90) { self.r2.i2i.paywall.exists || !G290.visibleTexts(self.app).contains { $0.contains("Analyzing") } }
            G290.pause(app, 3)
            chain.append("sau phân tích: \(r2.screenKind()) · \(G290.visibleTexts(app).prefix(6).joined(separator: " · "))")
            snap("N087 — sau bước phân tích ảnh")
            for b in ["Apply All Suggestions", "Enhance", "Enhance Photo", "Generate"] where !r2.i2i.paywall.exists {
                let el = app.buttons.matching(NSPredicate(format: "label == %@", b)).allElementsBoundByIndex.last
                if let el, el.exists, el.isEnabled { el.tap(); G290.pause(app, 4); chain.append("bấm \(b): \(r2.screenKind())"); break }
            }
            if r2.i2i.paywall.exists { chain += r2.closeChain("N087-sau phân tích") }
        }
        let iLast = chain.firstIndex { $0.hasPrefix("lastchance") }, iTop = chain.firstIndex { $0.hasPrefix("topup") }
        G290.verdict("N087", pass: iLast != nil && iTop != nil && iLast! < iTop!, "chuỗi Enhance: \(chain.joined(separator: " → "))")
        if r2.i2i.paywall.exists { r2.i2i.dismissPaywall() }
        G290Q.backToTabs(app, 5)
    }

    // MARK: - N093 kill app khi đang ở màn topup offer

    func test06_killAtTopupOffer() {
        guard r2.readyUpload(attempt: 4) else { G290.verdict("N093", "NA", "không vào được Upload i2i"); return }
        let first = r2.runChain("N093-lần1", stopAt: "topup")
        guard first.last?.hasPrefix("topup") == true else {
            G290.verdict("N093", "NA", "lần 1 không tới màn topup offer: \(first.joined(separator: " → "))"); return
        }
        app.terminate(); G290.pause(app, 2); app.launch()
        XCTAssertTrue(G290.reachMain(app))
        guard r2.readyUpload(attempt: 5) else { G290.verdict("N093", "NA", "mở lại: không vào được Upload i2i"); return }
        let second = r2.runChain("N093-mở lại", stopAt: "topup")
        G290.verdict("N093", pass: second.contains { $0.hasPrefix("topup") },
                     "lần 1: \(first.joined(separator: " → ")) · kill app · mở lại: \(second.joined(separator: " → "))")
        while r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
    }

    // MARK: - N143 / N148 `topup_offer_max_per_day` ép trong code (app vừa cài lại → bộ đếm offer = 0)

    func test07_offerMaxPerDay() {
        let rc = env["R2_RC_CASE"] ?? "?"
        let id = rc == "2" ? "N148" : "N143-\(rc)"
        let st = r2.debugState("\(id) RC")
        var shown: [Bool] = []
        for i in 1...3 {
            guard r2.readyUpload(attempt: 50 + i) else { break }
            let chain = r2.runChain("\(id)-lần\(i)", stopAt: "topup")
            let top = chain.contains { $0.hasPrefix("topup") }
            shown.append(top)
            if top { let no = G290.anyLabeled(app, "No, thanks"); if no.exists { no.tap() } else { r2.i2i.dismissPaywall() }; G290.pause(app, 2) }
            while r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
            G290Q.backToTabs(app, 5)
        }
        let s = "RC ép topup_offer_max_per_day='\(rc)' · enable_topup=\(st["enable_topup"] ?? "?") · offer hiện lần 1/2/3 = \(shown.map { $0 ? "có" : "không" }.joined(separator: "/"))"
        if rc == "2" {
            G290.verdict("N148", pass: shown == [true, true, false], s)
        } else {
            // Default trong code = 1 (RemoteConfigKeys.swift:220): chỉ lần 1 có offer.
            G290.verdict("N143-\(rc)", pass: shown == [true, false, false], s + " · default code = 1")
        }
    }

    // MARK: - N147 `enable_topup = false` (ép trong code) — 413 Get More + chuỗi free

    func test08_enableTopupOff() {
        let st = r2.debugState("N147 RC")
        var getMore = false
        if G290Q.openMyBalanceFromSetting(app) { getMore = G290.anyLabeled(app, "Get More").exists; snap("N147 — 413 khi enable_topup=false"); G290Q.backToTabs(app) }
        var chain: [String] = []
        if r2.readyUpload(attempt: 60) { chain = r2.runChain("N147-free", stopAt: "topup") }
        while r2.i2i.paywall.exists { r2.i2i.dismissPaywall(); G290.pause(app, 2) }
        G290Q.backToTabs(app, 5)
        G290.verdict("N147", "CHECK", "enable_topup=\(st["enable_topup"] ?? "?") · 413 Get More=\(getMore) · chuỗi free: \(chain.joined(separator: " → ")) · (481 'Mua thêm' của subscriber: chạy ở phần sub) — Expected TC còn mơ hồ ('xử lý thế nào khi tắt topup')")
    }
}
