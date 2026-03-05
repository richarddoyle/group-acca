import SwiftUI
import PhotosUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, Data?) -> Void
    
    @State private var groupName: String = ""
    @State private var errorMessage: String?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading = false
    
    init(onCreate: @escaping (String, Data?) -> Void) {
        self.onCreate = onCreate
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.title)
                                    )
                            }
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Group Details") {
                    TextField("Group Name", text: $groupName)
                }
                
                if let error = errorMessage {
                    Section {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Betting Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isUploading = true
                        onCreate(groupName, selectedImageData)
                        // dismiss() will be handled by the parent
                    }
                    .disabled(groupName.isEmpty || isUploading)
                }
            }
        }
    }
}

#Preview {
    CreateGroupView(onCreate: { _, _ in })
}
