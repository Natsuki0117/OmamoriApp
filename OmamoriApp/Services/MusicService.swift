import Foundation
import AVFoundation

struct MusicSearch {
    struct Response: Decodable { var results: [Track] }
    struct Track: Decodable {
        var trackId: Int
        var trackName: String
        var artistName: String
        var trackViewUrl: String?
        var previewUrl: String?
        var artworkUrl100: String?
        var song: Song { Song(id: String(trackId), title: trackName, artist: artistName, url: trackViewUrl ?? "", previewURL: previewUrl ?? "", artworkURL: artworkUrl100 ?? "") }
    }
    static func search(_ text: String) async throws -> [Song] {
        var url = URLComponents(string: "https://itunes.apple.com/search")!
        url.queryItems = [URLQueryItem(name: "term", value: text), URLQueryItem(name: "country", value: "jp"), URLQueryItem(name: "entity", value: "song"), URLQueryItem(name: "limit", value: "25"), URLQueryItem(name: "lang", value: "ja_jp")]
        let (data, response) = try await URLSession.shared.data(from: url.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AppIssue.message("曲を検索できませんでした。時間をおいてお試しください。") }
        return try JSONDecoder().decode(Response.self, from: data).results.map(\.song).filter { Validation.safeMusicURL($0.url) != nil }
    }
}

@MainActor
final class PreviewPlayer: ObservableObject {
    @Published var playing = false
    @Published var error: String?
    private var player: AVPlayer?
    private var observation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    func toggle(_ song: Song) {
        if playing { stop(); return }
        guard let url = URL(string: song.previewURL), url.scheme == "https", let host = url.host,
              host.hasSuffix(".mzstatic.com") || host.hasSuffix(".itunes.apple.com") else { error = "この曲には試聴音源がありません。音楽サービスで聴けます。"; return }
        let item = AVPlayerItem(url: url)
        observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor in self?.stop(); self?.error = "試聴を再生できませんでした。音楽サービスでお聴きください。" }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in Task { @MainActor in self?.stop() } }
        player = AVPlayer(playerItem: item)
        player?.play()
        playing = true
    }
    func stop() {
        player?.pause()
        player = nil
        observation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        playing = false
    }
}
