import Foundation

extension Jira {
    func request<T: Decodable>(configuration: URLRequest) async throws -> Result<T, Error> {
        do {
            let session = URLSession.shared
            let (data, _) = try await session.data(for: configuration)
//            print(String(data: data, encoding: .utf8))
            return try .success(JSONDecoder().decode(T.self, from: data))
        } catch {
            print(error)
            return .failure(error)
        }
    }

    func makeRequest(_ path: String) -> URLRequest {
        let url = URL(string: "\(domain)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        return request
    }

    func makeRequestPOST(_ path: String, body: [String: Any]) -> URLRequest {
        let url = URL(string: "\(domain)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !body.isEmpty {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }

        return request
    }
}
