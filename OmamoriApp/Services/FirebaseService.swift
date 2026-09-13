import Foundation
import Security

struct FirebaseConfiguration {
    let apiKey: String
    let projectID: String
    static var bundled: FirebaseConfiguration? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = values["API_KEY"] as? String, let project = values["PROJECT_ID"] as? String,
              !key.isEmpty, !project.isEmpty else { return nil }
        return FirebaseConfiguration(apiKey: key, projectID: project)
    }
}

struct AuthSession: Codable {
    var userID: String
    var idToken: String
    var refreshToken: String
    var expiresAt: Date
}

// Tokens never enter UserDefaults or the document cache.
enum SessionKeychain {
    static let service = "app.kanai.natsuki.OmamoriApp.firebase"
    static func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AppIssue.message("ログイン情報を安全に保存できませんでした。") }
        } else if status != errSecSuccess { throw AppIssue.message("ログイン情報を更新できませんでした。") }
    }
    static func read() -> AuthSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: "session", kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
    static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}

// Official Firebase Authentication + Firestore REST APIs. No package download is needed.
@MainActor
final class FirebaseService {
    let configuration: FirebaseConfiguration
    var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    init(configuration: FirebaseConfiguration) {
        self.configuration = configuration
        session = SessionKeychain.read()
    }
    var root: String { "https://firestore.googleapis.com/v1/projects/\(configuration.projectID)/databases/(default)/documents" }

    func authenticate(email: String, password: String, register: Bool) async throws -> String {
        let action = register ? "signUp" : "signInWithPassword"
        let data = try await request(URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:\(action)?key=\(configuration.apiKey)")!, method: "POST", body: ["email": email, "password": password, "returnSecureToken": true])
        guard let uid = data["localId"] as? String, let token = data["idToken"] as? String, let refresh = data["refreshToken"] as? String else { throw AppIssue.message("認証結果を読み取れませんでした。") }
        let value = AuthSession(userID: uid, idToken: token, refreshToken: refresh, expiresAt: Date().addingTimeInterval(3500))
        try SessionKeychain.save(value)
        session = value
        return uid
    }
    func resetPassword(email: String) async throws {
        _ = try await request(URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(configuration.apiKey)")!, method: "POST", body: ["requestType": "PASSWORD_RESET", "email": email])
    }
    func token() async throws -> String {
        guard let session else { throw AppIssue.message("ログインしてください。") }
        if session.expiresAt > Date() { return session.idToken }
        if let refreshTask { return try await refreshTask.value.idToken }
        let task = Task { @MainActor in
            let result = try await request(URL(string: "https://securetoken.googleapis.com/v1/token?key=\(configuration.apiKey)")!, method: "POST", body: ["grant_type": "refresh_token", "refresh_token": session.refreshToken], formEncoded: true)
            guard let token = result["id_token"] as? String, let refresh = result["refresh_token"] as? String else { throw AppIssue.message("もう一度ログインしてください。") }
            return AuthSession(userID: session.userID, idToken: token, refreshToken: refresh, expiresAt: Date().addingTimeInterval(3500))
        }
        refreshTask = task
        defer { refreshTask = nil }
        let renewed = try await task.value
        guard !Task.isCancelled, self.session?.refreshToken == session.refreshToken else { throw CancellationError() }
        try SessionKeychain.save(renewed)
        self.session = renewed
        return renewed.idToken
    }
    func signOut() {
        refreshTask?.cancel()
        refreshTask = nil
        session = nil
        SessionKeychain.clear()
    }
    func save<T: Encodable>(_ value: T, collection: String, id: String, createOnly: Bool = false) async throws {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
        let body: [String: Any] = ["fields": json.mapValues(Self.encodeValue)]
        let suffix = createOnly ? "?currentDocument.exists=false" : ""
        _ = try await request(URL(string: "\(root)/\(collection)/\(id)\(suffix)")!, method: "PATCH", body: body, token: try await token())
    }
    func get<T: Decodable>(_ type: T.Type, collection: String, id: String) async throws -> T {
        let data = try await request(URL(string: "\(root)/\(collection)/\(id)")!, token: try await token())
        return try Self.decode(type, document: data)
    }
    func query<T: Decodable>(_ type: T.Type, collection: String, field: String? = nil, equals: String? = nil, parent: String? = nil) async throws -> [T] {
        var query: [String: Any] = ["from": [["collectionId": collection]]]
        if let field, let equals {
            query["where"] = ["fieldFilter": ["field": ["fieldPath": field], "op": "EQUAL", "value": ["stringValue": equals]]]
        }
        let url = URL(string: root + (parent.map { "/\($0)" } ?? "") + ":runQuery")!
        let raw = try await requestData(url, method: "POST", body: ["structuredQuery": query], token: try await token())
        guard let rows = try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { throw AppIssue.message("データを読み取れませんでした。") }
        return try rows.compactMap { row in
            guard let document = row["document"] as? [String: Any] else { return nil }
            return try Self.decode(type, document: document)
        }
    }
    func claim(_ charm: Omamori, userID: String) async throws {
        // A conditional update in Security Rules ensures exactly one recipient can claim it.
        let url = URL(string: "\(root)/omamori/\(charm.id)?updateMask.fieldPaths=recipientID")!
        _ = try await request(url, method: "PATCH", body: ["fields": ["recipientID": ["stringValue": userID]]], token: try await token())
    }
    func dedicate(_ charm: Omamori) async throws {
        guard let date = charm.dedicatedAt, let message = charm.thankYouMessage else {
            throw AppIssue.message("奉納する内容がありません。")
        }
        let url = URL(string: "\(root)/omamori/\(charm.id)?updateMask.fieldPaths=dedicatedAt&updateMask.fieldPaths=thankYouMessage")!
        _ = try await request(url, method: "PATCH", body: ["fields": [
            "dedicatedAt": ["doubleValue": date.timeIntervalSinceReferenceDate],
            "thankYouMessage": ["stringValue": message]
        ]], token: try await token())
    }
    static func encodeValue(_ value: Any) -> [String: Any] {
        if let string = value as? String { return ["stringValue": string] }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return ["booleanValue": number.boolValue] }
            return ["doubleValue": number.doubleValue]
        }
        if let map = value as? [String: Any] { return ["mapValue": ["fields": map.mapValues(encodeValue)]] }
        if let array = value as? [Any] { return ["arrayValue": ["values": array.map(encodeValue)]] }
        return ["nullValue": NSNull()]
    }
    static func decodeValue(_ value: [String: Any]) -> Any {
        if let v = value["stringValue"] { return v }
        if let v = value["booleanValue"] { return v }
        if let v = value["doubleValue"] { return v }
        if let v = value["integerValue"] as? String { return Double(v) ?? 0 }
        if let v = value["mapValue"] as? [String: Any], let fields = v["fields"] as? [String: [String: Any]] { return fields.mapValues(decodeValue) }
        return NSNull()
    }
    static func decode<T: Decodable>(_ type: T.Type, document: [String: Any]) throws -> T {
        guard let fields = document["fields"] as? [String: [String: Any]] else { throw AppIssue.message("データ形式が正しくありません。") }
        return try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: fields.mapValues(decodeValue)))
    }
    private func request(_ url: URL, method: String = "GET", body: [String: Any]? = nil, token: String? = nil, formEncoded: Bool = false) async throws -> [String: Any] {
        let data = try await requestData(url, method: method, body: body, token: token, formEncoded: formEncoded)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
    private func requestData(_ url: URL, method: String, body: [String: Any]?, token: String?, formEncoded: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue(formEncoded ? "application/x-www-form-urlencoded" : "application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            if formEncoded {
                let encoded = body.map { key, value in
                    key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! + "=" + String(describing: value).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                }.joined(separator: "&")
                request.httpBody = Data(encoded.utf8)
            } else { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AppIssue.message("通信に失敗しました。") }
        guard (200..<300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let error = (json?["error"] as? [String: Any])?["message"] as? String ?? ""
            let message: String
            if error.contains("EMAIL_EXISTS") { message = "このメールアドレスは登録済みです。ログインしてください。" }
            else if error.contains("INVALID_LOGIN") || error.contains("INVALID_PASSWORD") || error.contains("EMAIL_NOT_FOUND") { message = "メールアドレスかパスワードが正しくありません。" }
            else if error.contains("WEAK_PASSWORD") { message = "パスワードは6文字以上にしてください。" }
            else if error.contains("TOO_MANY") { message = "しばらく待ってから、もう一度お試しください。" }
            else if response.statusCode == 404 { message = "見つかりませんでした。IDやリンクを確認してください。" }
            else if response.statusCode == 403 { message = "アクセスできません。受け取り済みのお守り、またはFirebaseのルール設定を確認してください。" }
            else { message = "通信できませんでした（\(response.statusCode)）。接続とFirebaseの設定を確認してください。" }
            throw AppIssue.message(message)
        }
        return data
    }
}
