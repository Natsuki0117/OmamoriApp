import SwiftUI

struct EmaFeedView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeading(eyebrow: "NEGAI", title: "みんなの願いが、ここに", subtitle: "心にとまった願いに、お守りでエールを。")
                if store.emas.isEmpty { EmptyCollection(title: "最初の願いを飾ろう", message: "あなたの目標を、絵馬に書いてみませんか。", symbol: "leaf") }
                ForEach(store.emas) { ema in
                    NavigationLink { EmaDetail(ema: ema) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            EmaArtwork(goal: ema.goal, name: ema.name, fulfilled: ema.fulfilled)
                            HStack {
                                Text(ema.createdAt, style: .date).font(.caption).foregroundStyle(ShrineTheme.muted)
                                Spacer()
                                Label(ema.fulfilled ? "願いが叶いました" : "願いを読む", systemImage: ema.fulfilled ? "checkmark.seal" : "heart").font(.subheadline).foregroundStyle(ShrineTheme.vermilion)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("みんなの絵馬").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { NavigationLink { EmaComposer() } label: { Image(systemName: "square.and.pencil").accessibilityLabel("絵馬を書く") } } }
            .refreshable { await store.refresh() }
    }
}
struct EmaDetail: View {
    @EnvironmentObject var store: AppStore
    let ema: Ema
    @State private var busy = false
    var current: Ema { store.emas.first { $0.id == ema.id } ?? ema }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                EmaArtwork(goal: current.goal, name: current.name, fulfilled: current.fulfilled)
                if !current.message.isEmpty {
                    PaperCard { Text(current.message).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading) }
                }
                Text("\(current.name) · \(current.createdAt.formatted(date: .abbreviated, time: .omitted))") .font(.subheadline).foregroundStyle(ShrineTheme.muted)
                if current.ownerID != store.myID {
                    NavigationLink { CharmComposer(ema: current) } label: { Label("お守りで応援する", systemImage: "heart") }.buttonStyle(PrimaryButton())
                    Text("この願いを書いた\(current.name)さんに届きます。") .font(.footnote).foregroundStyle(ShrineTheme.muted)
                } else {
                    Button {
                        busy = true
                        Task {
                            defer { busy = false }
                            do { try await store.fulfill(current) } catch { store.error = error.localizedDescription }
                        }
                    } label: { Text(current.fulfilled ? "挑戦中に戻す" : "願いが叶いました") }.buttonStyle(PrimaryButton()).disabled(busy)
                    let support = store.received.filter { $0.emaID == ema.id }
                    if !support.isEmpty {
                        Text("この願いに届いたお守り").font(.headline)
                        ForEach(support) { charm in NavigationLink { CharmDetail(charm: charm) } label: { CharmRow(charm: charm) }.buttonStyle(.plain) }
                    }
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("ひとつの願い").navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectionView: View {
    @EnvironmentObject var store: AppStore
    @State private var kind = 0
    @State private var filter = 0
    @State private var emaFilter = 0
    var charms: [Omamori] { filter == 1 ? store.received : filter == 2 ? store.sent : store.charms }
    var emas: [Ema] { store.emas.filter { $0.ownerID == store.myID && (emaFilter == 0 || $0.fulfilled == (emaFilter == 2)) } }
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PageHeading(eyebrow: "TAKARAMONO", title: "想いが並ぶ、たからもの", subtitle: "もらった勇気も、贈ったエールも。")
                Picker("コレクション", selection: $kind) { Text("お守り").tag(0); Text("絵馬").tag(1) }.pickerStyle(.segmented)
                if kind == 0 {
                    Picker("お守りの絞り込み", selection: $filter) { Text("すべて").tag(0); Text("もらった").tag(1); Text("贈った").tag(2) }.pickerStyle(.segmented)
                    if charms.isEmpty { EmptyCollection(title: "まだお守りがありません", message: "誰かへの想いを、ひとつ結んでみましょう。", symbol: "gift") }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 16)], spacing: 18) {
                        ForEach(charms) { charm in
                            NavigationLink { CharmDetail(charm: charm) } label: {
                                VStack(spacing: 12) {
                                    CharmArtwork(color: charm.color, blessing: charm.blessing, width: 88)
                                    Text(charm.blessing).font(.headline)
                                    Text(charm.senderID == store.myID ? "\(charm.recipientName)へ" : "\(charm.senderName)より").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                                    Text(charm.senderID == store.myID ? (charm.recipientID.isEmpty ? "お渡し待ち" : "贈ったお守り") : "もらったお守り")
                                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(ShrineTheme.paper, in: Capsule())
                                }.frame(maxWidth: .infinity).padding(.vertical, 20).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
                            }.buttonStyle(.plain)
                        }
                    }
                } else {
                    Picker("絵馬の絞り込み", selection: $emaFilter) { Text("すべて").tag(0); Text("挑戦中").tag(1); Text("叶った").tag(2) }.pickerStyle(.segmented)
                    if emas.isEmpty { EmptyCollection(title: "願いを残してみよう", message: "あなたが奉納した絵馬が並びます。", symbol: "leaf") }
                    ForEach(emas) { ema in NavigationLink { EmaDetail(ema: ema) } label: { EmaArtwork(goal: ema.goal, name: ema.name, fulfilled: ema.fulfilled) }.buttonStyle(.plain) }
                }
            }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("たからもの").navigationBarTitleDisplayMode(.inline).refreshable { await store.refresh() }
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var friendID = ""
    @State private var link = ""
    @State private var busy = false
    @State private var message: String?
    @StateObject private var nfc = NFCService()
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 65)).foregroundStyle(ShrineTheme.vermilion.opacity(0.65)).padding(.top, 20)
                Text(store.user?.name ?? "").font(.system(.title, design: .serif))
                Text("友達 \(store.friends.count) 人").foregroundStyle(ShrineTheme.muted)
                HStack(spacing: 14) {
                    stat("贈ったお守り", store.sent.count)
                    stat("もらったお守り", store.received.count)
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("友達とつながる", systemImage: "person.2").font(.headline)
                        Text("あなたの友達ID").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                        Text(store.myID).font(.footnote.monospaced()).textSelection(.enabled)
                        if !store.isDemo {
                            ShareLink(item: store.myID) { Label("IDを共有", systemImage: "square.and.arrow.up") }
                            Divider()
                            TextField("相手の友達ID", text: $friendID).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("友達に追加する") {
                                busy = true
                                Task {
                                    defer { busy = false }
                                    do { try await store.addFriend(id: friendID); friendID = ""; message = "友達に追加しました。お守りの作成画面から贈れます。" }
                                    catch { message = error.localizedDescription }
                                }
                            }.disabled(friendID.trimmed.isEmpty || busy)
                        }
                        ForEach(store.friends) { friend in Label(friend.name, systemImage: "person.crop.circle").font(.subheadline) }
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("お守りを受け取る", systemImage: "gift").font(.headline)
                        TextField("受け取りリンクを貼り付け", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("リンクを開く") {
                            guard let url = URL(string: link.trimmed) else { message = "正しいリンクを入力してください。"; return }
                            Task { await store.handle(url) }
                        }.disabled(link.trimmed.isEmpty)
                        if !store.isDemo { Button("NFCタグから読み取る") { nfc.read { url in Task { await store.handle(url) } } } }
                    }
                }
                if let message { Text(message).font(.subheadline).foregroundStyle(ShrineTheme.vermilion) }
                if store.isDemo {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("受け取りを体験する").font(.headline)
                            Text("相手に切り替えると、贈ったお守りを確認できます。実際のアカウントではありません。") .font(.footnote).foregroundStyle(ShrineTheme.muted)
                            ForEach(AppStore.demoPeople) { person in
                                Button { store.startDemo(as: person) } label: { HStack { Text(person.name); Spacer(); if person.id == store.myID { Image(systemName: "checkmark") } } }
                            }
                        }
                    }
                }
                Button(store.isDemo ? "体験を終了する" : "ログアウト") { store.signOut() }.padding()
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("わたし").navigationBarTitleDisplayMode(.inline)
            .alert("NFC", isPresented: Binding(get: { nfc.message != nil }, set: { if !$0 { nfc.message = nil } })) { Button("閉じる") { nfc.message = nil } } message: { Text(nfc.message ?? "") }
    }
    private func stat(_ title: String, _ count: Int) -> some View {
        PaperCard { VStack(spacing: 10) { Text(title).font(.subheadline); Text("\(count)").font(.system(size: 32, weight: .medium, design: .serif)) }.frame(maxWidth: .infinity) }
    }
}
