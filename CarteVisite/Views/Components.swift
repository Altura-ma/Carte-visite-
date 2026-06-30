import SwiftUI
import SwiftData

// MARK: - Disposition en flux (chips qui passent a la ligne)

/// Layout simple qui place les sous-vues de gauche a droite et passe a la ligne
/// quand la largeur est depassee (pour des etiquettes / chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        let width = maxWidth.isFinite ? maxWidth : totalWidth
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Chips

/// Etiquette en lecture seule.
struct TagBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

/// Etiquette supprimable (dans l'editeur).
struct RemovableTagChip: View {
    let text: String
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}

/// Chip de filtre (selectionnable).
struct FilterChip: View {
    let label: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editeur d'etiquettes

/// Permet d'ajouter / retirer des etiquettes, avec suggestions des tags existants.
struct TagsEditor: View {
    @Binding var tags: [String]
    @Query private var allCards: [BusinessCard]
    @State private var newTag = ""

    private var suggestions: [String] {
        let existing = Set(allCards.flatMap { $0.tags })
        return existing.subtracting(tags).sorted().prefix(8).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        RemovableTagChip(text: tag) { remove(tag) }
                    }
                }
            }

            HStack {
                TextField("Ajouter une etiquette…", text: $newTag)
                    .textInputAutocapitalization(.words)
                    .onSubmit { add(newTag) }
                Button {
                    add(newTag)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            add(suggestion)
                        } label: {
                            Label(suggestion, systemImage: "plus")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func add(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}
