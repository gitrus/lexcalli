import SwiftUI

/// App version and credits for the work Lexcalli builds on.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            // Opens the source code, where the version's changes can be found.
            Link(destination: URL(string: "https://github.com/gitrus/lexcalli")!) {
                LabeledContent("Version", value: version)
            }

            Section("Acknowledgements") {
                Link(destination: URL(string: "https://github.com/open-spaced-repetition/swift-fsrs")!) {
                    credit("swift-fsrs", role: "Scheduling")
                }
                // Sample deck photo for "der Schmetterling".
                Link(destination: URL(string: "https://commons.wikimedia.org/wiki/File:Admiral_(Juli_2024).jpg")!) {
                    credit("Admiral (Juli 2024)", role: "Photo, CC0")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The name of a project or work stays as published; only what it is used for is localized.
    private func credit(_ name: String, role: LocalizedStringKey) -> some View {
        LabeledContent {
            Text(role)
        } label: {
            Text(name)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
