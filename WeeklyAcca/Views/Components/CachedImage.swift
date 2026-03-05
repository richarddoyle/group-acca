import SwiftUI
import Combine

class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isLoading = false
    
    // Track the currently loading URL to prevent stale network returns overwriting newer requests
    private var currentUrlString: String?
    
    func load(url urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            self.image = nil
            self.currentUrlString = nil
            return
        }
        
        self.currentUrlString = urlString
        
        // Return instantly if cached
        if let cachedImage = ImageCache.shared.image(for: urlString) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // Otherwise download - clear old bounds to prevent flashing cell re-use
        self.image = nil
        self.isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Ensure this response is still for the current URL
                guard self.currentUrlString == urlString else { return }
                
                if let downloadedImage = UIImage(data: data) {
                    // Update cache
                    ImageCache.shared.insert(downloadedImage, for: urlString)
                    
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { isLoading = false }
                }
            } catch {
                print("Failed to load image from \(urlString): \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct CachedImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    init(url: String?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let urlString = url, let memoryImage = ImageCache.shared.memoryImage(for: urlString) {
                content(Image(uiImage: memoryImage))
            } else if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(url: url)
        }
        // Allows it to refresh if the URL string changes (e.g., cell reuse in a list)
        .onChange(of: url) { _, newUrl in
            loader.load(url: newUrl)
        }
    }
}
