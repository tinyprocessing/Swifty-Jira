import Foundation
import SwiftyTextTable
import WebKit

protocol Client {
    func auth() async -> Bool
    func user() async
    func project(key: String) async
    func issues(filter: String) async
    func issue(id: String) async
    func transition(to status: String, key: String, resolution: String) async
    func create(parent: String, summary: String, project: String, assignee: String) async
}

public class Jira: NSObject, Client {
    var continuation: CheckedContinuation<Bool, Never>?
    var webView: WKWebView?

    let domain: String
    let cookiesManager = CookieManager()

    init(domain: String) {
        self.domain = domain
        super.init()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
