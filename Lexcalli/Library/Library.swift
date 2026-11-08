import Foundation
import LexcalliCore
import LexcalliStore
import SwiftUI

/// Stores, media and exercise engines as views reach them; built only by `compose`.
nonisolated struct Library: Sendable {
    let decks: any DeckStore
    let reviews: any ReviewStore
    let media: MediaLibrary
    let exerciseEngines: ExerciseEnginesByMode

    /// The one place dependencies are wired: the app launch, previews and UI tests all come through here, so tests
    /// exercise the production graph with only the launch's test hooks swapped in.
    static func compose(
        store: some DeckStore & ReviewStore, media: MediaLibrary, launch: LaunchConfiguration = LaunchConfiguration()
    ) -> Library {
        var reviews: any ReviewStore = store
        var exerciseEngines = ExerciseEnginesByMode.standard
        #if DEBUG
            if let fixture = launch.exerciseFixture {
                exerciseEngines = fixture.exerciseEngines
                if launch.failsFirstExerciseAcknowledgement { reviews = LostExerciseAcknowledgement(base: store) }
            }
        #endif
        return Library(decks: store, reviews: reviews, media: media, exerciseEngines: exerciseEngines)
    }

    /// Fills an empty library as the launch asks; a starter deck that fails to load never blocks opening.
    func seed(for launch: LaunchConfiguration) async throws {
        #if DEBUG
            if let fixture = launch.exerciseFixture { return try await fixture.seedIfEmpty(self) }
        #endif
        if launch.seedsSamples {
            try await SampleLibrary.seedIfEmpty(self)
        } else {
            try? await StarterDeck.addIfNew(to: self, named: launch.libraryName)
        }
    }

    /// Empty, so a view outside a composed hierarchy shows no decks.
    static let unavailable = compose(
        store: try! DatabaseStore.inMemory(),
        media: MediaLibrary(root: URL.temporaryDirectory.appending(path: "Lexcalli-unavailable-media"))
    )
}

extension EnvironmentValues {
    @Entry var library = Library.unavailable
}

/// What this launch asks for, read once from the process environment. UI tests set `LEXCALLI_LIBRARY`,
/// `LEXCALLI_SEED_SAMPLES` and, in debug builds, `LEXCALLI_EXERCISE_FIXTURE` / `LEXCALLI_FAIL_EXERCISE_ACK_ONCE`.
nonisolated struct LaunchConfiguration: Sendable {
    /// A directory name in Application Support, which backups include.
    var libraryName = "Lexcalli"
    var seedsSamples = false
    #if DEBUG
        /// Only for isolated `UITest-` libraries, never a learner's.
        var exerciseFixture: ExerciseUITestFixture?
        var failsFirstExerciseAcknowledgement = false
    #endif

    init() {}

    init(environment: [String: String]) {
        // A directory name only, never outside Application Support.
        if let name = environment["LEXCALLI_LIBRARY"].map({ URL(filePath: $0).lastPathComponent }),
            !name.isEmpty, name != ".."
        {
            libraryName = name
        }
        seedsSamples = environment["LEXCALLI_SEED_SAMPLES"] != nil
        #if DEBUG
            if libraryName.hasPrefix("UITest-") {
                exerciseFixture = environment["LEXCALLI_EXERCISE_FIXTURE"].flatMap(
                    ExerciseUITestFixture.init(rawValue:))
                failsFirstExerciseAcknowledgement = environment["LEXCALLI_FAIL_EXERCISE_ACK_ONCE"] != nil
            }
        #endif
    }

    var root: URL {
        URL.applicationSupportDirectory.appending(path: libraryName, directoryHint: .isDirectory)
    }
}

/// Until opening succeeds, the app shows this instead of an empty deck list.
enum LibraryPhase {
    case opening
    case ready(Library)
    case failed(String)

    /// Off the main actor; migrates if needed.
    @concurrent static func open(
        launch: LaunchConfiguration = LaunchConfiguration(environment: ProcessInfo.processInfo.environment)
    ) async -> LibraryPhase {
        let root = launch.root
        do {
            let store = try DatabaseStore.open(at: root.appending(path: "Lexcalli.sqlite"))
            let library = Library.compose(
                store: store, media: MediaLibrary(root: root.appending(path: "Media")), launch: launch)
            try await library.seed(for: launch)
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
