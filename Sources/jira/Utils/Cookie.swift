import Foundation

/// Persists HTTP cookies to disk as a plist of their raw properties.
/// `HTTPCookie` is not NSSecureCoding-compliant, so we serialize
/// `cookie.properties` (a dictionary) instead of archiving the objects.
class CookieManager {
    private let defaultCookieFilePath = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("cookies.plist")

    private let maxAgeSeconds: TimeInterval = 604_800  // 7 days

    func clean() {
        do {
            try FileManager.default.removeItem(at: defaultCookieFilePath)
            fputs("Cached session cleared.\n", stderr)
        } catch {
            fputs("Error deleting cookie file: \(error)\n", stderr)
        }
    }

    func saveCookies(_ cookies: [HTTPCookie]) {
        let dicts: [[String: Any]] = cookies.compactMap { cookie in
            guard let props = cookie.properties else { return nil }
            var stringKeyed: [String: Any] = [:]
            for (key, value) in props {
                stringKeyed[key.rawValue] = value
            }
            return stringKeyed
        }
        guard !dicts.isEmpty else { return }
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: dicts, format: .binary, options: 0
            )
            try data.write(to: defaultCookieFilePath)
        } catch {
            fputs("[cookie] save error: \(error)\n", stderr)
        }
    }

    func loadCookies() -> [HTTPCookie]? {
        // Expire the cache after maxAgeSeconds based on file modification time.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: defaultCookieFilePath.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) > maxAgeSeconds {
            try? FileManager.default.removeItem(at: defaultCookieFilePath)
            return []
        }

        guard let data = try? Data(contentsOf: defaultCookieFilePath) else {
            return nil
        }

        do {
            guard let dicts = try PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            ) as? [[String: Any]] else {
                return nil
            }
            let cookies: [HTTPCookie] = dicts.compactMap { dict in
                var props: [HTTPCookiePropertyKey: Any] = [:]
                for (key, value) in dict {
                    props[HTTPCookiePropertyKey(key)] = value
                }
                return HTTPCookie(properties: props)
            }
            return cookies
        } catch {
            fputs("[cookie] decode error: \(error)\n", stderr)
            return nil
        }
    }

    func removeExpiredCookies() {
        try? FileManager.default.removeItem(at: defaultCookieFilePath)
    }
}
