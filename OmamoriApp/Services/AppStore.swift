import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var user: Person?
    @Published var isDemo = false
    @Published var charms: [Omamori] = []
    @Published var emas: [Ema] = []
    @Published var friends: [Person] = []
    @Published var loading = false
    @Published var error: String?
    @Published var pendingURL: URL?
    @Published var incoming: Omamori?
    let cloud = FirebaseConfiguration.bundled.map(FirebaseService.init)
    static let demoPeople = [Person(id: "demo-me", name: "なつき"), Person(id: "demo-haru", name: "はる"), Person(id: "demo-aoi", name: "あおい")]
    private var demo = DemoData()
    private var generation = 0
    private let demoURL: URL
    init(storageURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        demoURL = storageURL ?? directory.appendingPathComponent("omamori-demo-v1.json")
        if let data = try? Data(contentsOf: demoURL), let saved = try? JSONDecoder().decode(DemoData.self, from: data) { demo = saved }
    }
    var configured: Bool { cloud != nil }
    var myID: String { user?.id ?? "" }
    var received: [Omamori] { charms.filter { $0.recipientID == myID } }
    var sent: [Omamori] { charms.filter { $0.senderID == myID } }

    func restore() async {
        guard let cloud, let session = cloud.session, user == nil else { return }
        loading = true
        defer { loading = false }
        do {
            _ = try await cloud.token()
            user = try await cloud.get(Person.self, collection: "users", id: session.userID)
            await refresh()
            await resolvePendingLink()
        } catch { self.error = error.localizedDescription }
    }
    func authenticate(email: String, password: String, name: String, register: Bool) async throws {
        guard let cloud else { throw AppIssue.message("Firebaseが未設定です。端末内で体験できます。") }
        guard !register || (!name.trimmed.isEmpty && name.trimmed.count <= 30) else { throw AppIssue.message("名前を30文字以内で入力してください。") }
        let id = try await cloud.authenticate(email: email.trimmed, password: password, register: register)
        isDemo = false
        if register {
            let person = Person(id: id, name: name.trimmed)
            try await cloud.save(person, collection: "users", id: id)
            user = person
        } else {
            do { user = try await cloud.get(Person.self, collection: "users", id: id) }
            catch {
                // Auth may have succeeded previously while initial profile creation failed.
                // Only recover a missing profile; never overwrite on network/permission errors.
                if error.localizedDescription.contains("見つかりません") {
                    let person = Person(id: id, name: name.trimmed.isEmpty ? "ななし" : name.trimmed)
                    try await cloud.save(person, collection: "users", id: id, createOnly: true)
                    user = person
                } else { throw error }
            }
        }
        generation += 1
        await refresh()
        await resolvePendingLink()
    }
    func startDemo(as selectedPerson: Person? = nil) {
        let person = selectedPerson ?? Self.demoPeople[0]
        generation += 1
        isDemo = true
        loading = false
        user = person
        friends = Self.demoPeople.filter { $0.id != person.id }
        updateDemoView()
        Task { await resolvePendingLink() }
    }
    func signOut() {
        generation += 1
        cloud?.signOut()
        user = nil
        loading = false
        isDemo = false
        charms = []; emas = []; friends = []; incoming = nil
    }
    func refresh() async {
        guard let user else { return }
        if isDemo { updateDemoView(); return }
        guard let cloud else { return }
        let revision = generation
        loading = true
        defer { if revision == generation { loading = false } }
        do {
            let publicEmas = try await cloud.query(Ema.self, collection: "emas")
            let sent = try await cloud.query(Omamori.self, collection: "omamori", field: "senderID", equals: user.id)
            let received = try await cloud.query(Omamori.self, collection: "omamori", field: "recipientID", equals: user.id)
            let friends = try await cloud.query(Person.self, collection: "friends", parent: "users/\(user.id)")
            guard revision == generation else { return }
            self.emas = publicEmas.sorted { $0.createdAt > $1.createdAt }
            self.charms = Array(Dictionary((sent + received).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.createdAt > $1.createdAt }
            self.friends = friends.sorted { $0.name < $1.name }
        } catch { if revision == generation { self.error = error.localizedDescription } }
    }
    func createCharm(_ charm: Omamori) async throws {
        let revision = generation
        try Validation.charm(charm)
        guard charm.senderID == myID else { throw AppIssue.message("もう一度ログインしてください。") }
        if isDemo {
            var next = demo
            next.charms.insert(charm, at: 0)
            try saveDemo(next)
            updateDemoView()
        } else if let cloud {
            try await cloud.save(charm, collection: "omamori", id: charm.id, createOnly: true)
            guard revision == generation else { throw CancellationError() }
            charms.insert(charm, at: 0)
        } else { throw AppIssue.message("ログインしてください。") }
    }
    func createEma(_ ema: Ema) async throws {
        let revision = generation
        try Validation.ema(ema)
        guard ema.ownerID == myID else { throw AppIssue.message("もう一度ログインしてください。") }
        if isDemo {
            var next = demo
            next.emas.insert(ema, at: 0)
            try saveDemo(next)
            updateDemoView()
        } else if let cloud {
            try await cloud.save(ema, collection: "emas", id: ema.id, createOnly: true)
            guard revision == generation else { throw CancellationError() }
            emas.insert(ema, at: 0)
        }
    }
    func fulfill(_ ema: Ema) async throws {
        let revision = generation
        guard ema.ownerID == myID else { throw AppIssue.message("自分の絵馬だけ変更できます。") }
        var value = ema
        value.fulfilled.toggle()
        if isDemo {
            var next = demo
            if let index = next.emas.firstIndex(where: { $0.id == ema.id }) { next.emas[index] = value }
            try saveDemo(next)
            updateDemoView()
        } else if let cloud {
            try await cloud.save(value, collection: "emas", id: value.id)
            guard revision == generation else { throw CancellationError() }
            if let index = emas.firstIndex(where: { $0.id == ema.id }) { emas[index] = value }
        }
    }
    func dedicate(_ charm: Omamori, message: String) async throws {
        let revision = generation
        guard !myID.isEmpty, charm.recipientID == myID else {
            throw AppIssue.message("受け取ったお守りだけ奉納できます。")
        }
        guard !message.trimmed.isEmpty, message.count <= 300 else {
            throw AppIssue.message("お礼のメッセージを300文字以内で入力してください。")
        }
        let source = isDemo ? demo.charms : charms
        guard var current = source.first(where: { $0.id == charm.id }), current.recipientID == myID else {
            throw AppIssue.message("お守りが見つかりません。コレクションを更新してください。")
        }
        guard current.dedicatedAt == nil else { throw AppIssue.message("このお守りは奉納済みです。") }
        current.dedicatedAt = Date()
        current.thankYouMessage = message.trimmed
        if isDemo {
            var next = demo
            if let index = next.charms.firstIndex(where: { $0.id == current.id }) { next.charms[index] = current }
            try saveDemo(next)
            updateDemoView()
        } else if let cloud {
            try await cloud.dedicate(current)
            guard revision == generation else { throw CancellationError() }
            if let index = charms.firstIndex(where: { $0.id == current.id }) { charms[index] = current }
        } else { throw AppIssue.message("ログインしてください。") }
    }
    func addFriend(id: String) async throws {
        let revision = generation
        let owner = myID
        let id = id.trimmed
        guard !id.isEmpty, id.count <= 128, !id.contains("/"), id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }), id != myID else { throw AppIssue.message("相手の正しい友達IDを入力してください。") }
        guard !friends.contains(where: { $0.id == id }) else { throw AppIssue.message("すでに友達に追加されています。") }
        guard !isDemo, let cloud else { throw AppIssue.message("体験モードでは、はる・あおいにお守りを贈れます。") }
        let friend = try await cloud.get(Person.self, collection: "users", id: id)
        guard revision == generation else { throw CancellationError() }
        try await cloud.save(friend, collection: "users/\(owner)/friends", id: id)
        guard revision == generation else { throw CancellationError() }
        friends.append(friend)
    }
    func handle(_ url: URL) async {
        guard Validation.receivedID(url) != nil else { error = "このお守りのリンクは読み取れません。"; return }
        pendingURL = url
        await resolvePendingLink()
    }
    func resolvePendingLink() async {
        let revision = generation
        guard user != nil, let url = pendingURL, let id = Validation.receivedID(url) else { return }
        do {
            let charm: Omamori
            if isDemo {
                guard let found = demo.charms.first(where: { $0.id == id }) else { throw AppIssue.message("このリンクは体験データにありません。実際のお守りはFirebaseでログインして受け取ってください。") }
                charm = found
            } else if let cloud { charm = try await cloud.get(Omamori.self, collection: "omamori", id: id) }
            else { return }
            guard revision == generation else { return }
            guard charm.recipientID.isEmpty || charm.recipientID == myID || charm.senderID == myID else { throw AppIssue.message("このお守りは別の方に届いています。") }
            incoming = charm
            pendingURL = nil
        } catch { if revision == generation { self.error = error.localizedDescription; pendingURL = nil } }
    }
    func claim(_ charm: Omamori) async throws -> Omamori {
        let revision = generation
        guard user != nil, charm.senderID != myID else { throw AppIssue.message("自分で作ったお守りです。相手にリンクを渡してください。") }
        if charm.recipientID == myID { return charm }
        guard charm.recipientID.isEmpty else { throw AppIssue.message("このお守りは受け取り済みです。") }
        var claimed = charm
        claimed.recipientID = myID
        if isDemo {
            guard let current = demo.charms.first(where: { $0.id == charm.id }), current.recipientID.isEmpty else { throw AppIssue.message("このお守りは受け取り済みです。") }
            var next = demo
            next.charms.removeAll { $0.id == charm.id }
            next.charms.insert(claimed, at: 0)
            try saveDemo(next)
            updateDemoView()
        } else if let cloud {
            try await cloud.claim(charm, userID: myID)
            guard revision == generation else { throw CancellationError() }
            charms.removeAll { $0.id == charm.id }
            charms.insert(claimed, at: 0)
        }
        incoming = nil
        return claimed
    }
    private func updateDemoView() {
        emas = demo.emas.sorted { $0.createdAt > $1.createdAt }
        charms = demo.charms.filter { $0.senderID == myID || $0.recipientID == myID }.sorted { $0.createdAt > $1.createdAt }
    }
    private func saveDemo(_ next: DemoData) throws {
        try FileManager.default.createDirectory(at: demoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: demoURL, options: [.atomic, .completeFileProtection])
        demo = next
    }
}

struct DemoData: Codable {
    var charms: [Omamori] = [
        Omamori(senderID: "demo-haru", senderName: "はる", recipientID: "demo-me", recipientName: "なつき", message: "積み重ねてきた時間は、きっと力になるよ。いつものなつきのままで。応援しています。", blessing: "挑戦守り", color: .coral, song: Song(id: "sample", title: "あなたを応援する一曲", artist: "好きな曲を探して贈ろう", url: "https://music.apple.com/jp/search?term=応援", previewURL: "", artworkURL: ""), emaID: "", createdAt: Date().addingTimeInterval(-86400))
    ]
    var emas: [Ema] = [
        Ema(ownerID: "demo-haru", name: "はる", goal: "はじめてのマラソンを\n笑顔で走りきりたい", message: "毎朝、少しずつ走っています。最後まで自分のペースで。", createdAt: Date().addingTimeInterval(-3600)),
        Ema(ownerID: "demo-aoi", name: "あおい", goal: "大切な人に\n素直な気持ちを伝える", message: "ありがとうを、ちゃんと言葉にする一年に。", createdAt: Date().addingTimeInterval(-7200)),
        Ema(ownerID: "demo-me", name: "なつき", goal: "想いが届くアプリを\n完成させる", message: "誰かの背中をそっと押せるものをつくりたい。", createdAt: Date().addingTimeInterval(-10800))
    ]
}
