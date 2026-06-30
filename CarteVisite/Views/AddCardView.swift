import SwiftUI
import SwiftData

/// Ecran de revue apres scan/import : lance l'OCR local, pre-remplit les champs,
/// laisse l'utilisateur corriger puis enregistre la carte dans le coffre.
struct AddCardView: View {
    let image: UIImage

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CardDraft()
    @State private var isAnalyzing = true
    @State private var rawText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if isAnalyzing {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Analyse de la carte en cours…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    CardFormFields(draft: $draft)

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(isAnalyzing)
                }
            }
            .task {
                await analyze()
            }
        }
    }

    private func analyze() async {
        isAnalyzing = true
        do {
            let fields = try await CardScanner.scan(image)
            draft = CardDraft(from: fields)
            rawText = fields.rawText
        } catch {
            errorMessage = "Aucun texte detecte automatiquement. Saisissez les informations manuellement."
        }
        isAnalyzing = false
    }

    private func save() {
        let card = BusinessCard(
            fullName: draft.fullName,
            jobTitle: draft.jobTitle,
            company: draft.company,
            email: draft.email,
            phone: draft.phone,
            mobile: draft.mobile,
            website: draft.website,
            address: draft.address,
            notes: draft.notes,
            rawText: rawText,
            imageData: ImageProcessing.fullImageData(from: image),
            thumbnailData: ImageProcessing.thumbnailData(from: image)
        )
        modelContext.insert(card)
        dismiss()
    }
}
