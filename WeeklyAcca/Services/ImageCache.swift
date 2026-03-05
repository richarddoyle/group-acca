import SwiftUI
import Foundation

class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private init() {
        memoryCache.countLimit = 100 // Manage memory limits proactively
    }
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    
    private func getCacheFileURL(for key: String) -> URL {
        // Hash the URL or use base64 and make it filesystem safe
        let base64String = key.data(using: .utf8)?.base64EncodedString() ?? key
        
        let safeKey = "v2_" + base64String
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            
        return cacheDirectory.appendingPathComponent(safeKey)
    }
    
    func memoryImage(for urlString: String) -> UIImage? {
        let key = urlString as NSString
        return memoryCache.object(forKey: key)
    }
    
    func image(for urlString: String) -> UIImage? {
        let key = urlString as NSString
        
        // 1. Check memory cache (fastest)
        if let memoryImage = memoryCache.object(forKey: key) {
            return memoryImage
        }
        
        // 2. Check disk cache
        let fileURL = getCacheFileURL(for: urlString)
        if let data = try? Data(contentsOf: fileURL), let diskImage = UIImage(data: data) {
            // Restore to memory cache for next time
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        return nil
    }
    
    func insert(_ image: UIImage, for urlString: String) {
        let key = urlString as NSString
        
        // 1. Save to memory
        memoryCache.setObject(image, forKey: key)
        
        // 2. Save to disk (background thread)
        let fileURL = getCacheFileURL(for: urlString)
        Task.detached(priority: .background) {
            if let data = image.pngData() {
                try? data.write(to: fileURL)
            }
        }
    }
}
