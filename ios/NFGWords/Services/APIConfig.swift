import Foundation

enum APIConfig {
    static var baseURL: URL {
        if let env = ProcessInfo.processInfo.environment["NFG_API_BASE"],
           let url = URL(string: env) {
            return url
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "NFG_API_BASE") as? String,
           let url = URL(string: plist) {
            return url
        }
        return URL(string: "http://127.0.0.1:19877")!
    }
}
