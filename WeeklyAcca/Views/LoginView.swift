import AuthenticationServices
import SwiftUI
import Supabase

struct LoginView: View {
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var showingError = false
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        ZStack {
            // Background Gradients
            VStack {
                LinearGradient(colors: [Color.accentColor, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
                LinearGradient(colors: [.clear, Color.accentColor], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
            }
            .ignoresSafeArea()
            
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
                        .padding(.bottom, 10) // 1. Added padding
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Bet Together,")
                        Text("Win Together.")
                    }
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                }
                
            }
            
            Spacer()
            
            // Features Rows (Moved down, changed to HStack rows)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "person.3") // SF Symbol
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    
                    Text("Create group accumulators")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary) // Darkened text
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
                
                HStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis") // SF Symbol
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    
                    Text("Track results live")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary) // Darkened text
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
                
                HStack(spacing: 16) {
                    Image(systemName: "trophy") // SF Symbol
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    
                    Text("Compete with your friends")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary) // Darkened text
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
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
