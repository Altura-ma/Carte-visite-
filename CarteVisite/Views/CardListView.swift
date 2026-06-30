import SwiftUI
import SwiftData
import PhotosUI

/// Ecran principal : le "coffre" de cartes de visite.
struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]

    @State private var searchText = ""
    @State private var showScanner = false
    @State private var showSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var showAddSheet = false
    @State private var showAbout = false

    private var filteredCards: [BusinessCard] {
        guard !searchText.isEmpty else { return cards }
        let query = searchText.lowercased()
        return cards.filter { card in
            [card.fullName, card.company, card.jobTitle, card.email, card.phone, card.mobile]
                .contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Coffre de cartes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("A propos")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSourceDialog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Ajouter une carte")
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher un nom, une societe…")
            .confirmationDialog("Ajouter une carte", isPresented: $showSourceDialog, titleVisibility: .visible) {
                Button("Scanner avec l'appareil photo") {
                    showScanner = true
                }
                Button("Importer une photo") {
                    showPhotoPicker = true
                }
                Button("Annuler", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(
                    onScan: { image in
                        showScanner = false
                        presentReview(with: image)
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showAddSheet) {
                if let pendingImage {
                    AddCardView(image: pendingImage)
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        presentReview(with: image)
                    }
                    photoItem = nil
                }
            }
        }
    }

    private func presentReview(with image: UIImage) {
        pendingImage = image
        // Petit delai pour laisser la feuille precedente se fermer proprement.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showAddSheet = true
        }
    }

    // MARK: - Sous-vues

    private var cardList: some View {
        List {
            ForEach(filteredCards) { card in
                NavigationLink {
                    CardDetailView(card: card)
                } label: {
                    CardRow(card: card)
                }
            }
            .onDelete(perform: deleteCards)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Coffre vide", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Scannez ou importez une carte de visite pour commencer.\nElle sera analysee automatiquement et stockee sur votre appareil.")
        } actions: {
            Button {
                showSourceDialog = true
            } label: {
                Label("Ajouter une carte", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCards[index])
        }
    }
}

/// Une ligne de la liste : vignette + nom + sous-titre.
struct CardRow: View {
    let card: BusinessCard

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(card.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !card.displaySubtitle.isEmpty {
                    Text(card.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !card.email.isEmpty {
                    Text(card.email)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = card.thumbnailData ?? card.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(card.initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                )
        }
    }
}
