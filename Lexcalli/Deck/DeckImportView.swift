import LexcalliCore
import LexcalliImport
import NaturalLanguage
import SwiftUI
import UniformTypeIdentifiers

extension Library {
    var deckFileTypes: [UTType] {
        deckFormats.flatMap(\.filenameExtensions).compactMap { UTType(filenameExtension: $0, conformingTo: .data) }
    }
}

struct DeckImportRequest: Identifiable {
    let id = UUID()
    let file: Result<URL, any Error>
}

struct DeckImportView: View {
    let request: DeckImportRequest

    @Environment(\.library) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var phase = Phase.reading
    @State private var name = ""
    @State private var termLanguage = Locale.Language(identifier: "en")
    @State private var meaningLanguage = Locale.Language(identifier: "en")
    @State private var isSaving = false
    @State private var saveFailure: String?

    private enum Phase {
        case reading
        case ready(ImportedDeck)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Deck")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import", systemImage: "checkmark") { Task { await save() } }
                            .disabled(deckToSave == nil || isSaving)
                            .accessibilityIdentifier("deckImport.confirm")
                    }
                }
        }
        // Dismissing cancels reading; formats stop between chunks.
        .task { await read() }
        .interactiveDismissDisabled(isSaving)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .reading:
            ProgressView("Reading Deck…")
        case .failed(let message):
            LoadFailureView(title: "Couldn't Import Deck", message: message)
        case .ready(let deck):
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                .listRowBackground(Color.paper)
                Section {
                    Picker("Words", selection: $termLanguage) { languageOptions }
                    Picker("Meanings", selection: $meaningLanguage) { languageOptions }
                } header: {
                    Text("Languages")
                } footer: {
                    Text("Guessed from the words; check before importing.")
                }
                .listRowBackground(Color.paper)
                Section {
                    LabeledContent("Words", value: deck.notes.count, format: .number)
                } footer: {
                    VStack(alignment: .leading) {
                        if deck.skippedNotes > 0 {
                            Text(
                                "^[\(deck.skippedNotes) note](inflect: true) without a word or meaning will be left out."
                            )
                        }
                        Text(
                            "Text only for now: images, audio and review history aren't imported, and cards start as new."
                        )
                        if let saveFailure { Text(saveFailure).foregroundStyle(.red) }
                    }
                }
                .listRowBackground(Color.paper)
            }
            .paperGroupedBackground()
            .disabled(isSaving)
        }
    }

    private var languageOptions: some View {
        ForEach(languages(including: [termLanguage, meaningLanguage]), id: \.self) { language in
            Text(locale.name(of: language)).tag(language)
        }
    }

    private var deckToSave: Deck? {
        guard case .ready(let deck) = phase, !deck.notes.isEmpty else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return deck.deck(termLanguage: termLanguage, meaningLanguage: meaningLanguage, named: trimmed)
    }

    private func read() async {
        do {
            let file = try request.file.get()
            let deck = try await DeckFileReader.read(file, formats: library.deckFormats)
            guard !deck.notes.isEmpty else {
                phase = .failed(String(localized: "No notes in this deck have both a word and a meaning."))
                return
            }
            name = deck.name.isEmpty ? file.deletingPathExtension().lastPathComponent : deck.name
            termLanguage = guessLanguage(of: deck.notes.map(\.term)) ?? termLanguage
            meaningLanguage = guessLanguage(of: deck.notes.map(\.meaning)) ?? meaningLanguage
            phase = .ready(deck)
        } catch is CancellationError {
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private func save() async {
        guard let deck = deckToSave else { return }
        isSaving = true
        saveFailure = nil
        do {
            try await library.decks.save(deck, at: .now)
            dismiss()
        } catch {
            saveFailure = String(localized: "Couldn't save the deck: \(error.localizedDescription)")
        }
        isSaving = false
    }

    private static func message(for error: any Error) -> String {
        switch error as? DeckFileError {
        case .unsupportedFile:
            String(localized: "Lexcalli can't import this kind of file.")
        case .tooLarge:
            String(localized: "The deck is too large to import.")
        case .unreadable:
            String(localized: "The file couldn't be read. It may be damaged or from an unsupported version.")
        case nil:
            error.localizedDescription
        }
    }

    /// Every language with a name, sorted by it, plus the current choices so a selection always has a row.
    private func languages(including chosen: [Locale.Language]) -> [Locale.Language] {
        let all = Locale.LanguageCode.isoLanguageCodes.map { Locale.Language(languageCode: $0) } + chosen
        var seen = Set<Locale.Language>()
        return all.filter {
            locale.localizedString(forLanguageCode: $0.minimalIdentifier) != nil && seen.insert($0).inserted
        }
        .sorted { locale.name(of: $0).localizedStandardCompare(locale.name(of: $1)) == .orderedAscending }
    }
}

private func guessLanguage(of texts: [String]) -> Locale.Language? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(texts.prefix(200).joined(separator: "\n"))
    // Language only: the pickers list languages, not scripts or regions such as `zh-Hans`.
    return recognizer.dominantLanguage.flatMap { Locale.Language(identifier: $0.rawValue).languageCode }
        .map { Locale.Language(languageCode: $0) }
}

private nonisolated enum DeckFileReader {
    @concurrent static func read(_ picked: URL, formats: [any DeckFileFormat]) async throws -> ImportedDeck {
        let fileExtension = picked.pathExtension.lowercased()
        guard let format = formats.first(where: { $0.filenameExtensions.contains(fileExtension) }) else {
            throw DeckFileError.unsupportedFile
        }
        let staging = URL.temporaryDirectory.appending(
            path: "DeckImport-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        // Formats read only this copy, never the picked file, which may change underneath them.
        let copy = staging.appending(path: "source.\(fileExtension)")
        let isScoped = picked.startAccessingSecurityScopedResource()
        do {
            try FileManager.default.copyItem(at: picked, to: copy)
        } catch {
            if isScoped { picked.stopAccessingSecurityScopedResource() }
            throw error
        }
        if isScoped { picked.stopAccessingSecurityScopedResource() }

        let work = staging.appending(path: "work", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: false)
        return try format.read(copy, staging: work)
    }
}
