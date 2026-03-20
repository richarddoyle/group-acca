import SwiftUI
import PhotosUI

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

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var onCreate: (String, Data?) -> Void

    @State private var groupName: String = ""
    @State private var errorMessage: String?
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading = false

    private var bg: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7")
    }
    private let green = Color(hex: "2FAF4F")
    private let navy  = Color(hex: "071321")
    private var primaryText: Color {
        colorScheme == .dark ? Color(hex: "F2F2F7") : navy
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                Text("Name your group")
                    .font(.custom("BarlowCondensed-Medium", size: 36))
                    .foregroundStyle(primaryText)
                    .padding(.bottom, 40)

                // Group avatar circle with camera badge
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
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 42))
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

                // Group name field
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Group name", text: $groupName)
                        .font(.custom("BarlowCondensed-Medium", size: 20))
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        isUploading = true
                        onCreate(groupName, selectedImageData)
                    } label: {
                        Group {
                            if isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create group")
                                    .font(.custom("BarlowCondensed-Medium", size: 22))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(!groupName.isEmpty && !isUploading ? green : Color(.systemGray4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(groupName.isEmpty || isUploading)

                    Button {
                        dismiss()
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
    }
}

#Preview {
    CreateGroupView(onCreate: { _, _ in })
}
