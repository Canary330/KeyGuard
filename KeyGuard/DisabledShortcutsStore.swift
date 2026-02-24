//
//  DisabledShortcutsStore.swift
//  KeyGuard
//
//  Created by Mico on 2026/2/23.
//

import Combine
import Foundation
import AppKit

/// 表示一个被全局禁用的快捷键（仅保存修饰键的 4 位：⌘⇧⌥⌃）
struct DisabledShortcut: Codable, Hashable {
    var keyCode: Int
    /// 位: 0=⌘ 1=⇧ 2=⌥ 3=⌃，与 modifierFlagsToStored 一致
    var modifierBits: Int

    static let userDefaultsKey = "disabledShortcuts"

    /// 从 UserDefaults 读取列表
    static func load() -> [DisabledShortcut] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([DisabledShortcut].self, from: data) else {
            return []
        }
        return list
    }

    /// 写入 UserDefaults（立即同步，便于事件 tap 线程读到）
    static func save(_ list: [DisabledShortcut]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        let ud = UserDefaults.standard
        ud.set(data, forKey: userDefaultsKey)
        ud.synchronize()
    }

    /// NSEvent.ModifierFlags 转为存储用的 modifierBits（只取 ⌘⇧⌥⌃，与 CG 一致）
    static func modifierBits(from nsFlags: NSEvent.ModifierFlags) -> Int {
        let mask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let f = nsFlags.intersection(mask)
        var bits = 0
        if f.contains(.command) { bits |= 1 }
        if f.contains(.shift)   { bits |= 2 }
        if f.contains(.option)  { bits |= 4 }
        if f.contains(.control) { bits |= 8 }
        return bits
    }

    /// CGEventFlags 转为与存储一致的 modifierBits
    static func modifierBits(from cgFlags: CGEventFlags) -> Int {
        var bits = 0
        if cgFlags.contains(.maskCommand) { bits |= 1 }
        if cgFlags.contains(.maskShift)   { bits |= 2 }
        if cgFlags.contains(.maskAlternate) { bits |= 4 }
        if cgFlags.contains(.maskControl)  { bits |= 8 }
        return bits
    }

    /// 用于显示的字符串，如 "⌘Q"、"⌘⇧S"
    var displayString: String {
        let mod = modifierString
        let key = Self.keyLabel(for: keyCode)
        return mod.isEmpty ? key : (mod + key)
    }

    private var modifierString: String {
        var s = ""
        if (modifierBits & 1) != 0 { s += "⌘" }
        if (modifierBits & 2) != 0 { s += "⇧" }
        if (modifierBits & 4) != 0 { s += "⌥" }
        if (modifierBits & 8) != 0 { s += "⌃" }
        return s
    }

    /// 常见 keyCode 的显示标签（与 macOS 虚拟键一致）
    static func keyLabel(for keyCode: Int) -> String {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↵", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "␣", 50: "⌫", 51: "⎋", 52: "⌘", 53: "⌤", 55: "⌥",
            56: "⇧", 57: "⇪", 58: "⌃", 59: "⌃", 60: "⇧", 61: "⌥", 62: "⌃", 63: "fn",
            65: ".", 67: "*", 69: "+", 71: "⌧", 75: "/", 76: "⌤", 78: "-", 81: "=",
            82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
            91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 111: "F11", 103: "F12", 105: "F4", 107: "F2",
            113: "F1", 114: "↩", 115: "↪", 116: "⇞", 117: "⌦", 118: "F13", 119: "F14",
            120: "F15", 121: "F16", 122: "F17", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "Key(\(keyCode))"
    }

    /// 仅无修饰键且为字母/数字键时需提示（可能影响输入法）
    static func isSingleLetterOrNumber(keyCode: Int, modifierBits: Int) -> Bool {
        guard modifierBits == 0 else { return false }
        let letterKeyCodes: Set<Int> = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17, 31,32,34,35, 37,38,40, 45,46]
        let numberKeyCodes: Set<Int> = [18,19,20,21,22,23,24,25,26,27,28,29]
        return letterKeyCodes.contains(keyCode) || numberKeyCodes.contains(keyCode)
    }

    /// 无修饰键且为字母/数字/空格/回车/制表等常用输入键时需醒目警告（可能影响输入法）
    static func shouldWarnWhenAddingSingleKey(keyCode: Int, modifierBits: Int) -> Bool {
        guard modifierBits == 0 else { return false }
        let letterKeyCodes: Set<Int> = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17, 31,32,34,35, 37,38,40, 45,46]
        let numberKeyCodes: Set<Int> = [18,19,20,21,22,23,24,25,26,27,28,29]
        let otherInputKeyCodes: Set<Int> = [36, 48, 49] // 36=回车 48=Tab 49=空格
        return letterKeyCodes.contains(keyCode) || numberKeyCodes.contains(keyCode) || otherInputKeyCodes.contains(keyCode)
    }
}

import CoreGraphics

/// 与「防误触」开关对应的快捷键：⌘Q / ⌘W / ⌘H / ⌘M（keyCode, modifierBits）
enum KnownShortcut: CaseIterable {
    case commandQ  // 12, 1
    case commandW  // 13, 1
    case commandH  // 4, 1
    case commandM  // 46, 1

    var shortcut: DisabledShortcut {
        switch self {
        case .commandQ: return DisabledShortcut(keyCode: 12, modifierBits: 1)
        case .commandW: return DisabledShortcut(keyCode: 13, modifierBits: 1)
        case .commandH: return DisabledShortcut(keyCode: 4, modifierBits: 1)
        case .commandM: return DisabledShortcut(keyCode: 46, modifierBits: 1)
        }
    }

    static func match(keyCode: Int, modifierBits: Int) -> KnownShortcut? {
        KnownShortcut.allCases.first { $0.shortcut.keyCode == keyCode && $0.shortcut.modifierBits == modifierBits }
    }
}

/// 全局禁用的快捷键列表，与设置界面同步
final class DisabledShortcutsStore: ObservableObject {
    static let shared = DisabledShortcutsStore()

    @Published private(set) var list: [DisabledShortcut]

    private init() {
        self.list = DisabledShortcut.load()
        migrateKnownShortcutsFromUserDefaults()
    }

    /// 旧版用 UserDefaults 存 ⌘Q/⌘W/⌘H/⌘M，迁移到列表并统一由列表控制
    private func migrateKnownShortcutsFromUserDefaults() {
        let ud = UserDefaults.standard
        let keys: [(KnownShortcut, String)] = [
            (.commandQ, "blockCommandQ"),
            (.commandW, "blockCommandW"),
            (.commandH, "blockCommandH"),
            (.commandM, "blockCommandM"),
        ]
        for (known, key) in keys {
            if ud.bool(forKey: key), !list.contains(known.shortcut) {
                list.append(known.shortcut)
            }
            ud.removeObject(forKey: key)
        }
        if !keys.isEmpty { save() }
    }

    func add(keyCode: Int, modifierBits: Int) {
        let shortcut = DisabledShortcut(keyCode: keyCode, modifierBits: modifierBits)
        if !list.contains(shortcut) {
            list.append(shortcut)
            save()
        }
    }

    func remove(_ shortcut: DisabledShortcut) {
        list.removeAll { $0 == shortcut }
        save()
    }

    func remove(at index: Int) {
        guard index >= 0, index < list.count else { return }
        list.remove(at: index)
        save()
    }

    /// 列表中是否包含该快捷键
    func contains(_ shortcut: DisabledShortcut) -> Bool {
        list.contains(shortcut)
    }

    /// 开启某已知快捷键：加入列表（不重复）并返回是否与已知重合（供外部同步开关）
    func addKnown(_ known: KnownShortcut) {
        add(keyCode: known.shortcut.keyCode, modifierBits: known.shortcut.modifierBits)
    }

    /// 关闭某已知快捷键：从列表中移除
    func removeKnown(_ known: KnownShortcut) {
        remove(known.shortcut)
    }

    private func save() {
        DisabledShortcut.save(list)
    }

    /// 当前是否包含 Command+Q（用于本应用 Quit 菜单项显示）
    var disablesCommandQ: Bool {
        list.contains { $0.keyCode == 12 && $0.modifierBits == 1 }
    }

    /// 仅「自定义」项（排除 ⌘Q/⌘W/⌘H/⌘M），用于列表展示；下方四个开关单独控制那四项
    var customOnlyList: [DisabledShortcut] {
        list.filter { KnownShortcut.match(keyCode: $0.keyCode, modifierBits: $0.modifierBits) == nil }
    }
}
