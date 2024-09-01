import Foundation

extension Jira {
    func assignee(key: String, accountId: String) async {
        do {
            let parameters: [String: Any] = [
                "name": accountId
            ]
            let request = makeRequestCustom("/rest/api/2/issue/\(key)/assignee", body: parameters, httpMethod: "PUT")
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8) ?? "")
        } catch {
            print(error)
        }
    }
}
