import Foundation

extension Jira {
    func project(key: String = "") async {
        if key.isEmpty {
            do {
                let result: Result<[Project], Error> =
                    try await request(configuration: makeRequest("/rest/api/2/project"))
                switch result {
                case .success(let response):
                    var table = Table(title: "All projects (\(response.count))", columns: [
                        Table.Column("Key", width: 12),
                        Table.Column("Name"),
                        Table.Column("ID", width: 8)
                    ])
                    response.forEach { project in
                        table.addRow([project.key ?? "", project.name ?? "", project.id ?? ""])
                    }
                    print(table.render())
                case .failure(let error):
                    fputs("Failed to fetch projects: \(error)\n", stderr)
                }
            } catch {
                fputs("Error: \(error)\n", stderr)
            }
        } else {
            do {
                let result: Result<Project, Error> =
                    try await request(configuration: makeRequest("/rest/api/2/project/\(key)"))
                switch result {
                case .success(let response):
                    var table = Table(title: response.name ?? "", columns: [
                        Table.Column("Key", width: 12),
                        Table.Column("Name"),
                        Table.Column("ID", width: 8),
                        Table.Column("Category", width: 16)
                    ])
                    table.addRow([
                        response.key ?? "",
                        response.name ?? "",
                        response.id ?? "",
                        response.projectCategory?.description ?? ""
                    ])
                    print(table.render())
                case .failure(let error):
                    fputs("Failed to fetch project \(key): \(error)\n", stderr)
                }
            } catch {
                fputs("Error: \(error)\n", stderr)
            }
        }
    }
}
