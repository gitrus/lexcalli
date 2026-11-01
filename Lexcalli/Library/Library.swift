import Foundation
import LexcalliCore
import LexcalliStore
import SwiftUI

/// Stores and media library as views reach them; composed once in `LexcalliApp`.
nonisolated struct Library: Sendable {
    let decks: any DeckStore
    let reviews: any ReviewStore
    let media: MediaLibrary

    init(store: some DeckStore & ReviewStore, media: MediaLibrary) {
        decks = store
        reviews = store
        self.media = media
    }

    /// Empty, so a view outside a composed hierarchy shows no decks.
    static let unavailable = Library(
        store: InMemoryStore(),
        media: MediaLibrary(root: URL.temporaryDirectory.appending(path: "Lexcalli-unavailable-media"))
    )
}

extension EnvironmentValues {
    @Entry var library = Library.unavailable
}

/// Until opening succeeds, the app shows this instead of an empty deck list.
enum LibraryPhase {
    case opening
    case ready(Library)
    case failed(String)

    /// Application Support, which backups include. UI tests set `LEXCALLI_LIBRARY` and `LEXCALLI_SEED_SAMPLES`.
    nonisolated static var root: URL {
        // A directory name only, never outside Application Support.
        let name = ProcessInfo.processInfo.environment["LEXCALLI_LIBRARY"].map { URL(filePath: $0).lastPathComponent }
            .flatMap { $0.isEmpty || $0 == ".." ? nil : $0 }
        return URL.applicationSupportDirectory.appending(path: name ?? "Lexcalli", directoryHint: .isDirectory)
    }

    /// Off the main actor; migrates if needed.
    @concurrent static func open() async -> LibraryPhase {
        let root = root
        do {
            let store = try DatabaseStore.open(at: root.appending(path: "Lexcalli.sqlite"))
            let library = Library(store: store, media: MediaLibrary(root: root.appending(path: "Media")))
            if ProcessInfo.processInfo.environment["LEXCALLI_SEED_SAMPLES"] != nil {
                try await SampleLibrary.seedIfEmpty(library)
            }
            return .ready(library)
        } catch StoreOpenError.migrationFailed(_, let reason) {
            return .failed(
                String(
                    localized:
                        "Your decks couldn't be upgraded and were left unchanged. Update the app or contact support. (\(reason))"
                ))
        } catch StoreOpenError.newerSchema {
            return .failed(String(localized: "Your decks were saved by a newer version of Lexcalli. Update the app."))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
