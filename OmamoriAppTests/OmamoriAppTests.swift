import Testing
import Foundation
@testable import OmamoriApp

struct OmamoriAppTests {
    @Test func rejectsUnsafeMusicLinks() {
        #expect(Validation.safeMusicURL("https://open.spotify.com/track/123") != nil)
        #expect(Validation.safeMusicURL("https://music.apple.com/jp/album/song/123") != nil)
        #expect(Validation.safeMusicURL("http://music.apple.com/test") == nil)
        #expect(Validation.safeMusicURL("https://music.apple.com.evil.example/test") == nil)
        #expect(Validation.safeMusicURL("javascript:alert(1)") == nil)
    }
    @Test func receiveLinksOnlyAcceptUUIDs() {
        let id = UUID().uuidString
        #expect(Validation.receivedID(URL(string: "omamori://receive/\(id)")!) == id)
        #expect(Validation.receivedID(URL(string: "https://receive/\(id)")!) == nil)
        #expect(Validation.receivedID(URL(string: "omamori://receive/not-a-valid-id")!) == nil)
        #expect(Validation.receivedID(URL(string: "omamori://receive/\(id)/extra")!) == nil)
    }
    @Test func validatesCharmBeforeSaving() throws {
        var charm = DemoData().charms[0]
        try Validation.charm(charm)
        charm.message = "   "
        #expect(throws: AppIssue.self) { try Validation.charm(charm) }
        charm.message = String(repeating: "あ", count: 501)
        #expect(throws: AppIssue.self) { try Validation.charm(charm) }
        charm.message = "応援しています"
        charm.song = .empty
        #expect(throws: AppIssue.self) { try Validation.charm(charm) }
    }
    @Test @MainActor func firestoreRoundTripPreservesNestedSongAndDates() throws {
        let original = DemoData().charms[0]
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        let document: [String: Any] = ["fields": json.mapValues(FirebaseService.encodeValue)]
        let restored = try FirebaseService.decode(Omamori.self, document: document)
        #expect(restored == original)
        let ema = DemoData().emas[0]
        let emaJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ema)) as! [String: Any]
        let restoredEma = try FirebaseService.decode(Ema.self, document: ["fields": emaJSON.mapValues(FirebaseService.encodeValue)])
        #expect(restoredEma == ema)
    }
    @Test func validatesEma() throws {
        var ema = DemoData().emas[0]
        try Validation.ema(ema)
        ema.goal = "\n  "
        #expect(throws: AppIssue.self) { try Validation.ema(ema) }
    }
}
