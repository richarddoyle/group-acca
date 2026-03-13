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
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.badge.ellipsis")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            
                            if selectedImageData != nil {
                                Text("Profile Picture Selected")
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Set Group Profile Picture")
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                    
                    TextField("Group Name", text: $groupName)
                }
                
                if let error = errorMessage {
                    Section {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.primary)
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
