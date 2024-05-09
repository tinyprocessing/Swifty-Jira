import Foundation
import SwiftyTextTable

extension Jira {
    func project(key: String = "") async {
        if key.isEmpty {
            do {
                let result: Result<[Project], Error> = try await request(configuration: makeRequest("/rest/api/2/project"))
                switch result {
                case let .success(response):
                    var table = TextTable(columns: [
                        TextTableColumn(header: "Key"),
                        TextTableColumn(header: "Name"),
                        TextTableColumn(header: "ID"),
                    ], header: "All projects")
                    response.forEach { project in
                        table.addRow(values: [
                            project.key ?? "",
                            project.name ?? "",
                            project.id ?? "",
                        ])
                    }
                    print(table.render())
                case .failure:
                    break
                }
            } catch {}
        } else {
            do {
                let result: Result<Project, Error> = try await request(configuration: makeRequest("/rest/api/2/project/\(key)"))
                switch result {
                case let .success(response):
                    var table = TextTable(columns: [
                        TextTableColumn(header: "Key"),
                        TextTableColumn(header: "Name"),
                        TextTableColumn(header: "ID"),
                        TextTableColumn(header: "Category"),
                    ], header: "\(response.name ?? "")")
                    table.addRow(values: [
                        response.key ?? "",
                        response.name ?? "",
                        response.id ?? "",
                        response.projectCategory?.description ?? "",
                    ])
                    print(table.render())
                case .failure:
                    break
                }
            } catch {}
        }
    }
}
