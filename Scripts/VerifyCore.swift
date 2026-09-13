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
        store.startDemo(as: AppStore.demoPeople[1])
        guard let gift = store.received.first(where: { $0.id == charm.id }) else { throw AppIssue.message("missing gift") }
        try await store.dedicate(gift, message: "勇気をくれて、ありがとう。")
        try check(store.received.first { $0.id == gift.id }?.thankYouMessage == "勇気をくれて、ありがとう。", "dedication saves thank-you message")
        let dedicated = CollectionSelection.charms(store.charms, userID: store.myID, filter: .dedicated, order: .newest)
        try check(dedicated.count == 1 && dedicated[0].id == gift.id, "dedicated filter")
        let reloaded = AppStore(storageURL: path)
        reloaded.startDemo(as: AppStore.demoPeople[1])
        try check(reloaded.received.first { $0.id == gift.id }?.dedicatedAt != nil, "dedication persists after restart")
        do { try await store.dedicate(gift, message: "もう一度"); throw AppIssue.message("double dedication accepted") }
        catch { try check(error.localizedDescription.contains("奉納済み"), "reject repeated dedication") }
        store.startDemo()
        do { try await store.dedicate(gift, message: "他人"); throw AppIssue.message("wrong user accepted") }
        catch { try check(error.localizedDescription.contains("受け取った"), "sender cannot dedicate recipient's charm") }
        try check(store.sent.first { $0.id == gift.id }?.thankYouMessage != nil, "sender can read thank-you")
        var first = gift; first.id = "first"; first.createdAt = Date(timeIntervalSinceReferenceDate: 1)
        var second = gift; second.id = "second"; second.createdAt = Date(timeIntervalSinceReferenceDate: 2)
        try check(CollectionSelection.charms([first, second], userID: "demo-haru", filter: .received, order: .oldest).map(\.id) == ["first", "second"], "oldest sorting")
        try check(CollectionSelection.charms([first, second], userID: "demo-haru", filter: .received, order: .newest).map(\.id) == ["second", "first"], "newest sorting")
        try check(CollectionSelection.charms([first, second], userID: "stranger", filter: .all, order: .newest).isEmpty, "exclude unrelated user's charms")
        let publicEma = Ema(id: "supported", ownerID: "someone", name: "友達", goal: "願い", message: "")
        let unrelatedEma = Ema(id: "unrelated", ownerID: "another", name: "別の人", goal: "別の願い", message: "")
        first.emaID = publicEma.id
        let selected = CollectionSelection.emas([ema, publicEma, unrelatedEma], charms: [first, first], userID: "demo-me", filter: .all, order: .newest)
        try check(Set(selected.map(\.id)) == Set([ema.id, publicEma.id]), "own and supported emas without duplicates")
        try check(CollectionSelection.emas([ema, publicEma], charms: [first], userID: "demo-me", filter: .supported, order: .newest).map(\.id) == [publicEma.id], "supported ema filter")
        let legacy = try JSONDecoder().decode(Omamori.self, from: JSONEncoder().encode(gift))
        try check(legacy.dedicatedAt == nil, "legacy records without dedication fields decode")
        print("\(checks) checks passed")
    }
}
