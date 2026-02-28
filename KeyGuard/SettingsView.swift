//
//  SettingsView.swift
//  KeyGuard
//
//  Created by Mico on 2026/2/23.
//

import AppKit
import SwiftUI

/// 图标/强调色（用于图标与文字点缀，不用于整块背景）
private enum Accent {
    static let orange = Color(red: 0.85, green: 0.4, blue: 0.2)
    static let teal = Color(red: 0.2, green: 0.55, blue: 0.52)
    static let purple = Color(red: 0.45, green: 0.35, blue: 0.65)
}

/// 整块「卡片」背景与边框，高透明度、与窗口背景过渡自然
private struct CardTheme {
    let isDark: Bool
    var windowBackground: Color { Color(NSColor.windowBackgroundColor) }
    /// 全局禁用卡片：极淡橙调，高透明
    var globalCardBg: Color {
        isDark ? Color(white: 0.16).opacity(0.85) : Color(red: 0.99, green: 0.985, blue: 0.98)
    }
    var globalCardBorder: Color {
        isDark ? Color(white: 0.26).opacity(0.8) : Color(white: 0.9).opacity(0.7)
    }
    /// 功能卡片背景：更透明，仅轻微着色
    func featureCardBg(tint: Tint) -> Color {
        switch tint {
        case .orange:
            return isDark ? Color(white: 0.165).opacity(0.9) : Color(red: 0.995, green: 0.99, blue: 0.98)
        case .teal:
            return isDark ? Color(white: 0.162).opacity(0.9) : Color(red: 0.98, green: 0.995, blue: 0.99)
        case .purple:
            return isDark ? Color(white: 0.164).opacity(0.9) : Color(red: 0.99, green: 0.985, blue: 0.995)
        }
    }
    func featureCardBorder(tint: Tint) -> Color {
        isDark ? Color(white: 0.26).opacity(0.75) : Color(white: 0.88).opacity(0.65)
    }
    /// 列表项/输入区等内嵌块
    var controlBg: Color { Color(NSColor.controlBackgroundColor) }
    enum Tint { case orange, teal, purple }
}

private let hasSeenIntroKey = "KeyGuard_hasSeenIntro"

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(hasSeenIntroKey) private var hasSeenIntro = false
    @AppStorage(AppDelegate.remapCmdShiftSToScreenshotKey) private var remapCmdShiftS = false
    @AppStorage(AppDelegate.hideFromDockKey) private var hideFromDock = false
    @AppStorage(AppDelegate.spongebobModeKey) private var spongebobMode = false
    @AppStorage(AppDelegate.retroClickyKey) private var retroClicky = false
    @AppStorage(AppDelegate.catGuardKey) private var catGuard = false
    @ObservedObject private var disabledShortcuts = DisabledShortcutsStore.shared
    @State private var isRecording = false
    @State private var pendingSingleKey: (keyCode: Int, modifierBits: Int)? = nil
    @State private var showIntroSheet = false
    @State private var showAccessibilityAlert = false
    @State private var isAccessibilityTrusted = false
    private var theme: CardTheme { CardTheme(isDark: colorScheme == .dark) }

    private func refreshAccessibilityTrusted() {
        isAccessibilityTrusted = AppDelegate.isAccessibilityTrusted()
    }

    private func bindingForKnown(_ known: KnownShortcut, accessibilityAlert: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { disabledShortcuts.contains(known.shortcut) },
            set: { newValue in
                if newValue {
                    disabledShortcuts.addKnown(known)
                    if !AppDelegate.isAccessibilityTrusted() {
                        accessibilityAlert.wrappedValue = true
                    }
                } else {
                    disabledShortcuts.removeKnown(known)
                }
                AppDelegate.shared?.updateQuitMenuItemState()
            }
        )
    }

    private var remapCmdShiftSBinding: Binding<Bool> {
        Binding(
            get: { remapCmdShiftS },
            set: { newValue in
                remapCmdShiftS = newValue
                if newValue && !AppDelegate.isAccessibilityTrusted() {
                    showAccessibilityAlert = true
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    globalDisabledCard

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        featureCard(
                            icon: "face.smiling",
                            title: "海绵宝宝模式",
                            description: "开启后，你输入的字母会随机变成大小写混搭（lIkE tHiS），让你的文字自带嘲讽属性。",
                            color: Accent.purple,
                            tint: .purple
                        ) {
                            Toggle("", isOn: $spongebobMode).toggleStyle(.switch)
                        }
                        featureCard(
                            icon: "speaker.wave.2",
                            title: "复古机械音效",
                            description: "为每一次按键添加清脆的点击声，在薄膜键盘上也能找回机械键轴的操作快感。",
                            color: Accent.teal,
                            tint: .teal
                        ) {
                            Toggle("", isOn: $retroClicky).toggleStyle(.switch)
                        }
                        featureCard(
                            icon: "pawprint.fill",
                            title: "猫咪护卫",
                            description: "当检测到极高频率（<50ms）的乱码输入时拦截事件，防止主子踩键盘导致代码被删。",
                            color: Accent.orange,
                            tint: .orange
                        ) {
                            Toggle("", isOn: $catGuard).toggleStyle(.switch)
                        }
                        featureCard(icon: "xmark.circle", title: "禁止 ⌘Q 退出应用", color: Accent.orange, tint: .orange) {
                            Toggle("", isOn: bindingForKnown(.commandQ, accessibilityAlert: $showAccessibilityAlert)).toggleStyle(.switch)
                        }
                        featureCard(icon: "rectangle.compress.vertical", title: "禁止 ⌘W 关闭窗口", color: Accent.teal, tint: .teal) {
                            Toggle("", isOn: bindingForKnown(.commandW, accessibilityAlert: $showAccessibilityAlert)).toggleStyle(.switch)
                        }
                        featureCard(icon: "eye.slash", title: "禁止 ⌘H 隐藏应用", color: Accent.purple, tint: .purple) {
                            Toggle("", isOn: bindingForKnown(.commandH, accessibilityAlert: $showAccessibilityAlert)).toggleStyle(.switch)
                        }
                        featureCard(icon: "minus.rectangle", title: "禁止 ⌘M 最小化窗口", color: Accent.teal, tint: .teal) {
                            Toggle("", isOn: bindingForKnown(.commandM, accessibilityAlert: $showAccessibilityAlert)).toggleStyle(.switch)
                        }
                        featureCard(icon: "camera.viewfinder", title: "将 ⌘⇧S 当作系统截图（同 ⌘⇧5）", color: Accent.orange, tint: .orange) {
                            Toggle("", isOn: remapCmdShiftSBinding).toggleStyle(.switch)
                        }
                        featureCard(icon: "lock.shield.fill", title: "辅助功能权限", color: Accent.orange, tint: .orange) {
                            VStack(alignment: .leading, spacing: 8) {
                                Button("前往「系统设置」授权辅助功能以启用全局拦截") {
                                    AppDelegate.shared?.openAccessibilityPreferences()
                                }
                                .buttonStyle(.bordered)
                                Text(isAccessibilityTrusted ? String(localized: "已开启") : String(localized: "未开启"))
                                    .font(.caption)
                                    .foregroundStyle(isAccessibilityTrusted ? Color.green : Accent.orange)
                            }
                        }
                        featureCard(icon: "dock.rectangle", title: "运行时不显示在程序坞", color: Accent.teal, tint: .teal) {
                            Toggle("", isOn: $hideFromDock)
                                .toggleStyle(.switch)
                                .onChange(of: hideFromDock) { _, _ in
                                    AppDelegate.shared?.applyActivationPolicyFromPreference()
                                }
                        }
                    }
                }
                .padding(28)
            }
            Text("须在「系统设置 → 隐私与安全性 → 辅助功能」中开启本应用，全局拦截才会生效。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
        }
        .frame(minWidth: 520, minHeight: 480)
        .background(theme.windowBackground)
        .onAppear {
            if !hasSeenIntro { showIntroSheet = true }
            refreshAccessibilityTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityTrusted()
        }
        .alert("需要辅助功能权限", isPresented: $showAccessibilityAlert) {
            Button("前往设置") {
                AppDelegate.shared?.openAccessibilityPreferences()
            }
            Button("好的", role: .cancel) { }
        } message: {
            Text("全局拦截需要在「系统设置 → 隐私与安全性 → 辅助功能」中开启本应用。")
        }
        .sheet(isPresented: $showIntroSheet, onDismiss: { hasSeenIntro = true }) {
            IntroWelcomeView(isPresented: $showIntroSheet)
        }
    }

    private var globalDisabledCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.slash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Accent.orange)
                Text("自定义全局禁用快捷键")
                    .font(.headline)
            }
            Text("加入列表的快捷键将在所有应用中失效（系统级拦截）。首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中授权本应用。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(disabledShortcuts.customOnlyList, id: \.self) { shortcut in
                    HStack {
                        Text(shortcut.displayString)
                            .font(.system(size: 13, design: .rounded).weight(.medium))
                            .foregroundStyle(Accent.purple)
                        Spacer()
                        Button { removeShortcut(shortcut) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.controlBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                addShortcutButton
                if isRecording { inPlaceRecordingPrompt }
                if let p = pendingSingleKey { singleKeyConfirmRow(keyCode: p.keyCode, modifierBits: p.modifierBits) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.globalCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.globalCardBorder, lineWidth: 1))
    }

    private var inPlaceRecordingPrompt: some View {
        HStack(spacing: 10) {
            Text("请按下要禁用的快捷键…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("取消") {
                AppDelegate.shared?.cancelInPlaceRecording()
                isRecording = false
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(theme.controlBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func singleKeyConfirmRow(keyCode: Int, modifierBits: Int) -> some View {
        let warningRed = Color(red: 0.7, green: 0.2, blue: 0.2)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(warningRed)
                Text("添加单个字母、数字或空格等按键可能影响输入法与正常输入，请确认是否仍要添加。")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(warningRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Button("仍要添加") {
                    disabledShortcuts.add(keyCode: keyCode, modifierBits: modifierBits)
                    AppDelegate.shared?.updateQuitMenuItemState()
                    pendingSingleKey = nil
                }
                .buttonStyle(.borderedProminent)
                Button("取消") { pendingSingleKey = nil }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warningRed.opacity(colorScheme == .dark ? 0.2 : 0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(warningRed.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func featureCard<C: View>(icon: String, title: LocalizedStringKey, description: LocalizedStringKey? = nil, color: Color, tint: CardTheme.Tint, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    content()
                }
                if let desc = description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.featureCardBg(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.featureCardBorder(tint: tint), lineWidth: 1))
    }

    private var addShortcutButton: some View {
        Button {
            isRecording = true
            AppDelegate.shared?.beginRecordingShortcutInPlace(
                onCapture: { keyCode, modifierBits in
                    if DisabledShortcut.shouldWarnWhenAddingSingleKey(keyCode: keyCode, modifierBits: modifierBits) {
                        pendingSingleKey = (keyCode, modifierBits)
                    } else {
                        disabledShortcuts.add(keyCode: keyCode, modifierBits: modifierBits)
                        AppDelegate.shared?.updateQuitMenuItemState()
                    }
                    isRecording = false
                },
                onCancel: { isRecording = false }
            )
        } label: {
            Label("添加要禁用的快捷键…", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Accent.teal)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isRecording || pendingSingleKey != nil)
    }

    private func removeShortcut(_ shortcut: DisabledShortcut) {
        disabledShortcuts.remove(shortcut)
        AppDelegate.shared?.updateQuitMenuItemState()
    }
}

// MARK: - 首次启动欢迎（两页：下一步 → 知道了）
private struct IntroWelcomeView: View {
    @Binding var isPresented: Bool
    @State private var step: Int = 0
    private let totalSteps = 2

    var body: some View {
        let bg = Color(NSColor.windowBackgroundColor)
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题 + 页码
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.slash.fill")
                        .font(.title2)
                        .foregroundStyle(Accent.orange)
                    Text("欢迎使用 KeyGuard")
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                Text("\(step + 1)/\(totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 28)

            if step == 0 {
                page1Content
            } else {
                page2Content
            }

            Spacer(minLength: 24)
            HStack {
                Spacer()
                if step == 0 {
                    Button("下一步") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("知道了") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .background(bg)
        .frame(minWidth: 400, minHeight: 360)
    }

    private var page1Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本应用的目的")
                .font(.headline)
            Text("防止误触：由于 macos 的某些快捷键会导致工作时频繁的误点击，本应用设计的理念是避免误按 ⌘Q 退出应用、⌘W 关闭窗口、⌘H 隐藏、⌘M 最小化等快捷键，导致工作被打断或未保存内容丢失。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var page2Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用方法")
                .font(.headline)
            Text("在下方设置中开启需要的开关，或添加要全局禁用的快捷键。首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中授权本应用，才能生效。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 420)
}
