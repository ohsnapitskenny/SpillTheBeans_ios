import SwiftUI

struct SplashView: View {
    @Environment(AuthService.self) private var authService
    @State private var showAuth  = false
    @State private var authMode  = AuthMode.signIn

    var body: some View {
        ZStack {
            Color.espressoSolid.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── Branding ──────────────────────────────────────────────
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.terracotta.opacity(0.18))
                            .frame(width: 120, height: 120)
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.terracotta)
                    }

                    VStack(spacing: 6) {
                        Text("Spill the Beans")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.cream)

                        Text("Discover specialty coffee near you")
                            .font(.subheadline)
                            .foregroundStyle(Color.cream.opacity(0.65))
                    }
                }

                Spacer()

                // ── Auth Buttons ──────────────────────────────────────────
                VStack(spacing: 14) {
                    Button {
                        authMode = .signIn
                        showAuth = true
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundStyle(Color.espressoSolid)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        authMode = .signUp
                        showAuth = true
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.terracotta)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        authService.continueAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.cream.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.cream.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView(initialMode: authMode)
                .environment(authService)
        }
    }
}
