import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) var phase
    @State private var showingWelcome = false
    var body: some View {
        Group {
            if store.user == nil || showingWelcome {
                WelcomeView(onContinue: { showingWelcome = false })
            } else {
                MainTabs(onBackToWelcome: { showingWelcome = true })
            }
        }
        .tint(ShrineTheme.vermilion).foregroundStyle(ShrineTheme.ink)
        .task { await store.restore() }
        .onOpenURL { url in Task { await store.handle(url) } }
        .onChange(of: phase) { _, value in if value == .active { Task { await store.refresh() } } }
        .alert("お知らせ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .sheet(item: $store.incoming) { charm in NavigationStack { CharmDetail(charm: charm) }.environmentObject(store) }
    }
}

struct MainTabs: View {
    @EnvironmentObject var store: AppStore
    var onBackToWelcome: () -> Void
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView().environment(\.rootBackAction, onBackToWelcome) }
                .tabItem { Label("おまもり", systemImage: "house") }.tag(0)
            NavigationStack { EmaFeedView().environment(\.rootBackAction, { selectedTab = 0 }) }
                .tabItem { Label("みんなの絵馬", systemImage: "leaf") }.tag(1)
            NavigationStack { CreateHubView().environment(\.rootBackAction, { selectedTab = 0 }) }
                .tabItem { Label("つくる", systemImage: "plus.circle") }.tag(2)
            NavigationStack { CollectionView().environment(\.rootBackAction, { selectedTab = 0 }) }
                .tabItem { Label("コレクション", systemImage: "square.grid.2x2") }.tag(3)
            NavigationStack { ProfileView().environment(\.rootBackAction, { selectedTab = 0 }) }
                .tabItem { Label("わたし", systemImage: "person.crop.circle") }.tag(4)
        }
        .toolbarBackground(ShrineTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.isDemo {
                Text("体験モード · データはこの端末だけに保存されます")
                    .font(.caption).foregroundStyle(ShrineTheme.muted).frame(maxWidth: .infinity)
                    .padding(.vertical, 6).background(ShrineTheme.paper)
            }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var store: AppStore
    var onContinue: () -> Void = {}
    @State private var auth = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("想いを結ぶ").font(.subheadline).tracking(5).foregroundStyle(ShrineTheme.muted).padding(.top, 40)
                HStack(alignment: .center, spacing: 26) {
                    CharmArtwork(color: .cream, blessing: "縁結び", width: 95).rotationEffect(.degrees(-12)).offset(y: 14)
                    CharmArtwork(color: .coral, blessing: "応援守り", width: 140).rotationEffect(.degrees(8))
                }.padding(.vertical, 20).accessibilityHidden(true)
                Text("おまもり").font(.system(size: 42, weight: .medium, design: .serif)).tracking(8)
                Text("ことばと音楽を、小さなお守りに。\nあなたの「応援しているよ」を届けよう。")
                    .multilineTextAlignment(.center).lineSpacing(7).foregroundStyle(ShrineTheme.muted)
                VStack(spacing: 14) {
                    if store.pendingURL != nil { Label("届いたお守りがあります。ログインして受け取りましょう。", systemImage: "gift").font(.subheadline) }
                    if store.user != nil {
                        Button("アプリに戻る", action: onContinue).buttonStyle(PrimaryButton())
                    } else if store.configured {
                        Button("ログイン・新規登録") { auth = true }.buttonStyle(PrimaryButton())
                        Button("端末内で体験する") { store.startDemo(); onContinue() }.padding(8)
                    } else {
                        Button("端末内で体験する") { store.startDemo(); onContinue() }.buttonStyle(PrimaryButton())
                        Text("Firebase接続前でも、作成・応援・受け取りを試せます。実際のユーザー間共有にはFirebaseの設定が必要です。")
                            .font(.footnote).foregroundStyle(ShrineTheme.muted).lineSpacing(4)
                    }
                    if store.loading { ProgressView("ログインを確認中…") }
                }.padding(.top, 12)
            }.padding(28).frame(maxWidth: 550)
                .frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea())
            .sheet(isPresented: $auth) { NavigationStack { AuthView() } }
    }
}

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var register = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Form {
            Picker("アカウント", selection: $register) { Text("ログイン").tag(false); Text("新規登録").tag(true) }.pickerStyle(.segmented)
            if register { TextField("お名前（30文字以内）", text: $name).textContentType(.nickname) }
            TextField("メールアドレス", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)
            SecureField("パスワード（6文字以上）", text: $password).textContentType(register ? .newPassword : .password)
            Button {
                busy = true
                Task {
                    defer { busy = false }
                    do { try await store.authenticate(email: email, password: password, name: name, register: register); dismiss() }
                    catch { message = error.localizedDescription }
                }
            } label: { if busy { ProgressView() } else { Text(register ? "登録する" : "ログイン") } }
            .disabled(busy || email.trimmed.isEmpty || password.count < 6 || (register && name.trimmed.isEmpty))
            if !register {
                Button("パスワードを再設定") {
                    busy = true
                    Task {
                        defer { busy = false }
                        do { try await store.cloud?.resetPassword(email: email.trimmed); message = "該当するアカウントがある場合、再設定メールが届きます。" }
                        catch { message = error.localizedDescription }
                    }
                }.disabled(busy || email.trimmed.isEmpty)
            }
            if let message { Text(message).font(.subheadline).foregroundStyle(ShrineTheme.vermilion) }
        }.navigationTitle(register ? "はじめまして" : "おかえりなさい")
            .appBackButton(disabled: busy)
            .interactiveDismissDisabled(busy)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: "OMAMORI", title: "\(store.user?.name ?? "")さん、おかえりなさい", subtitle: "今日も、あなたらしい一歩を。")
                HStack(spacing: 18) {
                    CharmArtwork(color: .coral, blessing: "応援守り", width: 115).padding(.leading, 10)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("想いを込めて、\nひとつ結ぼう。").font(.system(.title2, design: .serif)).lineSpacing(6)
                        Text("大切な人へ\nことばと一曲のお守りを。")
                            .font(.subheadline).foregroundStyle(ShrineTheme.muted).lineSpacing(5)
                        NavigationLink { CharmComposer() } label: { Text("お守りをつくる").font(.subheadline.weight(.semibold)).padding(12).background(.white.opacity(0.8), in: Capsule()) }
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 20).background(Color(red: 0.95, green: 0.88, blue: 0.80), in: RoundedRectangle(cornerRadius: 28))
                HStack {
                    Text("届いた想い").font(.system(.title2, design: .serif))
                    Spacer()
                    Text("\(store.received.count) こ").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                }
                if store.received.isEmpty {
                    PaperCard { Text("届いたお守りがここに並びます。友達にIDを伝えて、想いをつなげましょう。").foregroundStyle(ShrineTheme.muted).lineSpacing(5) }
                } else {
                    ForEach(store.received.prefix(3)) { charm in
                        NavigationLink { CharmDetail(charm: charm) } label: { CharmRow(charm: charm) }.buttonStyle(.plain)
                    }
                }
                NavigationLink { EmaFeedView() } label: {
                    PaperCard {
                        HStack {
                            Image(systemName: "leaf").font(.title2)
                            VStack(alignment: .leading, spacing: 5) { Text("誰かの願いに、そっとエールを").font(.headline); Text("みんなの絵馬を見にいく").font(.subheadline).foregroundStyle(ShrineTheme.muted) }
                            Spacer(); Image(systemName: "chevron.right")
                        }
                    }
                }.buttonStyle(.plain)
            }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("おまもり").navigationBarTitleDisplayMode(.inline)
            .appBackButton()
            .refreshable { await store.refresh() }
    }
}

struct CharmRow: View {
    let charm: Omamori
    var body: some View {
        PaperCard {
            HStack(spacing: 22) {
                CharmArtwork(color: charm.color, blessing: charm.blessing, width: 52)
                VStack(alignment: .leading, spacing: 7) {
                    Text(charm.blessing).font(.headline)
                    Text("\(charm.senderName) → \(charm.recipientName)").font(.subheadline)
                    Label(charm.song.title, systemImage: "music.note").font(.footnote).foregroundStyle(ShrineTheme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShrineTheme.muted)
            }
        }
    }
}
