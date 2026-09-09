import Foundation

@main
struct Verify {
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ value: Bool, _ name: String) throws {
            guard value else { throw AppIssue.message("FAIL: \(name)") }
            checks += 1
            print("PASS: \(name)")
        }
        let path = URL(fileURLWithPath: "/private/tmp/omamori-verification-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: path) }
        let store = AppStore(storageURL: path)
        store.startDemo()
        try check(store.received.count == 1, "seeded received charm")
        var charm = DemoData().charms[0]
        charm.id = UUID().uuidString
        charm.senderID = "demo-me"; charm.senderName = "なつき"
        charm.recipientID = "demo-haru"; charm.recipientName = "はる"
        try await store.createCharm(charm)
        try check(store.sent.contains { $0.id == charm.id }, "sender collection")
        store.startDemo(as: AppStore.demoPeople[1])
        try check(store.received.contains { $0.id == charm.id }, "recipient collection after account switch")
        let restored = AppStore(storageURL: path)
        restored.startDemo(as: AppStore.demoPeople[1])
        try check(restored.received.contains { $0.id == charm.id }, "persistent save across store restart")
        store.startDemo()
        let ema = Ema(ownerID: "demo-me", name: "なつき", goal: "完成させる", message: "毎日少しずつ")
        try await store.createEma(ema)
        try await store.fulfill(ema)
        try check(store.emas.first { $0.id == ema.id }?.fulfilled == true, "ema fulfillment")
        store.startDemo(as: AppStore.demoPeople[1])
        do { try await store.fulfill(ema); throw AppIssue.message("wrong owner accepted") }
        catch { try check(error.localizedDescription.contains("自分の絵馬"), "reject other user's ema mutation") }
        store.startDemo()
        charm.id = UUID().uuidString; charm.recipientID = ""
        try await store.createCharm(charm)
        await store.handle(charm.shareURL)
        try check(store.incoming?.id == charm.id, "deep link resolution")
        store.startDemo(as: AppStore.demoPeople[1])
        _ = try await store.claim(charm)
        try check(store.received.contains { $0.id == charm.id }, "claim invitation")
        store.startDemo(as: AppStore.demoPeople[2])
        do { _ = try await store.claim(charm); throw AppIssue.message("double claim accepted") }
        catch { try check(error.localizedDescription.contains("受け取り済み"), "reject second claim from stale invitation") }
        try check(!store.charms.contains { $0.id == charm.id }, "third user cannot see private charm")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(charm)) as! [String: Any]
        let roundtrip = try FirebaseService.decode(Omamori.self, document: ["fields": json.mapValues(FirebaseService.encodeValue)])
        try check(roundtrip == charm, "Firestore nested song and timestamp roundtrip")
        let emaJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ema)) as! [String: Any]
        let emaRoundtrip = try FirebaseService.decode(Ema.self, document: ["fields": emaJSON.mapValues(FirebaseService.encodeValue)])
        try check(emaRoundtrip == ema, "Firestore boolean roundtrip")
        try check(Validation.safeMusicURL("https://music.apple.com.evil.example/track") == nil, "reject spoofed music domain")
        try check(Validation.safeMusicURL("javascript:alert(1)") == nil, "reject active content URL")
        try check(Validation.receivedID(URL(string: "omamori://receive/not-an-id")!) == nil, "reject malformed receive link")
        charm.message = " "
        do { try Validation.charm(charm); throw AppIssue.message("empty message accepted") }
        catch { try check(error.localizedDescription.contains("500文字"), "reject empty message") }
        print("\(checks) checks passed")
    }
}
