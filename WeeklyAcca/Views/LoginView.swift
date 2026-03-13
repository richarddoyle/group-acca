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
            
            VStack(spacing: 40) {
                // Stacked Logo and Tagline
                VStack(spacing: 0) {
                    Image("GroupAccaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.bottom, -15)
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Bet Together,")
                        Text("Win Together.")
                    }
                    .font(.largeTitle)
                    .bold()
                }
                
                // Features Columns
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 30)
                        
                        Text("Create group accumulators")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 30)
                        
                        Text("Track results live")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 30)
                        
                        Text("Compete with your friends")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
            }
            
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
