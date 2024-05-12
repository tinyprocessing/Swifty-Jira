import Foundation
import SwiftyTextTable

extension Jira {
    func user() async {
        do {
            let result: Result<UserModel, Error> = try await request(configuration: makeRequest("/rest/api/2/myself"))
            switch result {
            case let .success(response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Mail"),
                    TextTableColumn(header: "Login"),
                    TextTableColumn(header: "Active"),
                    TextTableColumn(header: "Key"),
                ], header: "User information")
                table.addRow(values: [
                    response.emailAddress ?? "",
                    response.name ?? "",
                    response.active ?? false,
                    response.key ?? "",
                ])
                print(table.render())
            case .failure:
                break
            }
        } catch {}
    }
}
