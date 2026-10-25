import XCTest

/// Helper chung cho suite Daily Quota vòng 2: chuỗi chào bán, chờ kết quả gen, header Home,
/// mua topup chủ động, đọc màn Debug "Sub state" (tier, RC, ví) để chấm thay vì đoán.
final class G290R2 {

    let app: XCUIApplication
    let i2i: I2IJourneyDriver
    private weak var tc: XCTestCase?

    init(app: XCUIApplication, tc: XCTestCase) {
        self.app = app
        self.i2i = I2IJourneyDriver(app: app)
        self.tc = tc
    }

    private func texts() -> [String] { G290.visibleTexts(app) }
    private func joined(_ n: Int = 8) -> String { texts().prefix(n).joined(separator: " · ") }
    private var resultScreen: XCUIElement { app.descendants(matching: .any).matching(identifier: "i2i-result-screen").firstMatch }

    // MARK: - Feed Home (Trending / New / Motion) — CMS 24/10 không còn tab For You

    /// Về Home, chọn chip tab feed rồi cuộn `scrolls` nhịp. Chip là StaticText không hittable → chạm toạ độ.
    func goHomeTab(_ chip: String, scrolls: Int) {
        G290Q.backToTabs(app, 4)
        G290.openTab(app, "Home"); G290Q.showHomeHeader(app)
        let c = G290.anyLabeled(app, chip)
        if c.exists { c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); G290.pause(app, 2) }
        for _ in 0..<scrolls { i2i.scrollHomeShort() }
    }

    /// Tên các thẻ style đang nằm trong vùng chạm được (bỏ thẻ không tên / sau thanh tab).
    func visibleCardLabels() -> [String] {
        app.buttons.matching(identifier: "home-style-card").allElementsBoundByIndex
            .filter { $0.exists && !$0.label.isEmpty && $0.frame.minY > 150 && $0.frame.maxY < 1600 && $0.isHittable }
            .map(\.label)
    }

    func tapCard(_ label: String) -> Bool {
        let card = app.buttons.matching(NSPredicate(format: "identifier == 'home-style-card' AND label == %@", label)).firstMatch
        guard card.exists, card.isHittable else { return false }
        card.tap(); return true
    }

    /// Thẻ style ảnh đã dò ra (env `R2_I2I_STYLE` = "chip|số nhịp cuộn|tên thẻ").
    private var knownI2IStyle: (chip: String, scrolls: Int, label: String)? {
        let p = (ProcessInfo.processInfo.environment["R2_I2I_STYLE"] ?? "").components(separatedBy: "|")
        guard p.count == 3, let n = Int(p[1]) else { return nil }
        return (p[0], n, p[2])
    }

    /// Vào Upload i2i. Feed có Personalized Ranking nên thứ tự thẻ đổi giữa các lần mở app:
    /// cuộn dần tìm đúng tên thẻ ảnh đã biết; không thấy thì chạm lần lượt thẻ chưa thử tới khi gặp
    /// thẻ mở Upload i2i (thẻ Motion mở tab Reel → về Home thử thẻ khác).
    private func enterI2IUpload() -> Bool {
        let chips = [knownI2IStyle?.chip ?? "Trending", "New"]
        if let k = knownI2IStyle {
            goHomeTab(k.chip, scrolls: 0)
            for _ in 0..<12 {
                if tapCard(k.label) {
                    if i2i.generateButton.waitForExistence(timeout: 12) { return true }
                    if i2i.paywall.exists { i2i.dismissPaywall(); G290.pause(app, 2) }
                    break
                }
                i2i.scrollHomeShort()
            }
            print("   ⚠️ không thấy thẻ i2i '\(k.label)' — dò thẻ ảnh khác")
        }
        var tried = Set<String>()
        for chip in chips {
            for depth in 0..<10 {
                goHomeTab(chip, scrolls: depth)
                for lbl in visibleCardLabels() where !tried.contains(lbl) {
                    tried.insert(lbl)
                    guard tapCard(lbl) else { continue }
                    if i2i.generateButton.waitForExistence(timeout: 6) { print("I2ISTYLE|\(chip)|\(depth)|\(lbl)"); return true }
                    if i2i.paywall.exists { i2i.dismissPaywall(); G290.pause(app, 2) }
                    goHomeTab(chip, scrolls: depth)
                }
            }
        }
        return false
    }

    // MARK: - Gen qua Enhance (tab Create) — dùng khi Home lỗi server (env R2_GEN_VIA=enhance)

    var viaEnhance: Bool { ProcessInfo.processInfo.environment["R2_GEN_VIA"] == "enhance" }
    /// Nút "Apply All Suggestions" — nhãn có thể nằm ở StaticText con thay vì Button → tìm mọi loại phần tử.
    private var applyButton: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Apply All Suggestions")).firstMatch
    }

    /// Create → Enhance Photo → Gallery → chọn ảnh → Analyze Photo → chờ màn "Suggested Enhancements".
    /// Free user: Analyze mở paywall gói — đóng thì app vẫn phân tích tiếp.
    func openEnhanceToApply(attempt: Int) -> Bool {
        G290Q.backToTabs(app, 5)
        G290.openTab(app, "Create"); G290.pause(app, 2)
        let tool = G290.anyLabeled(app, "Enhance Photo")
        guard tool.exists else { return false }
        tool.tap(); G290.pause(app, 3)
        let gallery = G290.anyLabeled(app, "Gallery")
        guard gallery.exists else { return false }
        gallery.tap(); G290.pause(app, 2)
        _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4)
        guard PhotoPickerAutomator.pickPhoto(attempt: attempt, in: app) else { return false }
        let analyze = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Analyze Photo")).firstMatch
        _ = G290.waitUntil(app, timeout: 15) { analyze.exists && analyze.isEnabled }
        analyze.tap()
        _ = G290.waitUntil(app, timeout: 90) {
            if self.i2i.paywall.exists { self.i2i.dismissPaywall(); G290.pause(self.app, 2) }
            return self.applyButton.exists || self.dialog481
        }
        // Hết 2 ví: Enhance chặn bằng 481 ngay ở bước Analyze — coi như đã tới cổng gen.
        if dialog481 { print("ENHANCE_481_AT_ANALYZE"); return true }
        if !applyButton.exists {
            print("ENHANCE_STUCK|\(G290.visibleTexts(app).prefix(12).joined(separator: " · "))")
            tc?.snap("Enhance — không tới được Apply")
        }
        return applyButton.exists
    }

    /// Vào màn sẵn sàng gen (i2i Upload hoặc Enhance "Apply") theo `R2_GEN_VIA`.
    func readyToGenerate(attempt: Int) -> Bool { viaEnhance ? openEnhanceToApply(attempt: attempt) : readyUpload(attempt: attempt) }

    /// Bấm nút gen của luồng đang đứng.
    var dialog481: Bool { app.staticTexts["Daily limit reached"].exists }

    /// Sau khi mua từ 481 ở Enhance: app phân tích tiếp → bấm Apply nếu nút hiện (tới khi ra kết quả).
    func continueEnhanceAfterPurchase(timeout: TimeInterval = 150) -> Bool {
        G290.waitUntil(app, timeout: timeout) {
            if self.viaEnhance, self.applyButton.exists { self.applyButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); G290.pause(self.app, 3) }
            return self.screenKind() == "result"
        }
    }

    func tapGenerate() {
        if viaEnhance && dialog481 { return }        // 481 đã hiện ở bước Analyze
        if viaEnhance { applyButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() } else { i2i.tap(i2i.generateButton) }
    }

    /// Vào Upload i2i (1 ảnh), chọn ảnh tới khi Generate sẵn sàng.
    func readyUpload(attempt: Int) -> Bool {
        guard enterI2IUpload() else { return false }
        // Style có thể cần 1–3 ảnh: điền lần lượt từng ô "Upload Image N" còn trống.
        for i in 0..<3 {
            i2i.openPicker(); _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4)
            guard PhotoPickerAutomator.pickPhoto(attempt: attempt + i, in: app) else { return false }
            G290.pause(app, 2)
            if i2i.emptySlotCount() == 0 { break }
        }
        return i2i.waitUntil(timeout: 15) { self.i2i.isGenerateReady() }
    }

    /// Màn đang đứng: paywall | lastchance | topup | 481 | upload | generating | result | khác.
    func screenKind() -> String {
        let t = texts(), s = t.joined(separator: " ")
        if i2i.paywall.exists {
            if s.range(of: "Still not ready|One-time|one-time|1 AI creation|Just want", options: .regularExpression) != nil
                && s.range(of: "Weekly|Yearly|/week|/year", options: .regularExpression) == nil { return "topup" }
            if s.range(of: "Limited|OFF|Last chance|last chance", options: .regularExpression) != nil { return "lastchance" }
            return "paywall"
        }
        if t.contains("Daily limit reached") { return "481" }
        if resultScreen.exists { return "result" }
        if t.contains("Edit More") && t.contains("Save") { return "result" }          // Enhance Result
        if t.contains("Try Again") && t.contains("Go Back") { return "failed" }
        if app.descendants(matching: .any).matching(identifier: "i2i-generating-screen").firstMatch.exists
            || s.contains("Building your visual") || s.contains("Creating your masterpiece") { return "generating" }
        if i2i.generateButton.exists { return "upload" }
        return "khác"
    }

    /// Ghi màn hiện tại rồi đóng lần lượt các màn bán (tối đa 4) — dừng sớm khi gặp `stopAt`.
    func closeChain(_ tag: String, stopAt: String? = nil) -> [String] {
        var steps = ["\(screenKind()): \(joined())"]
        tc?.snap("\(tag) — màn đầu chuỗi")
        for i in 0..<4 where i2i.paywall.exists {
            if let stop = stopAt, steps.last?.hasPrefix(stop) == true { break }
            i2i.dismissPaywall(); G290.pause(app, 3)
            steps.append("\(screenKind()): \(joined())")
            tc?.snap("\(tag) — sau lần đóng \(i + 1)")
        }
        print("PAYWALLCHAIN|\(tag)|\(steps.joined(separator: " → "))")
        return steps
    }

    /// Bấm Generate rồi đi chuỗi chào bán.
    func runChain(_ tag: String, closeUntilGen: Bool = true, stopAt: String? = nil) -> [String] {
        i2i.tap(i2i.generateButton)
        _ = i2i.waitUntil(timeout: 10) { self.screenKind() != "upload" }
        G290.pause(app, 2)
        return closeChain(tag, stopAt: stopAt)
    }

    /// Chờ lượt gen kết thúc → result | 481 | paywall | timeout. Đóng màn kết quả về Home.
    func waitGenerateOutcome(timeout: TimeInterval = 150) -> String {
        var out = "timeout"
        _ = i2i.waitUntil(timeout: timeout) {
            switch self.screenKind() {
            case "result": out = "result"; return true
            case "failed": out = "failed"; return true
            case "481": out = "481"; return true
            case "paywall", "lastchance", "topup": out = "paywall"; return true
            default: return false
            }
        }
        tc?.snap("kết thúc gen — \(out)")
        if out == "result" { i2i.tap(app.buttons["i2i-result-close"]); G290.pause(app, 2) }
        if out == "481" { G290.anyLabeled(app, "Maybe later").tap(); G290.pause(app, 1) }
        G290Q.backToTabs(app, 5)
        return out
    }

    /// Sheet Apple "In-App Purchase" của sandbox (mua gói sub) nằm trong cây AX của app: nút
    /// `footer` = "Subscribe" / "Purchase". Mua topup thì sandbox tự xác nhận, không có sheet.
    @discardableResult
    func confirmStoreSheet() -> Bool {
        for label in ["Subscribe", "Purchase", "Buy", "Confirm"] {
            let b = app.buttons.matching(NSPredicate(format: "identifier == 'footer' AND label == %@", label)).firstMatch
            if b.exists, b.isHittable { b.tap(); print("STORESHEET|\(label)"); return true }
        }
        return false
    }

    /// Màn topup offer (paywall RevenueCat "Get 1 creation" / màn 214 "Purchase"): cú chạm đầu ngay khi
    /// màn vừa mở hay bị nuốt (đã gặp 22/10 & 24/10) → chạm lại tối đa 3 lần, bấm sheet Apple nếu có.
    /// `onBought` chạy ngay khi màn bán đóng (vd kill app cho N078). Trả về đã rời màn bán chưa.
    @discardableResult
    func buyOnTopupOffer(_ tag: String, onBought: (() -> Void)? = nil) -> Bool {
        G290.pause(app, 3)
        for attempt in 1...3 {
            let offer = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Get 1 creation")).firstMatch
            if offer.exists { offer.tap() } else if G290Q.onTopupScreen(app) { G290.anyLabeled(app, "Purchase").tap() }
            print("TOPUPOFFER_TAP|\(tag)|lần \(attempt)")
            let left = G290.waitUntil(app, timeout: 30) {
                self.confirmStoreSheet()
                _ = SystemPermissionAlertHandler.tapButton("OK", timeout: 1)
                return !self.i2i.paywall.exists && !G290Q.onTopupScreen(self.app)
            }
            if left { onBought?(); return true }
        }
        tc?.snap("\(tag) — vẫn ở màn bán sau 3 lần chạm")
        return false
    }

    /// Header Home: badge số (nil = ẩn) + nút Upgrade/Get Pro (`home-upgrade-cta`, nhãn "Pro").
    func header(_ shot: String) -> (badge: Int?, upgrade: Bool, upgradeLabel: String) {
        G290Q.showHomeHeader(app)
        let cta = app.buttons["home-upgrade-cta"]
        tc?.snap(shot)
        return (G290Q.homeBadge(app), cta.exists, cta.exists ? cta.label : "")
    }

    /// Setting → My Balance → Get More → Purchase, `times` lần (sandbox tự xác nhận).
    @discardableResult
    func buyPull(_ tag: String, times: Int = 1) -> [Bool] {
        guard times > 0, G290Q.openMyBalanceFromSetting(app) else { return [] }
        var oks: [Bool] = []
        for i in 1...times {
            G290.anyLabeled(app, "Get More").tap(); G290.pause(app, 4)
            oks.append(G290Q.purchaseOnTopupScreen(app, "\(tag)-\(i)").ok)
            if G290Q.onTopupScreen(app) { G290Q.tapBack(app) }
            _ = app.staticTexts["Today's available creations"].waitForExistence(timeout: 8)
        }
        G290Q.backToTabs(app)
        return oks
    }

    /// Setting → Debug "Sub state": đọc cặp nhãn → giá trị (tier, isActive, latestPurchase, RC…).
    func debugState(_ tag: String) -> [String: String] {
        let labels = ["isPremium", "tier", "isActive", "latestPurchase", "productId", "expiration", "hasActiveSub",
                      "activeProviders", "quota.daily", "quota.topup", "quota.total", "quotaEnforced", "isUnlimitedGen",
                      "quotaLimit", "enable_topup", "quota_grandfather_until", "appUserID", "App User ID"]
        var found: [String: String] = [:]
        guard G290Q.openSetting(app) else { print("DEBUGSTATE|\(tag)|không mở được Setting"); return found }
        app.swipeUp(); G290.pause(app, 1)
        // Hàng trong Setting hay nuốt chạm đầu → chạm lại tới khi sheet Debug hiện (tối đa 3 lần).
        let opened = { G290.visibleTexts(self.app).contains { $0.contains("EntitlementStore") || $0 == "isPremium" } }
        for i in 0..<3 where !opened() {
            let btn = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sub state")).firstMatch
            let row = btn.exists ? btn : G290.anyLabeled(app, "Sub state")
            if row.exists { i == 0 ? row.tap() : row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).press(forDuration: 0.15) }
            G290.pause(app, 4)
        }
        guard opened() else {
            if let tc { G290Q.dump(app, "\(tag)-subState-fail", tc) }
            print("DEBUGSTATE|\(tag)|không mở được Sub state"); G290Q.backToTabs(app, 5); return found
        }
        for page in 0..<8 {
            let t = texts()
            print("DEBUGRAW|\(tag)|\(page)|\(t.joined(separator: " ¦ "))")
            for (i, s) in t.enumerated() where labels.contains(s) && i + 1 < t.count && found[s] == nil { found[s] = t[i + 1].replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "❌ ", with: "") }
            tc?.snap("\(tag) — Debug Sub state \(page + 1)")
            app.swipeUp(); G290.pause(app, 1)
        }
        print("DEBUGSTATE|\(tag)|" + found.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "|"))
        app.swipeDown(velocity: .fast); G290.pause(app, 1); app.swipeDown(velocity: .fast); G290.pause(app, 1)
        G290Q.backToTabs(app, 5)
        return found
    }
}
