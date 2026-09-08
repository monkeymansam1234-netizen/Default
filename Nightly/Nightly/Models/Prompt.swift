import Foundation

/// One question on the nightly card. Users can turn any of these off,
/// or add their own, so the card stays as short as they want it.
struct Prompt: Codable, Identifiable, Hashable {
    var id: String
    var text: String
    var symbolName: String
    var isEnabled: Bool
    var isBuiltIn: Bool

    init(id: String, text: String, symbolName: String, isEnabled: Bool, isBuiltIn: Bool) {
        self.id = id
        self.text = text
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "circle"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    /// The first three are the ones that ship switched on — the rest are
    /// there for whoever wants them, but an empty-feeling card is the point.
    static let builtIns: [Prompt] = [
        Prompt(id: "accomplished", text: "Happy with what you got done?", symbolName: "checkmark.circle", isEnabled: true, isBuiltIn: true),
        Prompt(id: "food", text: "Happy with how you ate?", symbolName: "fork.knife", isEnabled: true, isBuiltIn: true),
        Prompt(id: "bedtime", text: "Getting to bed at a decent hour?", symbolName: "moon.stars", isEnabled: true, isBuiltIn: true),
        Prompt(id: "movement", text: "Did you move your body?", symbolName: "figure.walk", isEnabled: false, isBuiltIn: true),
        Prompt(id: "people", text: "Any real contact with someone?", symbolName: "person.2", isEnabled: false, isBuiltIn: true),
        Prompt(id: "kindness", text: "Were you kind to yourself?", symbolName: "heart", isEnabled: false, isBuiltIn: true),
        Prompt(id: "screens", text: "Happy with your screen time?", symbolName: "iphone", isEnabled: false, isBuiltIn: true)
    ]
}
