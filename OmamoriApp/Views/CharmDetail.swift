import SwiftUI
import UIKit

struct CharmDetail: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    let charm: Omamori
    var justCreated = false
    @State private var opened = false
    @State private var sharing = false
    @State private var busy = false
    @State private var error: String?
    @StateObject private var player = PreviewPlayer()
    @StateObject private var nfc = NFCService()
    var current: Omamori { store.charms.first { $0.id == charm.id } ?? charm }
    var needsClaim: Bool { current.recipientID.isEmpty && current.senderID != store.myID }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(justCreated ? (current.recipientID.isEmpty ? "お守りが結ばれました" : "想いを届けました") : "\(current.recipientName)へ")
                    .font(.system(.title2, design: .serif)).padding(.top, 14)
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { opened.toggle() }
                } label: {
                    CharmArtwork(color: current.color, blessing: current.blessing, width: 160)
                        .rotationEffect(.degrees(opened ? -4 : 0)).scaleEffect(opened ? 0.95 : 1)
                }.buttonStyle(.plain).accessibilityLabel(opened ? "お守りを閉じる" : "お守りを開く")
                Text("\(current.senderName)より").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                if !opened { Text("お守りに触れて、想いをひらく").font(.subheadline).foregroundStyle(ShrineTheme.vermilion) }
                if opened {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("\(current.recipientName)へ").font(.system(.title3, design: .serif))
                            Text(current.message).lineSpacing(9).textSelection(.enabled)
                            Text("\(current.senderName)より").frame(maxWidth: .infinity, alignment: .trailing).font(.subheadline)
                        }
                    }.transition(.opacity.combined(with: .move(edge: .bottom)))
                    PaperCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("あなたに贈る一曲", systemImage: "music.note").font(.caption).foregroundStyle(ShrineTheme.vermilion)
                            Text(current.song.title).font(.headline)
                            Text(current.song.artist).font(.subheadline).foregroundStyle(ShrineTheme.muted)
                            HStack {
                                if !current.song.previewURL.isEmpty { Button { player.toggle(current.song) } label: { Label(player.playing ? "停止" : "試聴", systemImage: player.playing ? "pause.fill" : "play.fill") } }
                                Spacer()
                                if let url = Validation.safeMusicURL(current.song.url) { Button("音楽サービスで聴く") { openURL(url) } }
                            }.font(.subheadline)
                            if let error = player.error { Text(error).font(.footnote).foregroundStyle(ShrineTheme.vermilion) }
                        }
                    }.transition(.opacity)
                }
                if let date = current.dedicatedAt, let thanks = current.thankYouMessage {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("奉納したお守り", systemImage: "checkmark.seal").font(.headline).foregroundStyle(ShrineTheme.vermilion)
                            Text("\(current.recipientName)からのお礼").font(.subheadline)
                            Text(thanks).lineSpacing(7)
                            Text(date, style: .date).font(.caption).foregroundStyle(ShrineTheme.muted)
                        }
                    }
                }
                if needsClaim {
                    Text("受け取ると、あなたの「コレクション」に残ります。") .font(.subheadline).foregroundStyle(ShrineTheme.muted)
                    Button {
                        busy = true
                        Task {
                            defer { busy = false }
                            do { _ = try await store.claim(current); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: { Text(busy ? "受け取り中…" : "お守りを受け取る") }.buttonStyle(PrimaryButton()).disabled(busy)
                }
                if current.senderID == store.myID {
                    if current.recipientID.isEmpty {
                        Button { sharing = true } label: { Label("リンク・AirDropで渡す", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryButton())
                        if !store.isDemo { Button { nfc.write(current.shareURL) } label: { Label("NFCタグに書き込む", systemImage: "wave.3.right") }.padding(8) }
                        Text(store.isDemo ? "このリンクは、この端末の体験モードでのみ開けます。「わたし」で相手に切り替えて、リンクを開いてみましょう。" : "相手もアプリのインストールとログインが必要です。リンクを知る人が最初の1回だけ受け取れます。NFCは書き込み可能なタグを使います。")
                            .font(.footnote).foregroundStyle(ShrineTheme.muted).lineSpacing(4)
                    } else { Label("\(current.recipientName)さんのコレクションに届いています", systemImage: "checkmark.circle").font(.subheadline) }
                }
                if let error { Text(error).foregroundStyle(ShrineTheme.vermilion) }
                Text(current.createdAt, style: .date).font(.caption).foregroundStyle(ShrineTheme.muted)
            }.padding(24).frame(maxWidth: 580).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle(current.blessing).navigationBarTitleDisplayMode(.inline)
            .appBackButton(disabled: busy)
            .onDisappear { player.stop() }
            .sheet(isPresented: $sharing) { ActivitySheet(items: [current.shareURL]) }
            .alert("NFC", isPresented: Binding(get: { nfc.message != nil }, set: { if !$0 { nfc.message = nil } })) { Button("閉じる") { nfc.message = nil } } message: { Text(nfc.message ?? "") }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
