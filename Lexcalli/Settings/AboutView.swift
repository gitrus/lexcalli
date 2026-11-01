import SwiftUI

/// App version and credits for the work Lexcalli builds on.
struct AboutView: View {
    @State private var shownLicense: ThirdPartyLibrary?

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

            Section("Libraries") {
                ForEach(ThirdPartyLibrary.all) { library in
                    Button {
                        shownLicense = library
                    } label: {
                        LabeledContent {
                            Text(verbatim: "\(library.version) · \(library.license)")
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(library.name)
                            Text(library.role)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Media") {
                // Sample deck photo for "der Schmetterling".
                Link(destination: URL(string: "https://commons.wikimedia.org/wiki/File:Admiral_(Juli_2024).jpg")!) {
                    LabeledContent {
                        Text("Photo, CC0")
                    } label: {
                        Text(verbatim: "Admiral (Juli 2024)")
                    }
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shownLicense) { LicenseView(library: $0) }
    }
}

/// Every library `LexcalliKit/Package.swift` depends on; keep versions in step with it.
private struct ThirdPartyLibrary: Identifiable {
    let name: String
    let role: LocalizedStringKey
    let version: String
    /// SPDX identifier, as published; not localized.
    let license: String
    let url: URL

    var id: String { name }

    /// Copied from the library's repository as `Settings/Licenses/<name>-LICENSE.txt`. Paragraphs are rejoined,
    /// as the files break lines for a fixed width.
    var licenseText: String {
        let text =
            Bundle.main.url(forResource: "\(name)-LICENSE", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return text.components(separatedBy: "\n\n")
            .map { $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ") }
            .joined(separator: "\n\n")
    }

    static let all = [
        ThirdPartyLibrary(
            name: "swift-fsrs", role: "Scheduling", version: "4fbaf20", license: "MIT",
            url: URL(string: "https://github.com/open-spaced-repetition/swift-fsrs")!),
        ThirdPartyLibrary(
            name: "GRDB", role: "Storage", version: "7.11.1", license: "MIT",
            url: URL(string: "https://github.com/groue/GRDB.swift")!),
        ThirdPartyLibrary(
            name: "ZIPFoundation", role: "Deck import", version: "0.9.20", license: "MIT",
            url: URL(string: "https://github.com/weichsel/ZIPFoundation")!),
        // Dual-licensed; used under BSD.
        ThirdPartyLibrary(
            name: "zstd", role: "Deck import", version: "1.5.7", license: "BSD-3-Clause",
            url: URL(string: "https://github.com/facebook/zstd")!),
    ]
}

private struct LicenseView: View {
    let library: ThirdPartyLibrary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsList) private var configuration

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(library.licenseText)
                    .font(configuration.licenseFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(library.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Link(destination: library.url) {
                        Label("Project Page", systemImage: "safari")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
