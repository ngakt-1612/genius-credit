import XCTest

/// Helper cho suite Daily Quota & Topup (spec IIP055.1.16): đọc badge Home, 413 My Balance, màn topup.
/// Mọi số đọc lại từ cây accessibility rồi mới in `VERDICT` / `WALLET|…`.
enum G290Q {

    /// Dump cây accessibility (0 credit) — dòng `DUMP|tag|type|label|id|value|frame|enabled`.
    static func dump(_ app: XCUIApplication, _ tag: String, _ tc: XCTestCase) {
        guard let root = try? app.snapshot() else { return }
        var stack: [XCUIElementSnapshot] = [root], lines: [String] = []
        while let n = stack.popLast() {
            let v = (n.value as? String) ?? ""
            if !n.frame.isEmpty, n.frame.minY < 900, !(n.label.isEmpty && n.identifier.isEmpty && v.isEmpty) {
                lines.append("\(n.elementType.rawValue)|\(n.label)|\(n.identifier)|\(v.prefix(40))|\(Int(n.frame.minX)),\(Int(n.frame.minY)),\(Int(n.frame.width))x\(Int(n.frame.height))|\(n.isEnabled ? 1 : 0)")
            }
            stack.append(contentsOf: n.children.reversed())
        }
        print("DUMP|\(tag)|\(lines.count) element")
        lines.prefix(160).forEach { print("DUMP|\(tag)|\($0)") }
        tc.snap("probe — \(tag)")
    }

    /// Về Home, cuộn lên đầu để header hiện đủ.
    static func showHomeHeader(_ app: XCUIApplication) {
        G290.openTab(app, "Home"); app.swipeDown(); app.swipeDown(); G290.pause(app, 2)
    }

    /// Nút Upgrade chỉ có với user không gói (`HomeView` · `home-upgrade-cta`).
    static func isFree(_ app: XCUIApplication) -> Bool { app.buttons["home-upgrade-cta"].exists }

    /// Badge số lượt trên header Home: button ở góc phải trên, label là con số. nil = badge ẩn.
    static func homeBadge(_ app: XCUIApplication) -> Int? {
        guard let root = try? app.snapshot() else { return nil }
        var stack: [XCUIElementSnapshot] = [root]
        while let n = stack.popLast() {
            if n.elementType == .button, n.frame.minY < 120, n.frame.minX > 150,
               n.label.range(of: #"^\d+$"#, options: .regularExpression) != nil { return Int(n.label) }
            stack.append(contentsOf: n.children.reversed())
        }
        return nil
    }

    /// Setting (nút bánh răng trên header Home) → hàng "My Balance" → 413. Chạm lần đầu hay bị nuốt.
    static func openSetting(_ app: XCUIApplication) -> Bool {
        showHomeHeader(app)
        guard app.buttons["Setting"].firstMatch.waitForExistence(timeout: 6) else { return false }
        app.buttons["Setting"].firstMatch.tap()
        return app.staticTexts["Rate us"].waitForExistence(timeout: 8)
    }

    static func openMyBalanceFromSetting(_ app: XCUIApplication) -> Bool {
        guard openSetting(app) else { return false }
        G290.pause(app, 2)
        let row = app.staticTexts["My Balance"].firstMatch
        for _ in 0..<3 where app.staticTexts["Rate us"].exists { if row.exists { row.tap() }; G290.pause(app, 3) }
        return app.staticTexts["Today's available creations"].waitForExistence(timeout: 10)
    }

    /// Số trên thẻ 413 (chờ hết spinner).
    static func myBalanceNumber(_ app: XCUIApplication) -> Int? {
        _ = G290.waitUntil(app, timeout: 20) { numericText(app) != nil }
        return numericText(app)
    }

    static func numericText(_ app: XCUIApplication) -> Int? {
        G290.visibleTexts(app).first { $0.range(of: #"^\d+$"#, options: .regularExpression) != nil }.flatMap { Int($0) }
    }

    /// Số trên banner màn topup: "<N> topup creations".
    static func topupNumber(_ app: XCUIApplication) -> Int? {
        _ = G290.waitUntil(app, timeout: 15) { G290.visibleTexts(app).contains { $0.hasSuffix("topup creations") } }
        let t = G290.visibleTexts(app).first { $0.hasSuffix("topup creations") } ?? ""
        return Int(t.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
    }

    /// Nút back trên header các màn push (không id): button góc trái trên.
    static func tapBack(_ app: XCUIApplication) {
        if let b = app.buttons.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX < 70 && $0.frame.minY > 30 && $0.frame.minY < 140 }) {
            b.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)).press(forDuration: 0.1,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        }
        G290.pause(app, 1.5)
    }

    /// Về luồng chính (thanh tab hiện) bằng back tối đa `n` lần.
    static func backToTabs(_ app: XCUIApplication, _ n: Int = 4) {
        for _ in 0..<n where app.tabBars.buttons.count == 0 { tapBack(app) }
    }

    /// Ví hiện tại: tổng (413), topup (màn topup), quota = tổng − topup. In `WALLET|…`.
    @discardableResult
    static func readWallet(_ app: XCUIApplication, _ tag: String) -> (total: Int?, topup: Int?, free: Bool) {
        let free = { showHomeHeader(app); return isFree(app) }()
        let badge = homeBadge(app)
        guard openMyBalanceFromSetting(app) else { print("WALLET|\(tag)|không mở được 413"); return (nil, nil, free) }
        let total = myBalanceNumber(app)
        G290.anyLabeled(app, "Get More").tap(); G290.pause(app, 3)
        let topup = topupNumber(app)
        let quota = (total != nil && topup != nil) ? "\(total! - topup!)" : "?"
        print("WALLET|\(tag)|free=\(free)|badge=\(badge.map(String.init) ?? "ẩn")|413=\(total.map(String.init) ?? "?")|topup=\(topup.map(String.init) ?? "?")|quota=\(quota)")
        backToTabs(app)
        return (total, topup, free)
    }
}

extension G290Q {

    /// Launch có ghi event sink (`~/Documents/<sink>`, kéo về bằng `devicectl copy from`).
    static func launchWithSink(_ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["EVENT_SINK_PATH"] = "~/Documents/\(name)"
        G290RemoteConfigOverride.apply(to: app)
        app.launch()
        print("ETSINK|\(name)")
        return app
    }

    static func step(_ label: String) { print("ETSTEP|\(label)|\(Int64(Date().timeIntervalSince1970 * 1000))") }

    static func onTopupScreen(_ app: XCUIApplication) -> Bool { app.staticTexts["Top-up creations"].exists }

    /// Ở màn topup: bấm Purchase (`taps` lần liên tiếp), chờ tester xác nhận / huỷ trên sheet Apple.
    /// Thành công = app tự pop về 413 hoặc số topup tăng. Huỷ = vẫn ở màn topup, nút Back hiện lại.
    static func purchaseOnTopupScreen(_ app: XCUIApplication, _ tag: String, taps: Int = 1, expectCancel: Bool = false) -> (ok: Bool, detail: String) {
        guard onTopupScreen(app) else { return (false, "không ở màn topup") }
        let had = topupNumber(app) ?? -1
        let btn = G290.anyLabeled(app, "Purchase")
        guard btn.waitForExistence(timeout: 10) else { return (false, "không thấy nút Purchase") }
        let c = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: btn.frame.midX, dy: btn.frame.midY))
        print("PURCHASE_WAITING|\(tag)|\(expectCancel ? "bấm CANCEL trên sheet Apple" : "xác nhận mua (Purchase/mật khẩu) trên sheet Apple") — chờ tối đa 300s")
        for _ in 0..<taps { c.tap() }
        G290.pause(app, 4)
        var alertOK = false
        let done = G290.waitUntil(app, timeout: 300) {
            if SystemPermissionAlertHandler.tapButton("OK", timeout: 1) { alertOK = true }
            let back = app.buttons["Back"].exists
            if !onTopupScreen(app) { return true }                       // pop về 413 = mua xong
            if let n = topupNumber(app), n > had { return true }
            return back && expectCancel                                   // nút Back hiện lại = hết lượt mua (huỷ)
        }
        G290.pause(app, 3)
        if SystemPermissionAlertHandler.tapButton("OK", timeout: 2) { alertOK = true }
        let texts = G290.visibleTexts(app).prefix(10).joined(separator: " · ")
        print("TOPUP|\(tag)|done=\(done)|alertOK=\(alertOK)|còn ở màn topup=\(onTopupScreen(app))|\(texts)")
        return (done, "xong=\(done) · popup hệ thống OK=\(alertOK) · sau mua: \(texts)")
    }
}

/// Env runner `RC_OVERRIDE=1` → app đọc Remote Config từ `Documents/genius_remote_config_defaults.json`
/// (script chép file vào container trước khi chạy; xem `RemoteConfigRepositoryImpl.applyLocalOverrideIfRequested`).
enum G290RemoteConfigOverride {
    static func apply(to app: XCUIApplication) {
        guard ProcessInfo.processInfo.environment["RC_OVERRIDE"] == "1" else { return }
        app.launchEnvironment["RC_LOCAL_OVERRIDE_PATH"] = "~/Documents/genius_remote_config_defaults.json"
        print("RCOVERRIDE|on")
    }
}

extension G290Q {
    /// Nút mua chính của paywall RevenueCat (offer topup "Get 1 creation", paywall gói "Continue"…).
    static func tapBuyCTA(_ app: XCUIApplication) {
        for label in ["Get 1 creation", "Continue", "Claim limited time offer", "Subscribe", "Purchase"] {
            let b = G290.anyLabeled(app, label)
            if b.exists, b.frame.minY > 400 { b.tap(); print("BUYCTA|\(label)"); return }
        }
        print("BUYCTA|không thấy nút mua")
    }
}
