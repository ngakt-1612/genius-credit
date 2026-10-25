import XCTest

/// Daily Quota vòng 2 — trừ lượt trên từng tab còn dùng được khi Home lỗi server (25/10):
/// tab Create (Enhance · Restore · Remove Object · Try On) và tab Chat. Mỗi công cụ: đọc 413 →
/// tạo 1 lần → đọc lại 413; ghi `N035` (Remove Object) và `N034-<tool>` (đếm phẳng mọi feature).
/// Gate: `RUN_G290_R2SUB` (cần gói + còn lượt).
final class Genius290QuotaDeductPerToolUITests: XCTestCase {

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

    private func at(_ f: CGRect) { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap() }
    private func total(_ tag: String) -> Int { G290Q.readWallet(app, tag).total ?? -1 }
    private var looksLikeResult: Bool {
        app.buttons["Save"].exists || G290.visibleTexts(app).contains { $0 == "Before" || $0 == "After" || $0 == "Edit More" }
    }

    /// Bấm nút hành động ở nửa dưới màn theo thứ tự ưu tiên — đọc từ MỘT snapshot (màn đổi giữa chừng).
    private func tapAction(_ labels: [String]) -> String? {
        guard let root = try? app.snapshot() else { return nil }
        var found: [(String, CGRect)] = [], stack: [XCUIElementSnapshot] = [root]
        while let n = stack.popLast() {
            if (n.elementType == .button || n.elementType == .staticText), n.isEnabled, !n.frame.isEmpty, n.frame.minY > 450 { found.append((n.label, n.frame)) }
            stack.append(contentsOf: n.children)
        }
        for l in labels { if let hit = found.first(where: { $0.0 == l || $0.0.hasPrefix(l) }) { at(hit.1); return hit.0 } }
        return nil
    }

    /// Tab Create → thẻ công cụ → chọn ảnh → đi các nút hành động tới màn kết quả (tối đa 180 s).
    private func runTool(_ card: String, actions: [String]) -> (ok: Bool, note: String) {
        G290Q.backToTabs(app, 5)
        G290.openTab(app, "Create"); G290.pause(app, 2)
        guard let c = app.buttons.allElementsBoundByIndex.first(where: { $0.exists && $0.label.hasPrefix(card) }) else { return (false, "không thấy thẻ \(card)") }
        at(c.frame); G290.pause(app, 3)
        let pick = G290.anyLabeled(app, "Gallery").exists ? G290.anyLabeled(app, "Gallery") : G290.anyLabeled(app, "Tap to upload")
        if pick.exists { pick.tap(); G290.pause(app, 2) }
        _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4)
        guard PhotoPickerAutomator.pickPhoto(attempt: 7, in: app) else { return (false, "chọn ảnh không xong") }
        G290.pause(app, 3)
        var tapped: [String] = [], painted = false
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline && !looksLikeResult {
            if r2.i2i.paywall.exists { return (false, "ra màn mua sau \(tapped)") }
            if app.staticTexts["Daily limit reached"].exists { return (false, "hiện 481 sau \(tapped)") }
            if !painted, G290.anyLabeled(app, "Brush").exists {
                // Remove Object: chọn Brush rồi tô một vệt ngang giữa ảnh làm vùng cần xoá.
                G290.anyLabeled(app, "Brush").tap(); G290.pause(app, 1)
                let o = app.coordinate(withNormalizedOffset: .zero)
                o.withOffset(CGVector(dx: 140, dy: 380)).press(forDuration: 0.1, thenDragTo: o.withOffset(CGVector(dx: 250, dy: 400)), withVelocity: .slow, thenHoldForDuration: 0.1)
                painted = true; G290.pause(app, 1)
            }
            if let t = tapAction(actions) { tapped.append(t); G290.pause(app, 4) } else { G290.pause(app, 3) }
            if tapped.count > 8 { break }
        }
        let ok = looksLikeResult
        snap("\(card) — kết quả")
        G290Q.backToTabs(app, 5)
        return (ok, "bấm \(tapped)")
    }

    private func measure(_ id: String, _ card: String, _ actions: [String]) {
        let before = total("\(card)-trước")
        let r = runTool(card, actions: actions)
        let after = total("\(card)-sau")
        G290.verdict(id, pass: r.ok && before >= 0 && after == before - 1,
                     "\(card): tạo xong=\(r.ok) (\(r.note)) · 413 \(before) → \(after) (spec −1 lượt)")
    }

    func test01_enhance() { measure("N034-enhance", "Enhance", ["Next", "Analyze Photo", "Apply All Suggestions", "Apply Suggestions", "Enhance"]) }
    func test02_restore() { measure("N034-restore", "Restore", ["Restore"]) }
    func test03_removeObject() { measure("N035", "Remove Object", ["Next", "Remove"]) }
    func test04_tryOn() { measure("N034-tryon", "Try", ["Try On", "Try on", "Generate", "Continue", "Next"]) }

    /// Tab Chat: gửi 1 yêu cầu tạo ảnh → chờ ô kết quả (hàng Save · Share · Regenerate) → đọc lại 413.
    func test05_chat() {
        let before = total("chat-trước")
        G290.openTab(app, "Chat"); G290.pause(app, 2)
        if app.buttons["More"].exists, !app.staticTexts["What's on your mind?"].exists {
            app.buttons["More"].tap(); G290.pause(app, 1)
            if app.buttons["New conversation"].exists { app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 2) }
        }
        let fields = app.textFields.allElementsBoundByIndex.filter { $0.exists }
        let input = fields.first { $0.frame.minX >= 50 } ?? app.textFields.firstMatch
        let regen = { self.app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).count }
        let base = regen()
        for _ in 0..<4 where app.keyboards.count == 0 { input.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap(); _ = app.keyboards.firstMatch.waitForExistence(timeout: 2) }
        input.typeText("a cat wearing a wizard hat, watercolor style")
        let send = app.images["arrow.up"].firstMatch
        if send.exists { at(send.frame) }
        let done = G290.waitUntil(app, timeout: 220) {
            regen() > base || G290.visibleTexts(self.app).contains { $0.contains("Couldn") || $0.contains("longer than expected") }
        }
        let ok = regen() > base
        snap("Chat — kết quả")
        G290Q.backToTabs(app, 5)
        let after = total("chat-sau")
        G290.verdict("N034-chat", pass: ok && before >= 0 && after == before - 1,
                     "Chat: có kết quả=\(ok) (xong=\(done)) · 413 \(before) → \(after) (spec −1 lượt)")
    }
}
