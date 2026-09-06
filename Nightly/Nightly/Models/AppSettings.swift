import SwiftUI

struct AppSettings: Codable {
    var prompts: [Prompt]
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var hapticsEnabled: Bool
    var appearance: Appearance

    enum Appearance: String, Codable, CaseIterable, Identifiable {
        case dark, light, system

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dark: return "Dark"
            case .light: return "Light"
            case .system: return "System"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .dark: return .dark
            case .light: return .light
            case .system: return nil
            }
        }
    }

    /// Dark by default: this app gets opened in bed with the lights off.
    static let standard = AppSettings(prompts: Prompt.builtIns,
                                      reminderEnabled: false,
                                      reminderHour: 21,
                                      reminderMinute: 30,
                                      hapticsEnabled: true,
                                      appearance: .dark)

    init(prompts: [Prompt],
         reminderEnabled: Bool,
         reminderHour: Int,
         reminderMinute: Int,
         hapticsEnabled: Bool,
         appearance: Appearance) {
        self.prompts = prompts
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.hapticsEnabled = hapticsEnabled
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompts = try container.decodeIfPresent([Prompt].self, forKey: .prompts) ?? Prompt.builtIns
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 21
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 30
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .dark
    }

    var enabledPrompts: [Prompt] { prompts.filter(\.isEnabled) }

    var reminderTime: Date {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Keeps stored settings working when a new built-in question ships:
    /// anything unknown is appended (switched off), user choices survive.
    mutating func mergeInNewBuiltIns() {
        let existingIDs = Set(prompts.map(\.id))
        for builtIn in Prompt.builtIns where !existingIDs.contains(builtIn.id) {
            var addition = builtIn
            addition.isEnabled = false
            prompts.append(addition)
        }
    }
}
