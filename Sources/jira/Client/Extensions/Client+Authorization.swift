import Foundation
import WebKit

extension Jira {
    func auth() async -> Bool {
        let cookies = cookiesManager.loadCookies() ?? []
        if cookies.count > 3 {
            HTTPCookieStorage.shared.setCookies(cookies, for: URL(string: domain), mainDocumentURL: nil)
            return true
        }
        // Fail fast in non-interactive mode (e.g. invoked by Claude/scripts):
        // opening a WebKit window would hang forever with no display.
        if ProcessInfo.processInfo.environment["SWIFTY_JIRA_NONINTERACTIVE"] != nil {
            fputs("Not authenticated (no valid cached session). Run `swifty-jira user info` in a terminal to log in, then retry.\n", stderr)
            exit(2)
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
    public func webView(_ webView: WKWebView, didFinish naviagtion: WKNavigation!) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            HTTPCookieStorage.shared.setCookies(cookies,
                                                for: webView.url!,
                                                mainDocumentURL: nil)
            self.cookiesManager.saveCookies(HTTPCookieStorage.shared.cookies ?? [])
            let verificationString: String = (webView.url?.absoluteString ?? "")
            fputs("[auth] \(verificationString)\n", stderr)
            if verificationString.contains("RapidBoard.jspa") {
                self.continuation?.resume(returning: true)
                return
            }
            if verificationString.contains("Dashboard.jspa") {
                self.continuation?.resume(returning: true)
                return
            }
        }
    }

    public func webView(
        _: WKWebView,
        decidePolicyFor _: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }
}
