import SwiftUI

/// One question, three big targets. Tapping the selected answer again clears it.
struct PromptCard: View {
    let prompt: Prompt
    let selection: Rating?
    let onSelect: (Rating) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(prompt.text).font(.headline)
            } icon: {
                Image(systemName: prompt.symbolName).foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                ForEach(Rating.allCases) { rating in
                    RatingButton(rating: rating, isSelected: selection == rating) {
                        onSelect(rating)
                    }
                    .accessibilityLabel("\(prompt.text) \(rating.label)")
                }
            }
        }
        .cardStyle()
    }
}

struct RatingButton: View {
    let rating: Rating
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: rating.symbolName)
                    .font(.title2)
                Text(rating.label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? rating.tint : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(rating.tint.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.18), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
