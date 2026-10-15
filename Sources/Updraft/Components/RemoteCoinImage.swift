import SwiftUI
import UIKit

/// In-memory logo cache on top of URLSession's disk cache.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]

    func cached(_ url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func image(_ url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        if let task = inflight[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
        }
        inflight[url] = task
        let image = await task.value
        inflight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// A remote coin logo that shows `fallback` until (or unless) it loads.
struct RemoteCoinImage<Fallback: View>: View {
    let url: URL
    let size: CGFloat
    @ViewBuilder let fallback: () -> Fallback
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image ?? ImageCache.shared.cached(url) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallback()
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            let loaded = await ImageCache.shared.image(url)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}
