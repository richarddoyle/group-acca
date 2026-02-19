import AuthenticationServices
import SwiftUI
import Supabase

struct LoginView: View {
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var showingError = false
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("WeeklyAcca")
                .font(.largeTitle)
                .bold()
            
            Text("Manage your betting groups and track your weekly accumulators.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            if isSigningIn {
                ProgressView("Signing in...")
                    .padding()
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
                .padding(.horizontal)
                .padding(.horizontal)
                .padding(.bottom, 40)
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
                // 1. Get ID Token & Nonce from Apple
                let (idToken, nonce) = try await AppleSignInManager.shared.handleSignIn(with: result)
                
                // 2. Sign in to Supabase
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

#Preview {
    LoginView(isAuthenticated: .constant(false))
}
