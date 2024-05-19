import Foundation
import WebKit

extension Jira {
    func auth() async -> Bool {
        let cookies = cookiesManager.loadCookies() ?? []
        if cookies.count > 3 {
            HTTPCookieStorage.shared.setCookies(cookies, for: URL(string: domain), mainDocumentURL: nil)
            return true
        }
        return await withCheckedContinuation { [self] continuation in
            self.continuation = continuation
            sso()
        }
    }

    private func sso() {
        DispatchQueue.main.async {
            self.webView = WKWebView()
            self.webView?.navigationDelegate = self
            self.webView?.uiDelegate = self
            if let url = URL(string: self.domain) {
                _ = self.webView?.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
            }
        }
    }
}

extension Jira: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            HTTPCookieStorage.shared.setCookies(cookies,
                                                for: webView.url!,
                                                mainDocumentURL: nil)
            self.cookiesManager.saveCookies(HTTPCookieStorage.shared.cookies ?? [])
            self.continuation?.resume(returning: true)
        }
    }

    public func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}
