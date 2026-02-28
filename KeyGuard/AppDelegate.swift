//
//  AppDelegate.swift
//  KeyGuard
//
//  Created by Mico on 2026/2/23.
//

import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI
import AudioToolbox

// 键盘虚拟键码：Q=12, S=1, 5=23（与 Cmd+Shift+5 系统截图一致）
private let kVK_ANSI_S: Int64 = 1
private let kVK_ANSI_5: Int64 = 23

/// 记录最近按键的时间戳，用于“猫咪护卫”模式
private var lastKeyTimestamps: [Date] = []
private let catGuardThreshold: Double = 0.05 // 50ms 连续按键判定为猫
private let catGuardWindowSize = 8
private var lastCatAlertTime: Date = .distantPast

/// 将 Cmd+Shift+S 转为 Cmd+Shift+5 并投递，以触发系统截图界面
private func postScreenshotShortcut() {
    let modifiers: CGEventFlags = [.maskCommand, .maskShift]
    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_5), keyDown: true) {
        keyDown.flags = modifiers
        keyDown.post(tap: .cghidEventTap)
    }
    if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_5), keyDown: false) {
        keyUp.flags = modifiers
        keyUp.post(tap: .cghidEventTap)
    }
}

/// 全局事件 tap 回调：按用户列表拦截快捷键 / 原 Cmd+Q 开关 / Cmd+Shift+S 映射截图
private func globalKeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    let modifierBits = DisabledShortcut.modifierBits(from: flags)

    // 1. 复古音效 (Retro Clicky)
    if UserDefaults.standard.bool(forKey: AppDelegate.retroClickyKey) {
        // 使用 NSSound 播放 Tink 声音，这是最通用的系统声音之一
        NSSound(named: "Tink")?.play()
    }

    // 2. 猫咪护卫 (Cat Guard)
    if UserDefaults.standard.bool(forKey: AppDelegate.catGuardKey) {
        let now = Date()
        lastKeyTimestamps.append(now)
        if lastKeyTimestamps.count > catGuardWindowSize {
            lastKeyTimestamps.removeFirst()
            if let first = lastKeyTimestamps.first {
                let duration = now.timeIntervalSince(first)
                let avgInterval = duration / Double(catGuardWindowSize)
                if avgInterval < catGuardThreshold {
                    // 判定为猫踩键盘，拦截并弹窗（如果不在冷却期）
                    if now.timeIntervalSince(lastCatAlertTime) > 5.0 {
                        lastCatAlertTime = now
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "🐾 检测到猫咪出没！"
                            alert.informativeText = "检测到极高频率的连击，KeyGuard 已自动拦截后续输入。请确认是否是猫咪踩到了键盘？"
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "好的，我知道了")
                            NSApp.activate(ignoringOtherApps: true)
                            alert.runModal()
                        }
                    }
                    return nil
                }
            }
        }
    } else {
        lastKeyTimestamps.removeAll()
    }

    // 3. 用户配置的「全局禁用」列表
    let disabledList = DisabledShortcut.load()
    for item in disabledList where item.keyCode == keyCode && item.modifierBits == modifierBits {
        return nil
    }

    // 4. 将 Command+Shift+S 映射为 Command+Shift+5（系统截图）
    if keyCode == Int(kVK_ANSI_S) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        if UserDefaults.standard.bool(forKey: AppDelegate.remapCmdShiftSToScreenshotKey) {
            postScreenshotShortcut()
            return nil
        }
    }

    // 5. 海绵宝宝模式 (SpongeBob Mode)
    if UserDefaults.standard.bool(forKey: AppDelegate.spongebobModeKey) {
        // A-Z 的 keyCode 范围大致在 0-50 之间，这里简单判断是否是字母
        let letterKeyCodes: Set<Int> = [0,11,8,2,14,3,5,4,34,38,40,37,46,45,31,35,12,15,1,17,32,9,13,7,16,6]
        if letterKeyCodes.contains(keyCode) && modifierBits == 0 || modifierBits == 2 {
            // 50% 概率翻转 Shift 状态
            if Bool.random() {
                if flags.contains(.maskShift) {
                    event.flags.remove(.maskShift)
                } else {
                    event.flags.insert(.maskShift)
                }
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

/// 用于在开启时全局禁用 Cmd+Q，并控制本应用的 Quit 菜单项
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 供设置界面等直接调用，避免仅靠通知/ delegate 失效时无反应
    static weak var shared: AppDelegate?

    static let blockCommandQKey = "blockCommandQ"
    /// 将 Command+Shift+S 作为截图（与 Command+Shift+5 相同）
    static let remapCmdShiftSToScreenshotKey = "remapCmdShiftSToScreenshot"
    /// 防误触：禁用 ⌘W 关闭窗口、⌘H 隐藏、⌘M 最小化
    static let blockCommandWKey = "blockCommandW"
    static let blockCommandHKey = "blockCommandH"
    static let blockCommandMKey = "blockCommandM"
    /// 运行时不显示在程序坞（开启时使用 .accessory，关闭时使用 .regular，用户仍可通过「保留在程序坞」等系统行为控制）
    static let hideFromDockKey = "KeyGuard_hideFromDock"

    // --- 奇奇怪怪的功能 Key ---
    static let spongebobModeKey = "KeyGuard_spongebobMode"
    static let retroClickyKey = "KeyGuard_retroClicky"
    static let catGuardKey = "KeyGuard_catGuard"

    private var eventTapThread: Thread?
    private var runLoopSource: CFRunLoopSource?
    private var settingsWindow: NSWindow?
    private var inPlaceRecordingMonitor: Any?
    private var inPlaceRecordingOnCancel: (() -> Void)?

    /// 设置里点击「添加快捷键」时发送，避免 SwiftUI 里拿不到 delegate 导致无反应
    static let openShortcutRecorderNotification = Notification.Name("OpenShortcutRecorder")

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        applyQuitMenuItemState()
        startGlobalEventTapIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenShortcutRecorder),
            name: Self.openShortcutRecorderNotification,
            object: nil
        )
        // 启动时弹出设置窗口，与普通应用一致；并应用「是否在程序坞显示」偏好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.openSettingsWindow()
            self?.applyActivationPolicyFromPreference()
        }
        // SwiftUI 可能稍后才生成菜单，延迟再次应用以隐藏「退出 ⌘Q」
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.applyQuitMenuItemState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.applyQuitMenuItemState()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyQuitMenuItemState()
    }

    @objc private func handleOpenShortcutRecorder() {
        DispatchQueue.main.async { [weak self] in
            self?.beginRecordingShortcut { keyCode, modifierBits in
                self?.addShortcutAfterRecord(keyCode: keyCode, modifierBits: modifierBits)
            }
        }
    }

    /// 录制完成后：单键则先确认再添加；否则直接添加；与已知 ⌘Q/⌘W/⌘H/⌘M 同步（列表为唯一来源）
    func addShortcutAfterRecord(keyCode: Int, modifierBits: Int) {
        if DisabledShortcut.shouldWarnWhenAddingSingleKey(keyCode: keyCode, modifierBits: modifierBits) {
            showSingleKeyConfirmAlert(keyCode: keyCode, modifierBits: modifierBits)
        } else {
            performAddShortcut(keyCode: keyCode, modifierBits: modifierBits)
        }
    }

    private func showSingleKeyConfirmAlert(keyCode: Int, modifierBits: Int) {
        let alert = NSAlert()
        alert.messageText = "添加单个字母、数字或空格等按键可能影响输入法与正常输入。"
        alert.informativeText = "是否仍要将该键加入「全局禁用」列表？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "仍要添加")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            performAddShortcut(keyCode: keyCode, modifierBits: modifierBits)
        }
    }

    private func performAddShortcut(keyCode: Int, modifierBits: Int) {
        let store = DisabledShortcutsStore.shared
        store.add(keyCode: keyCode, modifierBits: modifierBits)
        updateQuitMenuItemState()
    }

    /// 点击 Dock 图标时打开设置窗口（与普通应用一致）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return true
    }

    /// 从 SwiftUI 切换开关时调用，更新系统 Quit 菜单项
    func updateQuitMenuItemState() {
        applyQuitMenuItemState()
    }

    /// 从菜单栏打开设置窗口（不依赖 SwiftUI openWindow，保证菜单栏点击能弹出）
    func openSettingsWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let content = SettingsView()
        let hosting = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyGuard — 设置"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    /// 在设置内展开录制：不弹窗，仅用本地 monitor 捕获下一次按键，回调 (keyCode, modifierBits)；取消时调用 onCancel
    func beginRecordingShortcutInPlace(onCapture: @escaping (Int, Int) -> Void, onCancel: @escaping () -> Void) {
        inPlaceRecordingOnCancel = onCancel
        inPlaceRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let modifierBits = DisabledShortcut.modifierBits(from: event.modifierFlags)
            if let m = self?.inPlaceRecordingMonitor { NSEvent.removeMonitor(m); self?.inPlaceRecordingMonitor = nil }
            self?.inPlaceRecordingOnCancel = nil
            DispatchQueue.main.async { onCapture(keyCode, modifierBits) }
            return nil
        }
    }

    func cancelInPlaceRecording() {
        if let m = inPlaceRecordingMonitor { NSEvent.removeMonitor(m); inPlaceRecordingMonitor = nil }
        inPlaceRecordingOnCancel?()
        inPlaceRecordingOnCancel = nil
    }

    /// 弹出「按下要禁用的快捷键」面板（菜单栏/通知仍可用）
    func beginRecordingShortcut(completion: @escaping (Int, Int) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.beginRecordingShortcut(completion: completion) }
            return
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.showRecordingPanel(completion: completion)
        }
    }

    private func showRecordingPanel(completion: @escaping (Int, Int) -> Void) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "添加快捷键"
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.backgroundColor = .windowBackgroundColor
        let label = NSTextField(labelWithString: "请按下要加入「全局禁用」列表的快捷键（可含 ⌘⇧⌥⌃）")
        label.frame = NSRect(x: 24, y: 68, width: 312, height: 28)
        label.alignment = .center
        label.font = .systemFont(ofSize: 14)
        panel.contentView?.addSubview(label)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - panel.frame.width / 2
            let y = frame.midY - panel.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        final class MonitorHolder { var value: Any? }
        final class ObserverHolder { var value: NSObjectProtocol? }
        let holder = MonitorHolder()
        let obHolder = ObserverHolder()
        obHolder.value = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            if let m = holder.value { NSEvent.removeMonitor(m); holder.value = nil }
            if let o = obHolder.value { NotificationCenter.default.removeObserver(o); obHolder.value = nil }
        }
        holder.value = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = Int(event.keyCode)
            let modifierBits = DisabledShortcut.modifierBits(from: event.modifierFlags)
            if let m = holder.value { NSEvent.removeMonitor(m); holder.value = nil }
            if let o = obHolder.value { NotificationCenter.default.removeObserver(o); obHolder.value = nil }
            DispatchQueue.main.async {
                panel.close()
                completion(keyCode, modifierBits)
            }
            return nil
        }
    }

    /// 当前进程是否已获得辅助功能（无障碍）权限
    static func isAccessibilityTrusted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 根据「运行时不显示在程序坞」偏好设置 NSApp 的 activation policy：开启时为 .accessory（不占程序坞），关闭时为 .regular（正常显示，用户可「保留在程序坞」）。
    /// 切换后会将设置窗口重新置前，避免被系统自动关闭或收起到后台。
    func applyActivationPolicyFromPreference() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.applyActivationPolicyFromPreference() }
            return
        }
        let hide = UserDefaults.standard.bool(forKey: Self.hideFromDockKey)
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// 打开「系统设置 - 隐私与安全性 - 辅助功能」。先保持设置窗口显示，在下一个 run loop 再触发辅助功能权限申请。
    func openAccessibilityPreferences() {
        DispatchQueue.main.async {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func startGlobalEventTapIfNeeded() {
        let thread = Thread { [weak self] in
            self?.runGlobalEventTap()
        }
        thread.start()
        eventTapThread = thread
    }

    private func runGlobalEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) as CGEventMask
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalKeyEventTapCallback,
            userInfo: nil
        ) else {
            return // 无辅助功能权限或创建失败
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    private func applyQuitMenuItemState() {
        let block = DisabledShortcutsStore.shared.disablesCommandQ
        if let item = findQuitMenuItem() {
            if block {
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
            } else {
                item.keyEquivalent = "q"
                item.keyEquivalentModifierMask = .command
            }
        }
    }

    private func findQuitMenuItem() -> NSMenuItem? {
        guard let mainMenu = NSApp.mainMenu else { return nil }
        for menuItem in mainMenu.items {
            guard let sub = menuItem.submenu else { continue }
            for item in sub.items {
                if item.action == #selector(NSApplication.terminate(_:)) { return item }
                let title = item.title.lowercased()
                if title == "quit" || title == "退出" || title.hasPrefix("quit ") || title.hasPrefix("退出 ") { return item }
            }
        }
        return nil
    }
}
