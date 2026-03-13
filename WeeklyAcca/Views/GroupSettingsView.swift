import SwiftUI
import PhotosUI

struct GroupSettingsView: View {
    @Binding var group: BettingGroup
    var onLeaveGroup: () -> Void
    
    @State private var groupName: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showingLeaveAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var showCopyToast = false
    
    @State private var isEditingName = false
    @State private var isSaving = false
    
    // Derived to know if current user can edit name/photo
    var isAdmin: Bool {
        group.adminId == SupabaseService.shared.currentUserId
    }
    
    init(group: Binding<BettingGroup>, onLeaveGroup: @escaping () -> Void) {
        self._group = group
        self.onLeaveGroup = onLeaveGroup
        self._groupName = State(initialValue: group.wrappedValue.name)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        VStack(spacing: 20) {
                            ZStack {
                                if isUploading {
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 180, height: 180)
                                    ProgressView()
                                        .scaleEffect(1.5)
                                } else {
                                    avatarView
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                    
                    Section {
                        if isAdmin {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                HStack(spacing: 12) {
                                    Image(systemName: "camera.badge.ellipsis")
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 24)
                                    
                                    Text("Set Group Profile Picture")
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .disabled(isUploading)
                        }
                        
                        // Name Row
                        Button {
                            if isAdmin { isEditingName = true }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 24)
                                
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if isAdmin {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAdmin)
                    }
                    
                    Section("Group Details") {
                        HStack {
                            Text("Join Code")
                            Spacer()
                            Text(group.joinCode)
                                .foregroundStyle(.secondary)
                            Button(action: {
                                UIPasteboard.general.string = group.joinCode
                                withAnimation { showCopyToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopyToast = false }
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .accessibilityLabel("Copy Join Code")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        if isAdmin {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Text("Delete Group")
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            Button(role: .destructive) {
                                showingLeaveAlert = true
                            } label: {
                                Text("Leave Group")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Leave Group", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveGroup()
                }
            } message: {
                Text("Are you sure you want to leave this group?")
            }
            .alert("Delete Group", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("Are you sure you want to delete this group? This action cannot be undone.")
            }
            .alert("Update Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred.")
            }
            .sheet(isPresented: $isEditingName) {
                EditProfileFieldView(
                    field: .username, // Re-use username as a generic text field
                    initialValue: group.name,
                    onSave: { newName in
                        updateGroupName(newName)
                    }
                )
            }
            .onChange(of: selectedItem) { _, newItem in
                if let newItem {
                    uploadPhoto(newItem)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopyToast {
                Text("Copied to clipboard")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
                    .zIndex(1)
            }
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let urlString = group.avatarUrl {
            CachedImage(url: urlString) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholderAvatar
            }
            .frame(width: 180, height: 180)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 180, height: 180)
            .overlay(
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 60))
            )
    }
    
    private func updateGroupName(_ newName: String) {
        guard isAdmin, !newName.isEmpty, newName != group.name else { return }
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                var updatedGroup = group
                updatedGroup.name = newName
                try await SupabaseService.shared.updateGroup(updatedGroup)
                
                await MainActor.run {
                    self.group = updatedGroup
                    self.groupName = newName
                    self.isSaving = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isSaving = false
                }
            }
        }
    }
    
    private func uploadPhoto(_ item: PhotosPickerItem) {
        guard isAdmin else { return }
        
        Task {
            do {
                await MainActor.run { isUploading = true }
                
                var imageData: Data?
                do {
                    imageData = try await item.loadTransferable(type: Data.self)
                } catch {
                    print("⚠️ Data transfer failed, trying UIImage fallback: \(error)")
                }
                
#if canImport(UIKit)
                if imageData == nil {
                    if let uiImage = try await item.loadTransferable(type: UIImage.self) {
                        imageData = uiImage.jpegData(compressionQuality: 0.8)
                    }
                }
#endif
                guard let finalData = imageData else {
                    throw NSError(domain: "GroupSettingsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract image data. Please try a different photo."])
                }
                
                let userId = SupabaseService.shared.currentUserId
                let url = try await SupabaseService.shared.uploadAvatar(imageData: finalData, userId: userId)
                
                var updatedGroup = group
                updatedGroup.avatarUrl = url
                
                try await SupabaseService.shared.updateGroup(updatedGroup)
                
                await MainActor.run {
                    self.group = updatedGroup
                    self.isUploading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isUploading = false
                }
            }
        }
    }
    
    private func leaveGroup() {
        isSaving = true
        Task {
            do {
                try await SupabaseService.shared.leaveGroup(
                    groupId: group.id,
                    userId: SupabaseService.shared.currentUserId
                )
                await MainActor.run {
                    isSaving = false
                    onLeaveGroup()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to leave group: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
    
    private func deleteGroup() {
        isSaving = true
        Task {
            do {
                try await SupabaseService.shared.deleteGroup(id: group.id)
                await MainActor.run {
                    isSaving = false
                    onLeaveGroup()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete group: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}
