import SwiftUI
import UIKit

struct WritingAnswerInput: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let language: Locale.Language?
    let isEnabled: Bool
    let control: WritingInputControl
    let onSubmit: () -> Void

    @Environment(\.practice) private var configuration
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.controlSpacing) {
            HStack {
                Label("Your answer", systemImage: "keyboard")
                Spacer()
                if let language { Text(locale.name(of: language)) }
            }
            .font(configuration.inputLabelFont)
            .foregroundStyle(.secondary)
            WritingAnswerField(
                text: $text, isFocused: $isFocused, language: language,
                isEnabled: isEnabled, control: control, onSubmit: onSubmit
            )
        }
        .padding(configuration.inputPadding)
        .background(.background, in: .rect(cornerRadius: configuration.inputCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: configuration.inputCornerRadius)
                .strokeBorder(
                    isFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    lineWidth: configuration.inputBorderWidth
                )
        }
    }
}

/// Keeps confirmation synchronous with UIKit's final IME composition, before the answer is captured.
final class WritingInputControl {
    weak var field: UITextField?

    func committedText() -> String? {
        field?.unmarkText()
        let text = field?.text
        field?.resignFirstResponder()
        return text
    }
}

/// A native, single-line field: SwiftUI doesn't expose the responder's preferred keyboard language.
struct WritingAnswerField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let language: Locale.Language?
    let isEnabled: Bool
    let control: WritingInputControl
    let onSubmit: () -> Void

    @Environment(\.practice) private var configuration

    func makeUIView(context: Context) -> LanguageTextField {
        let field = LanguageTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.placeholder = String(localized: "Type the term or phrase")
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.accessibilityLabel = String(localized: "Your answer")
        field.accessibilityIdentifier = "writing.response"
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.field = field
        return field
    }

    func updateUIView(_ field: LanguageTextField, context: Context) {
        context.coordinator.parent = self
        field.language = language
        field.font = configuration.answerFont.resolve(in: context.environment.fontResolutionContext).ctFont as UIFont
        field.isEnabled = isEnabled
        // Never replace an in-progress composition or reset the cursor on every binding update.
        if field.markedTextRange == nil, field.text != text { field.text = text }
        if !isEnabled, field.isFirstResponder { field.resignFirstResponder() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LanguageTextField, context: Context) -> CGSize? {
        let size = uiView.intrinsicContentSize
        return CGSize(
            width: proposal.width ?? size.width,
            height: max(size.height, configuration.inputMinimumHeight)
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: WritingAnswerField
        init(_ parent: WritingAnswerField) { self.parent = parent }

        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
            #if DEBUG
                if ProcessInfo.processInfo.environment["LEXCALLI_LIBRARY"]?.hasPrefix("UITest-") == true {
                    textField.accessibilityHint =
                        "Keyboard language: \(textField.textInputMode?.primaryLanguage ?? "unknown")"
                }
            #endif
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            let text = textField.text ?? ""
            if parent.text != text { parent.text = text }
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // Return first commits a marked candidate; it must not also submit that composition.
            guard textField.markedTextRange == nil else { return true }
            parent.text = textField.text ?? ""
            parent.onSubmit()
            return false
        }
    }
}

final class LanguageTextField: UITextField {
    var language: Locale.Language?
    private var preferredMode: UITextInputMode?

    override func becomeFirstResponder() -> Bool {
        preferredMode = matchingMode()
        return super.becomeFirstResponder()
    }

    override var textInputMode: UITextInputMode? { preferredMode ?? super.textInputMode }

    private func matchingMode() -> UITextInputMode? {
        guard let language, let code = language.languageCode else { return nil }
        let modes = UITextInputMode.activeInputModes
        // Prefer the exact regional layout, then the same language and script. Never choose emoji
        // or another script just because its language code happens to match.
        if let exact = modes.first(where: { mode in
            guard let identifier = mode.primaryLanguage else { return false }
            return Locale.Language(identifier: identifier).maximalIdentifier == language.maximalIdentifier
        }) {
            return exact
        }
        return modes.first { mode in
            guard let identifier = mode.primaryLanguage else { return false }
            let candidate = Locale.Language(identifier: identifier)
            return candidate.languageCode == code && candidate.script == language.script
        }
    }
}
