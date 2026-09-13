import SwiftUI

/// Shared by the actual screen and the render previews. No duplicate mockup layout.
struct CollectionPresentation: View {
    @Binding var kind: CollectionKind
    @Binding var charmFilter: CharmCollectionFilter
    @Binding var emaFilter: EmaCollectionFilter
    @Binding var order: CollectionOrder
    let charms: [Omamori]
    let emas: [Ema]
    let userID: String
    var loading = false
    var onCharm: (Omamori) -> Void
    var onDedicate: (Omamori) -> Void
    var onEma: (Ema) -> Void
    var onSupport: (Ema) -> Void
    var onCreate: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var selectedCharms: [Omamori] { CollectionSelection.charms(charms, userID: userID, filter: charmFilter, order: order) }
    var selectedEmas: [Ema] { CollectionSelection.emas(emas, charms: charms, userID: userID, filter: emaFilter, order: order) }
    var count: Int { kind == .charms ? selectedCharms.count : selectedEmas.count }

    var body: some View {
        GeometryReader { geometry in
            ScrollView { contents(width: geometry.size.width) }
        }.background(ShrineTheme.paper).foregroundStyle(ShrineTheme.ink)
    }
    // Exposes the same content for static rendering without platform scroll containers.
    func contents(width: CGFloat, staticPreview: Bool = false) -> some View {
                VStack(spacing: 0) {
                    tabs.padding(.top, 8)
                    Group {
                        if staticPreview { filterItems } else { filters }
                    }.padding(.top, 18)
                    HStack {
                        Text(kind == .charms ? "お守りコレクション" : "絵馬コレクション")
                            .font(.system(.headline, design: .serif))
                        Text("\(count)こ").font(.subheadline).foregroundStyle(ShrineTheme.muted)
                        Spacer(minLength: 4)
                        if staticPreview {
                            Label(order.rawValue, systemImage: "arrow.up.arrow.down").font(.caption).frame(minHeight: 44).foregroundStyle(ShrineTheme.vermilion)
                        } else {
                        Menu {
                            Picker("並び順", selection: $order) {
                                ForEach(CollectionOrder.allCases) { value in Text(value.rawValue).tag(value) }
                            }
                        } label: {
                            Label(order.rawValue, systemImage: "arrow.up.arrow.down")
                                .font(.caption).frame(minHeight: 44)
                        }.accessibilityIdentifier("collection.sort")
                        }
                    }.padding(.horizontal, 20).padding(.top, 16)
                    if loading && count == 0 {
                        ProgressView("コレクションを読み込み中…").frame(maxWidth: .infinity).padding(.vertical, 70)
                    } else if count == 0 {
                        emptyState.padding(.horizontal, 24).padding(.vertical, 44)
                    } else {
                        grid(width: min(width, 760)).padding(.horizontal, 20).padding(.top, 14)
                    }
                    if count > 0 {
                        Text(kind == .charms ? "ひとつひとつに、あなたへ届いた想い。" : "あの日の願いも、届けた応援も、ここに。")
                            .font(.footnote).foregroundStyle(ShrineTheme.muted)
                            .multilineTextAlignment(.center).padding(.horizontal, 24).padding(.top, 30)
                    }
                }.padding(.bottom, 32).frame(maxWidth: 760).frame(maxWidth: .infinity)
    }
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(CollectionKind.allCases) { value in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { kind = value }
                } label: {
                    VStack(spacing: 13) {
                        HStack(spacing: 8) {
                            Image(systemName: value == .charms ? "gift" : "leaf")
                            Text(value.rawValue).fontWeight(kind == value ? .semibold : .regular)
                        }.font(.body)
                        Rectangle().fill(kind == value ? ShrineTheme.vermilion : .clear).frame(height: 3)
                    }.foregroundStyle(kind == value ? ShrineTheme.vermilion : ShrineTheme.muted)
                        .frame(maxWidth: .infinity).padding(.top, 14).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(kind == value ? .isSelected : [])
                    .accessibilityIdentifier(value == .charms ? "collection.charms" : "collection.emas")
            }
        }.padding(.horizontal, 20).overlay(alignment: .bottom) { Rectangle().fill(ShrineTheme.wood.opacity(0.25)).frame(height: 1) }
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) { filterItems }
    }
    private var filterItems: some View {
        HStack(spacing: 8) {
            if kind == .charms {
                ForEach(CharmCollectionFilter.allCases) { filter in
                    chip(filter.rawValue, selected: charmFilter == filter) { charmFilter = filter }
                }
            } else {
                ForEach(EmaCollectionFilter.allCases) { filter in
                    chip(filter.rawValue, selected: emaFilter == filter) { emaFilter = filter }
                }
            }
        }.padding(.horizontal, 20)
    }
    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 16).frame(minHeight: 44)
                .foregroundStyle(selected ? .white : ShrineTheme.muted)
                .background(selected ? ShrineTheme.vermilion : .white.opacity(0.65), in: Capsule())
                .overlay { Capsule().stroke(selected ? .clear : ShrineTheme.wood.opacity(0.3), lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func grid(width: CGFloat) -> some View {
        let minimum: CGFloat = typeSize.isAccessibilitySize ? 230 : (typeSize >= .xxLarge ? 145 : (kind == .charms ? 78 : 105))
        let preferred = kind == .charms ? 4 : 3
        let columns = max(1, min(preferred, Int((width - 30) / (minimum + 8))))
        let itemWidth = (width - 40 - CGFloat(columns - 1) * 10) / CGFloat(columns)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: columns), alignment: .center, spacing: 26) {
            if kind == .charms {
                ForEach(selectedCharms) { charm in
                    charmTile(charm, width: itemWidth)
                }
            } else {
                ForEach(selectedEmas) { ema in
                    emaTile(ema, width: itemWidth)
                }
            }
        }
    }
    private func charmTile(_ charm: Omamori, width: CGFloat) -> some View {
        let received = charm.recipientID == userID
        let canDedicate = received && charm.dedicatedAt == nil
        return VStack(spacing: 4) {
            Button { onCharm(charm) } label: {
                VStack(spacing: 9) {
                    CharmArtwork(color: charm.color, blessing: charm.blessing, width: min(72, width * 0.75))
                        .frame(height: 130, alignment: .center)
                        .opacity(charm.dedicatedAt == nil ? 1 : 0.65)
                    Text(charm.blessing).font(.footnote.weight(.medium)).lineLimit(1)
                    Text(received ? "\(charm.senderName)より" : "\(charm.recipientName)へ")
                        .font(.caption).foregroundStyle(ShrineTheme.muted).lineLimit(1)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(charm.blessing)、\(charm.senderName)から\(charm.recipientName)へ。詳細を見る")
            Button { canDedicate ? onDedicate(charm) : onCharm(charm) } label: {
                Text(charm.dedicatedAt != nil ? "奉納済み" : (canDedicate ? "奉納する" : "詳細を見る"))
                    .font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(canDedicate ? ShrineTheme.vermilion : ShrineTheme.muted)
                    .background(canDedicate ? Color.white.opacity(0.85) : ShrineTheme.wood.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityLabel("\(charm.blessing)を\(canDedicate ? "奉納する" : "見る")")
        }
    }
    private func emaTile(_ ema: Ema, width: CGFloat) -> some View {
        VStack(spacing: 5) {
            Button { onEma(ema) } label: {
                VStack(spacing: 10) {
                    CollectionEmaThumbnail(ema: ema).frame(height: max(94, min(135, width * 0.92)))
                    Text(ema.goal.replacingOccurrences(of: "\n", with: " ")).font(.footnote.weight(.medium)).lineLimit(2).frame(minHeight: 38, alignment: .top)
                    Text(ema.name).font(.caption).foregroundStyle(ShrineTheme.muted).lineLimit(1)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(ema.name)の絵馬。\(ema.goal)。\(ema.fulfilled ? "叶った願い" : "挑戦中")。詳細を見る")
            Button { ema.ownerID == userID ? onEma(ema) : onSupport(ema) } label: {
                Text(ema.ownerID == userID ? (ema.fulfilled ? "叶った願い" : "願いを見る") : "応援する")
                    .font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(ShrineTheme.vermilion).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityLabel("\(ema.name)の絵馬を\(ema.ownerID == userID ? "見る" : "応援する")")
        }
    }
    private var emptyState: some View {
        VStack(spacing: 17) {
            Image(systemName: kind == .charms ? "gift" : "leaf").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(ShrineTheme.vermilion.opacity(0.7))
            Text("\(kind == .charms ? charmFilter.rawValue : emaFilter.rawValue)の\(kind.rawValue)はまだありません")
                .font(.headline).multilineTextAlignment(.center)
            Text(kind == .charms ? "贈ったお守りや、受け取ったお守りが\nこの場所に並びます。" : "自分の願いと、お守りで応援した願いが\nこの場所に並びます。")
                .font(.subheadline).foregroundStyle(ShrineTheme.muted).multilineTextAlignment(.center).lineSpacing(5)
            Button(action: onCreate) { Label(kind == .charms ? "お守りをつくる" : "絵馬を書く", systemImage: "plus").font(.subheadline.weight(.semibold)).padding(.horizontal, 22).frame(minHeight: 48).background(.white, in: Capsule()) }
                .buttonStyle(.plain).foregroundStyle(ShrineTheme.vermilion)
        }.frame(maxWidth: .infinity)
    }
}

struct CollectionEmaThumbnail: View {
    let ema: Ema
    var body: some View {
        ZStack {
            EmaSilhouette().fill(LinearGradient(colors: [Color(red: 0.95, green: 0.84, blue: 0.66), ShrineTheme.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
            EmaSilhouette().stroke(.brown.opacity(0.18), lineWidth: 1).padding(4)
            VStack(spacing: 5) {
                Capsule().fill(ShrineTheme.vermilion.opacity(0.8)).frame(width: 4, height: 16)
                Image(systemName: ema.fulfilled ? "checkmark.seal" : "leaf").font(.system(size: 21, weight: .light)).foregroundStyle(ShrineTheme.vermilion)
                Text(ema.fulfilled ? "成 就" : "奉 納").font(.caption2).foregroundStyle(ShrineTheme.ink.opacity(0.8))
            }.padding(.top, 4)
        }.shadow(color: ShrineTheme.wood.opacity(0.18), radius: 5, y: 4).accessibilityHidden(true)
    }
}
