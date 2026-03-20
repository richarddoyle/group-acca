import SwiftUI
import PhotosUI

// MARK: - Color Helper
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

// MARK: - Step Model

private enum OnboardingStep {
    case profile
    case groupChoice
    case joinGroup
    case joinedGroup(BettingGroup)

    var index: Int {
        switch self {
        case .profile:      return 0
        case .groupChoice:  return 1
        case .joinGroup:    return 2
        case .joinedGroup:  return 3
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    var onComplete: (BettingGroup?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var step: OnboardingStep = .profile

    // Profile step
    @State private var username: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSavingProfile = false
    @State private var profileError: String?

    // Join step
    @State private var joinCode: String = ""
    @State private var isJoining = false
    @State private var joinError: String?

    // Create group step
    @State private var showingCreateGroup = false
    @State private var isCreatingGroup = false
    @State private var createGroupError: String?

    // Tracks which onboarding flow was used (read by DashboardView coach marks)
    @AppStorage("onboardingCreatedGroup") private var onboardingCreatedGroup = false

    private var bg: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7")
    }
    private let green = Color(hex: "2FAF4F")
    private let navy  = Color(hex: "071321")

    private var primaryText: Color {
        colorScheme == .dark ? Color(hex: "F2F2F7") : navy
    }

    // MARK: - Username validation

    private var usernameError: String? {
        username.count > 20 ? "Username must be 20 characters or less" : nil
    }

    private var canContinue: Bool {
        username.count >= 3 && usernameError == nil && !isSavingProfile
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            switch step {
            case .profile:
                profileStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            case .groupChoice:
                groupChoiceStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            case .joinGroup:
                joinGroupStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .joinedGroup(let group):
                joinedGroupStep(group: group)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step.index)
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView { groupName, imageData in
                createGroup(name: groupName, imageData: imageData)
            }
        }
    }

    // MARK: - Screen 1: Create your profile

    private var profileStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Text("Create your profile")
                .font(.custom("BarlowCondensed-Medium", size: 36))
                .foregroundStyle(primaryText)
                .padding(.bottom, 40)

            // Photo picker
            ZStack {
                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        )
                }

                Circle()
                    .fill(green)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 40, y: 40)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text(selectedImageData == nil ? "Add photo" : "Change photo")
                    .font(.subheadline)
                    .foregroundStyle(green)
            }
            .padding(.top, 14)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { selectedImageData = data }
                    }
                }
            }

            // Username field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Your name", text: $username)
                    .font(.custom("BarlowCondensed-Medium", size: 20))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = usernameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                } else if let error = profileError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Spacer()

            Button {
                saveProfile()
            } label: {
                Group {
                    if isSavingProfile {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .font(.custom("BarlowCondensed-Medium", size: 22))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canContinue ? green : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Screen 2: You're almost in!

    private var groupChoiceStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Text("You're almost in!")
                .font(.custom("BarlowCondensed-Medium", size: 36))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryText)
                .padding(.bottom, 48)

            VStack(spacing: 16) {
                // Join a group
                Button {
                    withAnimation { step = .joinGroup }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Join a group")
                                .font(.custom("BarlowCondensed-Medium", size: 22))
                            Text("Enter an invite code from a friend")
                                .font(.caption)
                                .opacity(0.75)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Create a group
                Button {
                    showingCreateGroup = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Create a group")
                                .font(.custom("BarlowCondensed-Medium", size: 22))
                            Text("Set up your own group and invite mates")
                                .font(.caption)
                                .opacity(0.75)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(primaryText)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .overlay {
                    if isCreatingGroup {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground).opacity(0.7))
                        ProgressView()
                    }
                }

                if let error = createGroupError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onComplete(nil)
            } label: {
                Text("I'll do this later")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Join a group (inline)

    private var joinGroupStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Text("Join a group")
                .font(.custom("BarlowCondensed-Medium", size: 36))
                .foregroundStyle(primaryText)
                .padding(.bottom, 12)

            Text("Ask the group admin for the invite code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 8) {
                TextField("e.g. EE3F7C", text: $joinCode)
                    .font(.custom("BarlowCondensed-Medium", size: 28))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .tracking(6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(joinError != nil ? Color.red : Color.clear, lineWidth: 1.5)
                    )
                    .onChange(of: joinCode) { _, _ in
                        // Clear error when user edits the code
                        if joinError != nil { joinError = nil }
                    }

                Text("Code format: alphanumeric e.g. EE3F7C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if let error = joinError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    joinGroup()
                } label: {
                    Group {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join group")
                                .font(.custom("BarlowCondensed-Medium", size: 22))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(!joinCode.isEmpty && !isJoining ? green : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(joinCode.isEmpty || isJoining)

                Button {
                    joinError = nil
                    withAnimation { step = .groupChoice }
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Joined group successfully

    private func joinedGroupStep(group: BettingGroup) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Avatar or tick fallback
            ZStack(alignment: .bottomTrailing) {
                if let avatarUrl = group.avatarUrl {
                    CachedImage(url: avatarUrl) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.title)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())

                    // Green checkmark badge
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(green)
                        .background(
                            Circle().fill(bg).padding(-3)
                        )
                        .offset(x: 4, y: 4)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(green)
                }
            }
            .padding(.bottom, 28)

            Text("You've joined")
                .font(.custom("BarlowCondensed-Medium", size: 26))
                .foregroundStyle(primaryText)

            Text(group.name)
                .font(.custom("BarlowCondensed-Medium", size: 44))
                .foregroundStyle(green)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            Text("You're all set — let's get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Spacer()

            Button {
                onComplete(group)
            } label: {
                Text("Let's go")
                    .font(.custom("BarlowCondensed-Medium", size: 22))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
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
                    withAnimation { step = .groupChoice }
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    profileError = error.localizedDescription
                }
            }
        }
    }

    private func joinGroup() {
        isJoining = true
        joinError = nil

        Task {
            do {
                let userId = SupabaseService.shared.currentUserId
                let profile = try await SupabaseService.shared.fetchProfile(id: userId)
                let group = try await SupabaseService.shared.joinGroup(
                    code: joinCode,
                    userName: profile.username,
                    userId: userId
                )
                await MainActor.run {
                    isJoining = false
                    withAnimation { step = .joinedGroup(group) }
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    joinError = error.localizedDescription
                }
            }
        }
    }

    private func createGroup(name: String, imageData: Data?) {
        isCreatingGroup = true
        createGroupError = nil
        showingCreateGroup = false

        Task {
            do {
                let userId = SupabaseService.shared.currentUserId
                var avatarUrl: String?
                if let data = imageData {
                    avatarUrl = try await SupabaseService.shared.uploadAvatar(imageData: data, userId: userId)
                }
                let group = try await SupabaseService.shared.createGroup(
                    name: name,
                    stake: 5.0,
                    avatarUrl: avatarUrl
                )
                await MainActor.run {
                    isCreatingGroup = false
                    onboardingCreatedGroup = true
                    onComplete(group)
                }
            } catch {
                await MainActor.run {
                    isCreatingGroup = false
                    createGroupError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
