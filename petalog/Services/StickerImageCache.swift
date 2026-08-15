import CryptoKit
import Foundation
import UIKit

final class CachedStickerImage: @unchecked Sendable {
    let image: UIImage

    nonisolated init(image: UIImage) {
        self.image = image
    }
}

actor StickerImageCache {
    static let shared = StickerImageCache()

    private static let maximumDownloadBytes = 2 * 1024 * 1024
    private static let memoryLimit = 32 * 1024 * 1024
    private static let diskLimit = 100 * 1024 * 1024
    private static let maximumDiskAge: TimeInterval = 30 * 24 * 60 * 60

    private let memoryCache = NSCache<NSString, CachedStickerImage>()
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var hasPreparedDiskCache = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.cacheDirectory = baseDirectory.appendingPathComponent("petalog-sticker-images", isDirectory: true)
        memoryCache.totalCostLimit = Self.memoryLimit
    }

    func image(for url: URL) async throws -> CachedStickerImage {
        prepareDiskCacheIfNeeded()
        let key = url.absoluteString
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        if let data = loadDiskData(forKey: key), let cached = makeCachedImage(from: data) {
            memoryCache.setObject(cached, forKey: key as NSString, cost: memoryCost(of: cached.image))
            return cached
        }

        let task: Task<Data, Error>
        if let existingTask = inFlight[key] {
            task = existingTask
        } else {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            let newTask = Task {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let response = response as? HTTPURLResponse,
                   !(200...299).contains(response.statusCode) {
                    throw URLError(.badServerResponse)
                }
                guard !data.isEmpty, data.count <= Self.maximumDownloadBytes else {
                    throw URLError(.dataLengthExceedsMaximum)
                }
                return data
            }
            inFlight[key] = newTask
            task = newTask
        }

        let data: Data
        do {
            data = try await task.value
            inFlight[key] = nil
        } catch {
            inFlight[key] = nil
            throw error
        }

        guard let cached = makeCachedImage(from: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        memoryCache.setObject(cached, forKey: key as NSString, cost: memoryCost(of: cached.image))
        saveDiskData(data, forKey: key)
        pruneDiskCache()
        return cached
    }

    func store(data: Data, for url: URL) {
        guard !data.isEmpty,
              data.count <= Self.maximumDownloadBytes,
              let cached = makeCachedImage(from: data) else { return }
        prepareDiskCacheIfNeeded()
        let key = url.absoluteString
        memoryCache.setObject(cached, forKey: key as NSString, cost: memoryCost(of: cached.image))
        saveDiskData(data, forKey: key)
        pruneDiskCache()
    }

    func remove(for url: URL) {
        let key = url.absoluteString
        memoryCache.removeObject(forKey: key as NSString)
        inFlight[key]?.cancel()
        inFlight[key] = nil
        try? fileManager.removeItem(at: fileURL(forKey: key))
    }

    private func prepareDiskCacheIfNeeded() {
        guard !hasPreparedDiskCache else { return }
        hasPreparedDiskCache = true
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        pruneDiskCache()
    }

    private func makeCachedImage(from data: Data) -> CachedStickerImage? {
        guard let image = UIImage(data: data) else { return nil }
        return CachedStickerImage(image: image)
    }

    private func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    private func loadDiskData(forKey key: String) -> Data? {
        let fileURL = fileURL(forKey: key)
        guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modificationDate = values.contentModificationDate,
              Date().timeIntervalSince(modificationDate) <= Self.maximumDiskAge,
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty,
              data.count <= Self.maximumDownloadBytes else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return data
    }

    private func saveDiskData(_ data: Data, forKey key: String) {
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDirectory.appendingPathComponent(digest).appendingPathExtension("png")
    }

    private func pruneDiskCache() {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        var files: [(url: URL, size: Int, date: Date)] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            let date = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(date) > Self.maximumDiskAge {
                try? fileManager.removeItem(at: url)
                continue
            }
            files.append((url, values.fileSize ?? 0, date))
        }

        var totalSize = files.reduce(0) { $0 + $1.size }
        guard totalSize > Self.diskLimit else { return }
        for file in files.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= Self.diskLimit { break }
        }
    }
}
