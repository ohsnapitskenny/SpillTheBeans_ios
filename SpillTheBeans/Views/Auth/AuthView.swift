import SwiftUI

// MARK: - AuthMode

enum AuthMode { case signIn, signUp }

// MARK: - AuthView
//
// Passwordless, two-step flow:
//   Step 1 — collect email (+ username when creating an account), request a code.
//   Step 2 — enter the 6-digit code emailed by the worker to get a session.
// The step is driven by `authService.pendingEmail`: nil = step 1, set = step 2.

struct AuthView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    var initialMode: AuthMode = .signIn

    @State private var mode: AuthMode = .signIn
    @State private var username = ""
    @State private var email    = ""
    @State private var code     = ""

    @FocusState private var codeFocused: Bool

    private var isCodeStep: Bool { authService.pendingEmail != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let error = authService.authError { errorBanner(error) }

                    if isCodeStep {
                        codeStep
                    } else {
                        modePicker
                        emailFields
                        submitButton
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.25), value: isCodeStep)
            }
            .background(Color.creamBackground)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isCodeStep ? "Back" : "Cancel") {
                        if isCodeStep {
                            code = ""
                            authService.cancelCodeEntry()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.terracotta)
                }
            }
        }
        .onAppear { mode = initialMode }
        .onChange(of: authService.currentUser) { _, user in
            if user != nil { dismiss() }
        }
        .onChange(of: isCodeStep) { _, codeStep in
            if codeStep { codeFocused = true }
        }
    }

    private var navigationTitle: String {
        if isCodeStep { return "Check Your Email" }
        return mode == .signIn ? "Welcome Back" : "Create Account"
    }

    // MARK: - Step 1: email

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text("Sign In").tag(AuthMode.signIn)
            Text("Create Account").tag(AuthMode.signUp)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: mode) { _, _ in
            authService.authError = nil
        }
    }

    private var emailFields: some View {
        VStack(spacing: 14) {
            if mode == .signUp {
                styledField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
            }

            styledField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

            Text(mode == .signIn
                 ? "We'll email you a 6-digit code to sign in."
                 : "We'll email you a 6-digit code to confirm your account.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    private var submitButton: some View {
        Button(action: requestCode) {
            buttonLabel(title: "Send Code")
        }
        .disabled(!isEmailStepValid || authService.isLoading)
        .padding(.horizontal)
    }

    // MARK: - Step 2: code

    private var codeStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.espresso)
                Text("Enter the 6-digit code sent to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(authService.pendingEmail ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.espresso)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 8)

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .kerning(8)
                .focused($codeFocused)
                .padding(14)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.espresso.opacity(0.12), lineWidth: 1))
                .onChange(of: code) { _, newValue in
                    // Keep digits only, capped at 6.
                    let digits = String(newValue.filter(\.isNumber).prefix(6))
                    if digits != newValue { code = digits }
                }

            Button(action: verify) {
                buttonLabel(title: "Verify")
            }
            .disabled(code.count != 6 || authService.isLoading)

            Button("Resend code") {
                code = ""
                Task { await authService.resendCode() }
            }
            .font(.subheadline)
            .foregroundStyle(Color.terracotta)
            .disabled(authService.isLoading)
        }
        .padding(.horizontal)
    }

    // MARK: - Shared UI

    private func buttonLabel(title: String) -> some View {
        ZStack {
            if authService.isLoading {
                ProgressView().tint(Color.onEspresso)
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.onEspresso)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(isActionEnabled ? Color.espresso : Color.espresso.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Drives the button fill colour for whichever step is showing.
    private var isActionEnabled: Bool {
        isCodeStep ? code.count == 6 : isEmailStepValid
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.espresso.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Validation & actions

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespaces)
    }

    private var isEmailValid: Bool {
        let e = trimmedEmail
        guard let at = e.firstIndex(of: "@") else { return false }
        let domain = e[e.index(after: at)...]
        return at != e.startIndex && domain.contains(".") && !domain.hasSuffix(".")
    }

    private var isEmailStepValid: Bool {
        guard isEmailValid else { return false }
        if mode == .signUp {
            return username.trimmingCharacters(in: .whitespaces).count >= 3
        }
        return true
    }

    private func requestCode() {
        let e = trimmedEmail
        Task {
            if mode == .signIn {
                await authService.requestSignIn(email: e)
            } else {
                await authService.requestSignUp(
                    email: e,
                    username: username.trimmingCharacters(in: .whitespaces)
                )
            }
        }
    }

    private func verify() {
        Task { await authService.verifyCode(code) }
    }
}
