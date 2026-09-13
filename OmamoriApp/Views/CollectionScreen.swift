import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var store: AppStore
    @State private var kind: CollectionKind = .charms
    @State private var charmFilter: CharmCollectionFilter = .all
    @State private var emaFilter: EmaCollectionFilter = .all
    @State private var order: CollectionOrder = .newest
    @State private var selectedCharm: Omamori?
    @State private var selectedEma: Ema?
    @State private var dedication: Omamori?
    @State private var support: Ema?
    @State private var createCharm = false
    @State private var createEma = false

    var body: some View {
        CollectionPresentation(kind: $kind, charmFilter: $charmFilter, emaFilter: $emaFilter, order: $order,
                               charms: store.charms, emas: store.emas, userID: store.myID, loading: store.loading,
                               onCharm: { selectedCharm = $0 }, onDedicate: { dedication = $0 },
                               onEma: { selectedEma = $0 }, onSupport: { support = $0 },
                               onCreate: { if kind == .charms { createCharm = true } else { createEma = true } })
            .background(ShrineTheme.paper.ignoresSafeArea())
            .navigationTitle("コレクション").navigationBarTitleDisplayMode(.inline)
            .appBackButton()
            .toolbarBackground(ShrineTheme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { if kind == .charms { createCharm = true } else { createEma = true } } label: {
                        Image(systemName: "plus").accessibilityLabel(kind == .charms ? "お守りをつくる" : "絵馬を書く")
                    }
                }
            }
            .refreshable { await store.refresh() }
            .navigationDestination(item: $selectedCharm) { CharmDetail(charm: $0) }
            .navigationDestination(item: $selectedEma) { EmaDetail(ema: $0) }
            .navigationDestination(item: $support) { CharmComposer(ema: $0) }
            .navigationDestination(isPresented: $createCharm) { CharmComposer() }
            .navigationDestination(isPresented: $createEma) { EmaComposer() }
            .sheet(item: $dedication) { charm in NavigationStack { DedicationView(charm: charm) }.environmentObject(store) }
            .onChange(of: store.myID) { _, _ in
                selectedCharm = nil; selectedEma = nil; dedication = nil; support = nil
                charmFilter = .all; emaFilter = .all
            }
    }
}

struct DedicationView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let charm: Omamori
    @State private var message = ""
    @State private var saving = false
    @State private var completed = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("支えてくれた想いに、ありがとう。").font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
                CharmArtwork(color: charm.color, blessing: charm.blessing, width: 135)
                Text("\(charm.senderName)からの\(charm.blessing)").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最後に、お礼のメッセージを").font(.headline)
                        TextField("支えになった気持ちを、ことばに。", text: $message, axis: .vertical)
                            .lineLimit(4...8).padding(12).background(ShrineTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("dedication.message")
                        Text("\(message.count) / 300文字").font(.caption).foregroundStyle(message.count > 300 ? ShrineTheme.vermilion : ShrineTheme.muted).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                Text("メッセージは\(charm.senderName)さんにも表示されます。奉納したお守りは削除されず、「奉納した」からいつでも見返せます。")
                    .font(.subheadline).foregroundStyle(ShrineTheme.muted).lineSpacing(5)
                if let error { Text(error).foregroundStyle(ShrineTheme.vermilion).font(.subheadline) }
                Button {
                    saving = true
                    Task {
                        defer { saving = false }
                        do { try await store.dedicate(charm, message: message); completed = true }
                        catch { self.error = error.localizedDescription }
                    }
                } label: {
                    if saving { ProgressView().tint(.white) }
                    else { Text("お礼を添えて奉納する") }
                }.buttonStyle(PrimaryButton()).disabled(saving || completed || message.trimmed.isEmpty || message.count > 300)
            }.padding(24).frame(maxWidth: 550).frame(maxWidth: .infinity)
        }.background(ShrineTheme.paper.ignoresSafeArea()).navigationTitle("お守りを奉納する").navigationBarTitleDisplayMode(.inline)
            .appBackButton(disabled: saving)
            .interactiveDismissDisabled(saving)
            .alert("お守りを奉納しました", isPresented: $completed) { Button("コレクションへ") { dismiss() } } message: { Text("受け取った想いと、お礼のことばを残しました。") }
    }
}
