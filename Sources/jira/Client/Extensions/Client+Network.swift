import Foundation

extension Jira {
    func request<T: Decodable>(configuration: URLRequest) async throws -> Result<T, Error> {
        do {
            let session = URLSession.shared
            let (data, _) = try await session.data(for: configuration)
            return try .success(JSONDecoder().decode(T.self, from: data))
        } catch {
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
}
