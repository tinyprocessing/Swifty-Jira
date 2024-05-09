import Foundation

class CookieManager {
    private let defaultCookieFilePath = FileManager.default.urls(for: .applicationSupportDirectory,
                                                                 in: .userDomainMask).first!.appendingPathComponent("cookies.txt")

    func saveCookies(_ cookies: [HTTPCookie]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true) else {
            return
        }

        do {
            try data.write(to: defaultCookieFilePath)
        } catch {}
    }

    func loadCookies() -> [HTTPCookie]? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: defaultCookieFilePath.path)
            if let modificationDate = fileAttributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modificationDate) > 7200
            {
                try FileManager.default.removeItem(at: defaultCookieFilePath)
                return []
            }
        } catch {
            return nil
        }

        guard let data = try? Data(contentsOf: defaultCookieFilePath) else {
            return nil
        }

        do {
            guard let cookies = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie] else {
                return nil
            }

            return cookies
        } catch {
            return nil
        }
    }

    func removeExpiredCookies() {
        saveCookies([])
    }
}
