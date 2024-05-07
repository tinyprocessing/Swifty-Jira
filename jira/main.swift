import Foundation

protocol Client {
    func generateCoolies()
}

public class Jira: NSObject, Client {
    func generateCoolies() {
        print("generation started")
    }

    override init() {}
}

func main() {
    let client = Jira()
    client.generateCoolies()
}

main()
