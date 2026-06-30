import SwiftUI
import SwiftData

/// Detail d'une carte : photo, informations, et actions rapides
/// (ajout aux contacts en 1 clic, partage, edition, suppression).
struct CardDetailView: View {
    @Bindable var card: BusinessCard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var isAddingContact = false
    @State private var alert: AlertState?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                cardImage
                quickActions
                if !card.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(card.tags, id: \.self) { tag in
                            TagBadge(text: tag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                infoSection
            }
            .padding()
        }
        .navigationTitle(card.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    Button(role: .destructive) { delete() } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            CardEditView(card: card)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .alert(item: $alert) { state in
            Alert(title: Text(state.title), message: Text(state.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Sous-vues

    @ViewBuilder
    private var cardImage: some View {
        if let data = card.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.gradient)
                .frame(height: 180)
                .overlay(
                    Text(card.initials)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                addToContacts()
            } label: {
                Label(isAddingContact ? "Ajout…" : "Ajouter aux contacts",
                      systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAddingContact)

            Button {
                share()
            } label: {
                Label("Partager", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            InfoRow(systemImage: "person", label: "Nom", value: card.fullName)
            InfoRow(systemImage: "briefcase", label: "Poste", value: card.jobTitle)
            InfoRow(systemImage: "building.2", label: "Societe", value: card.company)
            InfoRow(systemImage: "envelope", label: "Email", value: card.email, link: card.email.isEmpty ? nil : URL(string: "mailto:\(card.email)"))
            InfoRow(systemImage: "phone", label: "Telephone", value: card.phone, link: telURL(card.phone))
            InfoRow(systemImage: "iphone", label: "Mobile", value: card.mobile, link: telURL(card.mobile))
            InfoRow(systemImage: "globe", label: "Site web", value: card.website, link: URL(string: card.website))
            InfoRow(systemImage: "mappin.and.ellipse", label: "Adresse", value: card.address)
            InfoRow(systemImage: "note.text", label: "Notes", value: card.notes)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func telURL(_ number: String) -> URL? {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    // MARK: - Actions

    private func addToContacts() {
        isAddingContact = true
        Task {
            do {
                try await ContactManager.addToContacts(card)
                alert = AlertState(title: "Contact ajoute", message: "\(card.displayTitle) a ete ajoute a vos contacts.")
            } catch {
                alert = AlertState(title: "Erreur", message: error.localizedDescription)
            }
            isAddingContact = false
        }
    }

    private func share() {
        var items: [Any] = []
        if let url = try? ContactManager.vCardFileURL(for: card) {
            items.append(url)
        }
        if let data = card.imageData, let image = UIImage(data: data) {
            items.append(image)
        }
        guard !items.isEmpty else {
            alert = AlertState(title: "Rien a partager", message: "Cette carte ne contient pas de donnees a partager.")
            return
        }
        shareItems = items
        showShare = true
    }

    private func delete() {
        modelContext.delete(card)
        dismiss()
    }
}

/// Une ligne d'information (masquee si la valeur est vide).
struct InfoRow: View {
    let systemImage: String
    let label: String
    let value: String
    var link: URL?

    var body: some View {
        if !value.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let link {
                            Link(value, destination: link)
                                .font(.body)
                        } else {
                            Text(value)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                Divider().padding(.leading, 50)
            }
        }
    }
}

/// Petit modele d'alerte identifiable.
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
