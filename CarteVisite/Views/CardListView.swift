import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var exportError: String?
    @State private var showImporter = false
    @State private var infoMessage: String?
    @State private var selectedTag: String?

    /// Toutes les etiquettes presentes dans le coffre, triees.
    private var allTags: [String] {
        Set(cards.flatMap { $0.tags }).sorted()
    }

    private var filteredCards: [BusinessCard] {
        cards.filter { card in
            let matchesTag = selectedTag == nil || card.tags.contains(selectedTag!)
            guard matchesTag else { return false }
            guard !searchText.isEmpty else { return true }
            let query = searchText.lowercased()
            return ([card.fullName, card.company, card.jobTitle, card.email, card.phone, card.mobile]
                .contains { $0.lowercased().contains(query) })
                || card.tags.contains { $0.lowercased().contains(query) }
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
                    Menu {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Importer un fichier .vcf", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            exportAll()
                        } label: {
                            Label("Exporter le coffre (.vcf)", systemImage: "square.and.arrow.up")
                        }
                        .disabled(cards.isEmpty)
                        Divider()
                        Button {
                            showAbout = true
                        } label: {
                            Label("A propos", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Menu")
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
            .sheet(isPresented: $showShare) {
                ShareSheet(items: shareItems)
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.vCard, .text],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("Export impossible", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(exportError ?? "")
            }
            .alert("Import", isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(infoMessage ?? "")
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

    private func exportAll() {
        guard !cards.isEmpty else { return }
        do {
            let url = try ContactManager.exportFileURL(cards: cards)
            shareItems = [url]
            showShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

            let imported = try ContactManager.importCards(fromVCardAt: url)
            guard !imported.isEmpty else {
                infoMessage = "Aucune carte n'a ete trouvee dans ce fichier."
                return
            }
            for card in imported { modelContext.insert(card) }
            infoMessage = "\(imported.count) carte(s) importee(s) dans le coffre."
        } catch {
            exportError = "Import impossible : \(error.localizedDescription)"
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
        VStack(spacing: 0) {
            if !allTags.isEmpty {
                tagFilterBar
            }
            if filteredCards.isEmpty {
                ContentUnavailableView.search
            } else {
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
        }
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Toutes", selected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(allTags, id: \.self) { tag in
                    FilterChip(label: tag, selected: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
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
