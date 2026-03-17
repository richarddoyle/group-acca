import AuthenticationServices
import SwiftUI
import Supabase

struct LoginView: View {
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var showingError = false
    @Binding var isAuthenticated: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7"))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Upper third: wordmark
                Spacer(minLength: 80)

                Image(colorScheme == .dark ? "DarkmodeWatermark" : "LightmodeWatermark")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 65)

                // Slogan
                Text("Bet together. Win together.")
                    .font(.custom("BarlowCondensed-Medium", size: 24, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        (colorScheme == .dark ? Color(hex: "F2F2F7") : Color(hex: "071321"))
                            .opacity(0.90)
                    )
                    .padding(.top, 12)

                Spacer()
                Spacer()
                Spacer()

                // Sign in button pinned to bottom
                if isSigningIn {
                    ProgressView("Signing in...")
                        .padding(.bottom, 48)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        let appleRequest = AppleSignInManager.shared.request()
                        request.requestedScopes = appleRequest.requestedScopes
                        request.nonce = appleRequest.nonce
                    } onCompletion: { result in
                        handleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
        }
        .alert("Sign In Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        Task {
            do {
                let (idToken, nonce) = try await AppleSignInManager.shared.handleSignIn(with: result)
                try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                await MainActor.run {
                    self.isSigningIn = false
                    self.isAuthenticated = true
                }
            } catch {
                print("Sign in failed: \(error)")
                await MainActor.run {
                    self.isSigningIn = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    LoginView(isAuthenticated: .constant(false))
}
