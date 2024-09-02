import Foundation

extension Jira {
    private func makeTransition(key: String, resolution: String, transition: String) async {
        do {
            var parameters: [String: Any] = [
                "update": [
                    "comment": [
                        [
                            "add": [
                                "body": key
                            ]
                        ]
                    ]
                ],
                "transition": [
                    "id": transition
                ]
            ]

            if !resolution.isEmpty {
                parameters["fields"] = [
                    "resolution": [
                        "name": resolution
                    ]
                ]
            }

            let request = makeRequestCustom("/rest/api/2/issue/\(key)/transitions", body: parameters)
            let _ = try await URLSession.shared.data(for: request)
            await issue(id: key)
        } catch {
            print(error)
        }
    }

    func transitionFields(key: String, verbose: Bool = false) async -> Result<Transition, Error> {
        do {
            let result: Result<Transition, Error> =
                try await request(
                    configuration: makeRequest("/rest/api/2/issue/\(key)/transitions?expand=transitions.fields")
                )
            if verbose {
                switch result {
                case .success(let response):
                    response.transitions?.forEach {
                        print($0.name ?? "", " id: ", $0.id ?? "")
                        if let fields = $0.fields, let resolution = fields.resolution {
                            print("Resulution:")
                            resolution.allowedValues?.forEach { value in
                                print("    ", value.name ?? "", value.id ?? "")
                            }
                        }
                    }
                default:
                    break
                }
            }
            return result
        } catch {
            return .failure(NSError())
        }
    }

    func transition(to status: String, key: String, resolution: String) async {
        do {
            switch await transitionFields(key: key) {
            case .success(let response):
                var transitionValue: String?
                var resolutionValue: String?
                response.transitions?.forEach { transition in
                    if (transition.name ?? "").lowercased() == status.lowercased() {
                        print("You selected: \(transition.name ?? ""), with id: \(transition.id ?? "")")
                        if transition.fields?.resolution?.allowedValues?.isEmpty ?? true {
                            transitionValue = transition.id
                            resolutionValue = ""
                        }
                        transition.fields?.resolution?.allowedValues?.forEach { value in
                            if (value.name ?? "").lowercased() == resolution.lowercased() {
                                print("With resolution: \(value.id ?? "") -> \(value.name ?? "")")
                                transitionValue = transition.id
                                resolutionValue = value.name
                            }
                        }
                    }
                }

                if let transitionValue = transitionValue, let resolutionValue = resolutionValue {
                    await makeTransition(key: key,
                                         resolution: resolutionValue,
                                         transition: transitionValue)
                }
            case .failure:
                print("failure")
            }
        } catch {
            print(error)
        }
    }
}
