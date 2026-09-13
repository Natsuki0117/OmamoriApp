import SwiftUI

struct CreateHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                PageHeading(eyebrow: "MUSUBU", title: "想いを、かたちに", subtitle: "誰かへの応援も、自分への約束も。")
                NavigationLink { CharmComposer() } label: {
                    PaperCard {
                        HStack(spacing: 25) {
                            CharmArtwork(width: 85)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("お守りをつくる").font(.system(.title2, design: .serif))
                                Text("名前、ことば、一曲。\nあの人だけのお守りを。").font(.subheadline).lineSpacing(5)
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                }.buttonStyle(.plain)
                NavigationLink { EmaComposer() } label: {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 18) {
                            EmaArtwork(goal: "一歩、踏み出せますように", name: "")
                            Text("絵馬を書く").font(.system(.title2, design: .serif))
                            Text("叶えたい願いを、みんなの絵馬に。") .font(.subheadline).foregroundStyle(ShrineTheme.muted)
                        }
                    }
                }.buttonStyle(.plain)
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("つくる").navigationBarTitleDisplayMode(.inline)
            .appBackButton()
    }
}

struct CharmComposer: View {
    @EnvironmentObject var store: AppStore
    var ema: Ema? = nil
    @State private var recipientName = ""
    @State private var senderName = ""
    @State private var recipientID = ""
    @State private var message = ""
    @State private var blessing = "応援守り"
    @State private var color: CharmColor = .coral
    @State private var song = Song.empty
    @State private var pickSong = false
    @State private var busy = false
    @State private var error: String?
    @State private var created: Omamori?
    @State private var initialized = false
    var valid: Bool {
        !recipientName.trimmed.isEmpty && !senderName.trimmed.isEmpty && !message.trimmed.isEmpty &&
        !blessing.trimmed.isEmpty && !song.title.isEmpty && recipientName.count <= 30 && senderName.count <= 30 && message.count <= 500 && blessing.count <= 12
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeading(eyebrow: "FOR YOU", title: "想いを込めて、結ぶ", subtitle: ema == nil ? "ひとつずつ、あなたらしいお守りに。" : "\(ema!.name)さんの願いを応援します。")
                CharmArtwork(color: color, blessing: blessing, width: 135)
                    .animation(.easeInOut(duration: 0.25), value: color)
                Text("\(recipientName.trimmed.isEmpty ? "大切なあなた" : recipientName)へ").font(.system(.title3, design: .serif))
                PaperCard {
                    VStack(alignment: .leading, spacing: 17) {
                        sectionTitle("01", "誰に届ける？")
                        if ema == nil {
                            Picker("届け方", selection: $recipientID) {
                                Text("リンク・AirDrop・NFCで渡す").tag("")
                                ForEach(store.friends) { friend in Text("友達：\(friend.name)").tag(friend.id) }
                            }.pickerStyle(.menu)
                            .onChange(of: recipientID) { _, id in
                                if let person = store.friends.first(where: { $0.id == id }) { recipientName = person.name }
                            }
                        } else { Label("絵馬を書いた\(ema!.name)さんに届きます", systemImage: "person.crop.circle") .font(.subheadline) }
                        field("相手の名前（30文字まで）", text: $recipientName)
                        field("自分の名前（30文字まで）", text: $senderName)
                        if recipientID.isEmpty {
                            Text(store.isDemo ? "体験モードのリンクは、この端末の体験データだけで使えます。" : "リンクを知っている人が最初の1回だけ受け取れます。相手に直接渡してください。")
                                .font(.footnote).foregroundStyle(ShrineTheme.muted)
                        }
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 17) {
                        sectionTitle("02", "ことばと音楽")
                        TextField("伝えたい想いを書いてください", text: $message, axis: .vertical).lineLimit(4...8).padding(12).background(ShrineTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                        Text("\(message.count) / 500文字").font(.caption).foregroundStyle(message.count > 500 ? ShrineTheme.vermilion : ShrineTheme.muted).frame(maxWidth: .infinity, alignment: .trailing)
                        Button { pickSong = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note").font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title.isEmpty ? "贈る一曲を選ぶ" : song.title).font(.headline)
                                    Text(song.title.isEmpty ? "曲名やアーティストで検索" : song.artist).font(.subheadline).foregroundStyle(ShrineTheme.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }.padding(14).background(ShrineTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 17) {
                        sectionTitle("03", "お守りの装い")
                        HStack(spacing: 14) {
                            ForEach(CharmColor.allCases) { choice in
                                Button { color = choice } label: {
                                    VStack(spacing: 7) {
                                        Circle().fill(choice.color).frame(width: 39, height: 39)
                                            .overlay { if color == choice { Image(systemName: "checkmark").foregroundStyle(.white).font(.headline) } }
                                        Text(choice.name).font(.caption)
                                    }
                                }.buttonStyle(.plain).accessibilityLabel(choice.name).accessibilityAddTraits(color == choice ? .isSelected : [])
                            }
                        }.frame(maxWidth: .infinity)
                        field("何守り？（12文字まで）", text: $blessing)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(["応援守り", "合格守り", "健康守り", "縁結び", "挑戦守り"], id: \.self) { title in
                                Button(title) { blessing = title }.font(.footnote).padding(.horizontal, 12).padding(.vertical, 8).background(ShrineTheme.paper, in: Capsule())
                            } }
                        }
                    }
                }
                if let error { Text(error).font(.subheadline).foregroundStyle(ShrineTheme.vermilion) }
                Button {
                    let charm = Omamori(senderID: store.myID, senderName: senderName.trimmed, recipientID: recipientID, recipientName: recipientName.trimmed, message: message.trimmed, blessing: blessing.trimmed, color: color, song: song, emaID: ema?.id ?? "")
                    busy = true
                    Task {
                        defer { busy = false }
                        do { try await store.createCharm(charm); created = charm }
                        catch { self.error = error.localizedDescription }
                    }
                } label: { if busy { ProgressView().tint(.white) } else { Text(recipientID.isEmpty ? "お守りを結ぶ" : "お守りを贈る") } }
                    .buttonStyle(PrimaryButton()).disabled(!valid || busy || created != nil)
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("お守りをつくる").navigationBarTitleDisplayMode(.inline)
            .appBackButton(disabled: busy)
            .onAppear {
                guard !initialized else { return }; initialized = true
                senderName = store.user?.name ?? ""
                if let ema { recipientID = ema.ownerID; recipientName = ema.name }
            }
            .sheet(isPresented: $pickSong) { NavigationStack { SongPicker(song: $song) } }
            .navigationDestination(item: $created) { charm in CharmDetail(charm: charm, justCreated: true) }
    }
    private func sectionTitle(_ number: String, _ title: String) -> some View {
        HStack(spacing: 10) { Text(number).foregroundStyle(ShrineTheme.vermilion).font(.caption.weight(.bold)); Text(title).font(.headline) }
    }
    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(label).font(.caption).foregroundStyle(ShrineTheme.muted); TextField(label, text: text).padding(12).background(ShrineTheme.paper, in: RoundedRectangle(cornerRadius: 12)) }
    }
}

struct SongPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var song: Song
    @State private var query = ""
    @State private var results: [Song] = []
    @State private var busy = false
    @State private var searched = false
    @State private var error: String?
    @State private var manual = false
    @State private var title = ""
    @State private var artist = ""
    @State private var link = ""
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("曲名・アーティスト名", text: $query).submitLabel(.search).onSubmit { search() }
                    Button("検索") { search() }.disabled(query.trimmed.isEmpty || busy)
                }
            } footer: { Text("iTunesの曲を選んで添えられます。音源ファイルは送信せず、曲のリンクを共有します。") }
            if busy { ProgressView("曲を探しています…") }
            if let error { Text(error).foregroundStyle(ShrineTheme.vermilion) }
            if searched && results.isEmpty && !busy { Text("曲が見つかりませんでした。別の言葉で検索するか、曲のリンクを入力してください。").foregroundStyle(ShrineTheme.muted) }
            ForEach(results) { result in
                Button { song = result; dismiss() } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: result.artworkURL)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "music.note").frame(maxWidth: .infinity, maxHeight: .infinity).background(ShrineTheme.paper) }.frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) { Text(result.title).foregroundStyle(ShrineTheme.ink); Text(result.artist).font(.subheadline).foregroundStyle(ShrineTheme.muted) }
                    }
                }
            }
            Section {
                DisclosureGroup("曲のリンクを入力する", isExpanded: $manual) {
                    TextField("曲名", text: $title)
                    TextField("アーティスト", text: $artist)
                    TextField("https://…", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("この曲を添える") {
                        song = Song(id: UUID().uuidString, title: title.trimmed, artist: artist.trimmed, url: link.trimmed, previewURL: "", artworkURL: "")
                        dismiss()
                    }.disabled(title.trimmed.isEmpty || artist.trimmed.isEmpty || Validation.safeMusicURL(link.trimmed) == nil)
                }
            } footer: { Text("Apple Music・Spotify・YouTubeのリンクに対応しています。") }
        }.navigationTitle("贈る一曲").navigationBarTitleDisplayMode(.inline)
            .appBackButton()
    }
    private func search() {
        guard !query.trimmed.isEmpty, !busy else { return }
        busy = true; error = nil; searched = true
        let term = query.trimmed
        Task {
            defer { busy = false }
            do { results = try await MusicSearch.search(term) }
            catch { self.error = "曲を検索できませんでした。通信を確認するか、曲のリンクを直接入力してください。"; results = [] }
        }
    }
}

struct EmaComposer: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var goal = ""
    @State private var message = ""
    @State private var consent = false
    @State private var busy = false
    @State private var error: String?
    @State private var success = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeading(eyebrow: "NEGAU", title: "願いを、ここに", subtitle: "書きとめることが、最初の一歩。")
                EmaArtwork(goal: goal, name: name).padding(.vertical, 8)
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("叶えたい願い").font(.headline)
                        TextField("例：第一志望の学校に合格したい", text: $goal, axis: .vertical).lineLimit(2...4)
                        Text("\(goal.count) / 60文字").font(.caption).foregroundStyle(ShrineTheme.muted)
                        Divider()
                        TextField("お名前（30文字まで）", text: $name)
                        Divider()
                        TextField("願いに込めた気持ち（任意・300文字まで）", text: $message, axis: .vertical).lineLimit(3...6)
                    }
                }
                Toggle(isOn: $consent) {
                    Text(store.isDemo ? "体験モードのみんなの絵馬に飾る" : "名前と願いを、ログインしているみんなに公開する").font(.subheadline)
                }
                Text("絵馬を見た人から、お守りで応援が届きます。公開したくない情報は書かないでください。").font(.footnote).foregroundStyle(ShrineTheme.muted)
                if let error { Text(error).foregroundStyle(ShrineTheme.vermilion) }
                Button {
                    busy = true
                    Task {
                        defer { busy = false }
                        do {
                            try await store.createEma(Ema(ownerID: store.myID, name: name.trimmed, goal: goal.trimmed, message: message.trimmed))
                            success = true
                        } catch { self.error = error.localizedDescription }
                    }
                } label: { if busy { ProgressView().tint(.white) } else { Text("絵馬を奉納する") } }
                    .buttonStyle(PrimaryButton()).disabled(busy || !consent || name.trimmed.isEmpty || goal.trimmed.isEmpty || goal.count > 60 || name.count > 30 || message.count > 300 || success)
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("絵馬を書く").navigationBarTitleDisplayMode(.inline)
            .appBackButton(disabled: busy)
            .onAppear { if name.isEmpty { name = store.user?.name ?? "" } }
            .alert("願いを奉納しました", isPresented: $success) { Button("みんなの応援を待つ") { dismiss() } } message: { Text("「みんなの絵馬」と「コレクション」に絵馬が飾られました。") }
    }
}
