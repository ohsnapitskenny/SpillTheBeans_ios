import SwiftUI

// MARK: - AuthMode

enum AuthMode { case signIn, signUp }

// MARK: - AuthView

struct AuthView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    var initialMode: AuthMode = .signIn

    @State private var mode: AuthMode = .signIn
    @State private var username       = ""
    @State private var password       = ""
    @State private var confirmPassword = ""
    @State private var displayName    = ""
    @State private var email          = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    modePicker
                    if let error = authService.authError { errorBanner(error) }
                    fields
                    submitButton
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.creamBackground)
            .navigationTitle(mode == .signIn ? "Welcome Back" : "Create Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.terracotta)
                }
            }
        }
        .onAppear { mode = initialMode }
        .onChange(of: authService.currentUser) { _, user in
            if user != nil { dismiss() }
        }
    }

    // MARK: - Sub-views

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

    private var fields: some View {
        VStack(spacing: 14) {
            if mode == .signUp {
                styledField("Display Name", text: $displayName)
                    .textContentType(.name)
            }

            styledField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)

            styledSecure("Password", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)

            if mode == .signUp {
                styledSecure("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)

                styledField("Email (optional)", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
            }
        }
        .padding(.horizontal)
    }

    private var submitButton: some View {
        Button(action: submit) {
            ZStack {
                if authService.isLoading {
                    ProgressView().tint(Color.onEspresso)
                } else {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .font(.headline)
                        .foregroundStyle(Color.onEspresso)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isValid ? Color.espresso : Color.espresso.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValid || authService.isLoading)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.espresso.opacity(0.12), lineWidth: 1))
    }

    private func styledSecure(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.espresso.opacity(0.12), lineWidth: 1))
    }

    private var isValid: Bool {
        guard !username.isEmpty, password.count >= 8 else { return false }
        if mode == .signUp {
            return !displayName.isEmpty && password == confirmPassword
        }
        return true
    }

    private func submit() {
        Task {
            if mode == .signIn {
                await authService.signIn(username: username, password: password)
            } else {
                await authService.signUp(
                    username: username,
                    password: password,
                    displayName: displayName,
                    email: email.isEmpty ? nil : email
                )
            }
        }
    }
}
