import SwiftUI
import PhotosUI

struct OnboardingView: View {
    var onComplete: (BettingGroup?) -> Void

    // Profile step
    @State private var username: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSavingProfile = false
    @State private var profileError: String?

    // MARK: - Username validation

    private var usernameError: String? {
        username.count > 20 ? "Username must be 20 characters or less" : nil
    }

    private var canContinue: Bool {
        username.count >= 3 && usernameError == nil && !isSavingProfile
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 20) {
                        ZStack {
                            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 60))
                                            .foregroundStyle(.secondary)
                                    )
                            }

                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                )
                                .offset(x: 48, y: 48)
                        }

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text(selectedImageData == nil ? "Add Photo" : "Change Photo")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowBackground(Color.clear)
                
                Section("Your Name") {
                    TextField("Enter your name", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    
                    if let error = usernameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let error = profileError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Button(action: {
                        saveProfile()
                    }) {
                        HStack {
                            Spacer()
                            if isSavingProfile {
                                ProgressView()
                            } else {
                                Text("Continue")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canContinue)
                }
            }
            .navigationTitle("Set up profile")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { selectedImageData = data }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveProfile() {
        isSavingProfile = true
        profileError = nil

        Task {
            do {
                let userId = SupabaseService.shared.currentUserId
                var profile = try await SupabaseService.shared.fetchProfile(id: userId)
                profile.username = username

                if let data = selectedImageData {
                    let url = try await SupabaseService.shared.uploadAvatar(imageData: data, userId: userId)
                    profile.avatarUrl = url
                }

                try await SupabaseService.shared.updateProfile(profile)

                await MainActor.run {
                    isSavingProfile = false
                    onComplete(nil)
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    profileError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
