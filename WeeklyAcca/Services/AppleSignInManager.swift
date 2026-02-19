import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    
    private var currentNonce: String?
    
    // Adapted from Supabase Auth Docs
    func handleSignIn(with result: Result<ASAuthorization, Error>) async throws -> (idToken: String, nonce: String) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                throw AppleSignInError.invalidCredential
            }
            
            guard let nonce = currentNonce else {
                throw AppleSignInError.missingNonce
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                throw AppleSignInError.missingIdentityToken
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AppleSignInError.invalidIdentityToken
            }
            
            return (idTokenString, nonce)
            
        case .failure(let error):
            throw error
        }
    }
    
    func request() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        
        return request
    }
    
    // MARK: - Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }.reduce("") { partialResult, char in
             partialResult + String(char)
        }
        
        return nonce
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

enum AppleSignInError: Error {
    case invalidCredential
    case missingNonce
    case missingIdentityToken
    case invalidIdentityToken
}
