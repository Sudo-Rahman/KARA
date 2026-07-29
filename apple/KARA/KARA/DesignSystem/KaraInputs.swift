import SwiftUI

extension View {
    func karaTextInputSurface() -> some View {
        modifier(KaraTextInputSurfaceModifier())
    }

    func karaCobaltControlSurface() -> some View {
        modifier(KaraCobaltControlSurfaceModifier())
    }

    func karaDismissibleKeyboard<FocusValue: Hashable>(
        focusedField: FocusState<FocusValue?>.Binding
    ) -> some View {
        modifier(
            KaraKeyboardDismissalModifier(
                dismissKeyboard: {
                    focusedField.wrappedValue = nil
                }
            )
        )
    }

    func karaDismissibleKeyboard(
        isFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(
            KaraKeyboardDismissalModifier(
                dismissKeyboard: {
                    isFocused.wrappedValue = false
                }
            )
        )
    }
}

private struct KaraTextInputSurfaceModifier: ViewModifier {
    @Environment(KaraTheme.self) private var theme

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(theme.ink)
            .tint(theme.cobaltBright)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(
                Color.black.opacity(0.24),
                in: .rect(cornerRadius: 12)
            )
    }
}

private struct KaraCobaltControlSurfaceModifier: ViewModifier {
    @Environment(KaraTheme.self) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
            .foregroundStyle(theme.cobaltBright)
            .tint(theme.cobaltBright)
            .background(
                theme.cobalt.opacity(0.16),
                in: .rect(cornerRadius: 12)
            )
    }
}

private struct KaraKeyboardDismissalModifier: ViewModifier {
    let dismissKeyboard: () -> Void

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.never)
            .gesture(
                TapGesture().onEnded { _ in
                    dismissKeyboard()
                },
                including: .gesture
            )
    }
}
