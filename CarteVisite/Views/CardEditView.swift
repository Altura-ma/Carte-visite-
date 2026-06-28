import SwiftUI

/// Edition des champs d'une carte existante.
struct CardEditView: View {
    @Bindable var card: BusinessCard
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CardDraft

    init(card: BusinessCard) {
        self.card = card
        _draft = State(initialValue: CardDraft(from: card))
    }

    var body: some View {
        NavigationStack {
            Form {
                CardFormFields(draft: $draft)
            }
            .navigationTitle("Modifier la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        draft.apply(to: card)
                        dismiss()
                    }
                }
            }
        }
    }
}
