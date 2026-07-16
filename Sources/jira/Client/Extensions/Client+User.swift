import Foundation

extension Jira {
    func user() async {
        do {
            let result: Result<UserModel, Error> = try await request(configuration: makeRequest("/rest/api/2/myself"))
            switch result {
            case .success(let response):
                var table = Table(title: "User information", columns: [
                    Table.Column("Mail"),
                    Table.Column("Login", width: 14),
                    Table.Column("Active", width: 6),
                    Table.Column("Key", width: 16)
                ])
                table.addRow([
                    response.emailAddress ?? "",
                    response.name ?? "",
                    "\(response.active ?? false)",
                    response.key ?? ""
                ])
                print(table.render())
            case .failure(let error):
                fputs("Failed to fetch user: \(error)\n", stderr)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
        }
    }
}
