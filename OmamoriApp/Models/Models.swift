import Foundation
import SwiftUI

struct Person: Codable, Identifiable, Hashable {
    var id: String
    var name: String
}

struct Song: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var artist: String
    var url: String
    var previewURL: String
    var artworkURL: String
    static let empty = Song(id: "", title: "", artist: "", url: "", previewURL: "", artworkURL: "")
}

enum CharmColor: String, Codable, CaseIterable, Identifiable {
    case coral, cream, lavender, sage, blue
    var id: String { rawValue }
    var name: String {
        switch self {
        case .coral: "朱色"
        case .cream: "生成り"
        case .lavender: "藤色"
        case .sage: "若草"
        case .blue: "空色"
        }
    }
    var color: Color {
        switch self {
        case .coral: Color(red: 0.77, green: 0.37, blue: 0.35)
        case .cream: Color(red: 0.82, green: 0.70, blue: 0.47)
        case .lavender: Color(red: 0.60, green: 0.53, blue: 0.70)
        case .sage: Color(red: 0.46, green: 0.61, blue: 0.48)
        case .blue: Color(red: 0.43, green: 0.60, blue: 0.70)
        }
    }
}

struct Omamori: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var senderID: String
    var senderName: String
    var recipientID: String
    var recipientName: String
    var message: String
    var blessing: String
    var color: CharmColor
    var song: Song
    var emaID: String
    var createdAt: Date = Date()
    var dedicatedAt: Date? = nil
    var thankYouMessage: String? = nil
    var shareURL: URL { URL(string: "omamori://receive/\(id)")! }
}

struct Ema: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var ownerID: String
    var name: String
    var goal: String
    var message: String
    var fulfilled: Bool = false
    var createdAt: Date = Date()
}

enum AppIssue: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum Validation {
    static func charm(_ charm: Omamori) throws {
        guard !charm.recipientName.trimmed.isEmpty, charm.recipientName.count <= 30,
              !charm.senderName.trimmed.isEmpty, charm.senderName.count <= 30,
              !charm.message.trimmed.isEmpty, charm.message.count <= 500,
              !charm.blessing.trimmed.isEmpty, charm.blessing.count <= 12 else {
            throw AppIssue.message("名前は30文字、お守りの種類は12文字、メッセージは500文字以内で入力してください。")
        }
        guard !charm.song.title.trimmed.isEmpty, safeMusicURL(charm.song.url) != nil else {
            throw AppIssue.message("贈る曲を選択してください。曲のリンクにはApple Music・Spotify・YouTubeのHTTPSリンクが使えます。")
        }
    }
    static func ema(_ ema: Ema) throws {
        guard !ema.name.trimmed.isEmpty, ema.name.count <= 30,
              !ema.goal.trimmed.isEmpty, ema.goal.count <= 60, ema.message.count <= 300 else {
            throw AppIssue.message("名前は30文字、願いごとは60文字、メッセージは300文字以内で入力してください。")
        }
    }
    static func safeMusicURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", let host = url.host?.lowercased(),
              ["music.apple.com", "itunes.apple.com", "open.spotify.com", "www.youtube.com", "youtube.com", "youtu.be", "music.youtube.com"].contains(host) else { return nil }
        return url
    }
    static func receivedID(_ url: URL) -> String? {
        guard url.scheme == "omamori", url.host == "receive", url.pathComponents.count == 2,
              UUID(uuidString: url.lastPathComponent) != nil else { return nil }
        return url.lastPathComponent
    }
}
