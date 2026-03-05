import SwiftUI
import PhotosUI
import CoreTransferable
import StoreKit

struct ProfileView: View {
    @Binding var selectedGroup: BettingGroup?
    @Binding var isAuthenticated: Bool
    
    @State private var groups: [BettingGroup] = []
    @State private var profile: Profile?
    @State private var editingUsername: String = ""
    @State private var editingPhone: String = ""
    @State private var selectedItem: PhotosPickerItem?
    
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isUploading = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @State private var fieldToEdit: EditField? = nil
    
    enum EditField: String, Identifiable {
        case username = "Name"
        case phoneNumber = "Phone Number"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
                List {
                Section {
                    VStack(spacing: 20) {
                        // Profile Picture
                        ZStack {
                            if isUploading {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 180, height: 180)
                                ProgressView()
                                    .scaleEffect(1.5)
                            } else {
                                ProfileImage(url: profile?.avatarUrl, size: 180)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.badge.ellipsis")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            
                            Text("Set Profile Photo")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(isUploading)
                    
                    ProfileRow(
                        value: profile?.username ?? "Not set",
                        icon: "person.fill"
                    ) {
                        fieldToEdit = .username
                    }
                    
                    ProfileRow(
                        value: profile?.phoneNumber ?? "Not set",
                        icon: "phone.fill"
                    ) {
                        fieldToEdit = .phoneNumber
                    }
                }
                
                Section("App Settings") {
                    ProfileRow(
                        value: "Notifications",
                        icon: "bell.badge.fill"
                    ) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    ProfileRow(
                        value: "Leave a Review",
                        icon: "star.fill"
                    ) {
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    }
                    
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button(action: {
                        Task {
                            try? await SupabaseService.shared.signOut()
                            await MainActor.run { isAuthenticated = false }
                        }
                    }) {
                        Text("Sign Out")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $fieldToEdit) { field in
                EditProfileFieldView(
                    field: field,
                    initialValue: field == .username ? (profile?.username ?? "") : (profile?.phoneNumber ?? ""),
                    onSave: { newValue in
                        updateField(field, value: newValue)
                    }
                )
            }
            .refreshable {
                await loadData()
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem {
                    uploadPhoto(newItem)
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            let userId = SupabaseService.shared.currentUserId
            async let fetchedGroups = SupabaseService.shared.fetchGroups(for: userId)
            async let fetchedProfile = SupabaseService.shared.fetchProfile(id: userId)
            
            let (gs, p) = try await (fetchedGroups, fetchedProfile)
            
            await MainActor.run {
                self.groups = gs
                self.profile = p
                self.editingUsername = p.username
                self.editingPhone = p.phoneNumber ?? ""
                isLoading = false
            }
        } catch {
            print("Error loading data: \(error)")
            isLoading = false
        }
    }
    
    private func updateField(_ field: EditField, value: String) {
        guard var updatedProfile = profile else { return }
        switch field {
        case .username: updatedProfile.username = value
        case .phoneNumber: updatedProfile.phoneNumber = value
        }
        
        Task {
            do {
                try await SupabaseService.shared.updateProfile(updatedProfile)
                await MainActor.run {
                    self.profile = updatedProfile
                    if field == .username { self.editingUsername = value }
                    else { self.editingPhone = value }
                }
            } catch {
                print("Error saving profile: \(error)")
            }
        }
    }
    
    private func uploadPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                await MainActor.run { isUploading = true }
                
                var imageData: Data?
                
                // Try loading as Data first
                do {
                    imageData = try await item.loadTransferable(type: Data.self)
                } catch {
                    print("⚠️ Data transfer failed, trying UIImage fallback: \(error)")
                }
                
#if canImport(UIKit)
                // Fallback to UIImage if Data fails
                if imageData == nil {
                    if let uiImage = try await item.loadTransferable(type: UIImage.self) {
                        imageData = uiImage.jpegData(compressionQuality: 0.8)
                    }
                }
#endif
                
                guard let finalData = imageData else {
                    throw NSError(domain: "ProfileView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract image data. Please try a different photo."])
                }
                
                let url = try await SupabaseService.shared.uploadAvatar(imageData: finalData, userId: SupabaseService.shared.currentUserId)
                
                if var updatedProfile = profile {
                    updatedProfile.avatarUrl = url
                    try await SupabaseService.shared.updateProfile(updatedProfile)
                    await MainActor.run {
                        self.profile = updatedProfile
                    }
                }
                
                await MainActor.run { isUploading = false }
            } catch {
                print("❌ Final upload error: \(error)")
                await MainActor.run {
                    self.errorTitle = "Upload Failed"
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isUploading = false
                }
            }
        }
    }
    
    private func loadGroups() async {
        // Redundant with loadData, but used in sheets. Let's keep it for now or refactor calls.
        await loadData()
    }
}

// MARK: - Helper Views

struct ProfileRow: View {
    let value: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                
                Text(value)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EditProfileFieldView: View {
    let field: ProfileView.EditField
    let initialValue: String
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var value: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(field.rawValue)) {
                    TextField(field.rawValue, text: $value)
                        .keyboardType(field == .phoneNumber ? .phonePad : .default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(field == .username ? .words : .none)
                }
            }
            .navigationTitle("Edit \(field.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(value)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                value = initialValue
            }
        }
        .presentationDetents([.height(200)])
    }
}

#if canImport(UIKit)
extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { image in
            image.jpegData(compressionQuality: 0.8) ?? Data()
        }
    }
}
#endif
