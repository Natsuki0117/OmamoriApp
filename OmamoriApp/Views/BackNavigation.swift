import SwiftUI

private struct RootBackActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var rootBackAction: (() -> Void)? {
        get { self[RootBackActionKey.self] }
        set { self[RootBackActionKey.self] = newValue }
    }
}

private struct AppBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(\.rootBackAction) private var rootBackAction
    let disabled: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isPresented || rootBackAction == nil {
                            dismiss()
                        } else {
                            rootBackAction?()
                        }
                    } label: {
                        Label("戻る", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                            .font(.body)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .disabled(disabled)
                    .accessibilityLabel("戻る")
                    .accessibilityIdentifier("navigation.back")
                }
            }
    }
}

extension View {
    func appBackButton(disabled: Bool = false) -> some View {
        modifier(AppBackButtonModifier(disabled: disabled))
    }
}
