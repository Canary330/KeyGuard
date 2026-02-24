//
//  KeyGuardApp.swift
//  KeyGuard
//
//  Created by Mico on 2026/2/23.
//

import SwiftUI
import AppKit

@main
struct KeyGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var disabledShortcuts = DisabledShortcutsStore.shared
    @AppStorage(AppDelegate.remapCmdShiftSToScreenshotKey) private var remapCmdShiftS = false

    private var blockCommandQBinding: Binding<Bool> {
        Binding(
            get: { disabledShortcuts.disablesCommandQ },
            set: { newValue in
                if newValue { disabledShortcuts.addKnown(.commandQ) } else { disabledShortcuts.removeKnown(.commandQ) }
                appDelegate.updateQuitMenuItemState()
            }
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                blockCommandQ: blockCommandQBinding,
                remapCmdShiftS: $remapCmdShiftS,
                onOpenSettings: { appDelegate.openSettingsWindow() }
            )
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarIconView: View {
    var body: some View {
        if NSImage(named: "MenuBarIcon") != nil {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "hand.raised.slash.fill")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, height: 22)
        }
    }
}

private struct MenuBarContentView: View {
    @Binding var blockCommandQ: Bool
    @Binding var remapCmdShiftS: Bool
    var onOpenSettings: () -> Void

    var body: some View {
        Button {
            blockCommandQ.toggle()
        } label: {
            if blockCommandQ {
                Label("禁止 ⌘Q 退出：已开启", systemImage: "checkmark.circle.fill")
            } else {
                Label("禁止 ⌘Q 退出：已关闭", systemImage: "circle")
            }
        }
        .buttonStyle(.borderless)

        Button {
            remapCmdShiftS.toggle()
        } label: {
            if remapCmdShiftS {
                Label("⌘⇧S 当作截图：已开启", systemImage: "checkmark.circle.fill")
            } else {
                Label("⌘⇧S 当作截图：已关闭", systemImage: "circle")
            }
        }
        .buttonStyle(.borderless)

        Divider()

        Button("设置…") {
            onOpenSettings()
        }
        .buttonStyle(.borderless)

        Divider()

        Button("退出 KeyGuard") {
            NSApplication.shared.terminate(nil)
        }
    }
}
