import Foundation

extension Locale {
    /// The language's name in this locale, for example "German"; falls back to its code.
    func name(of language: Locale.Language) -> String {
        localizedString(forIdentifier: language.minimalIdentifier) ?? language.minimalIdentifier
    }
}
