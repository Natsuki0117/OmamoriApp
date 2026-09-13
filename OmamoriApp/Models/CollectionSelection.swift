import Foundation

enum CollectionKind: String, CaseIterable, Identifiable {
    case charms = "お守り", emas = "絵馬"
    var id: String { rawValue }
}
enum CharmCollectionFilter: String, CaseIterable, Identifiable {
    case all = "すべて", received = "もらった", sent = "贈った", dedicated = "奉納した"
    var id: String { rawValue }
}
enum EmaCollectionFilter: String, CaseIterable, Identifiable {
    case all = "すべて", mine = "自分の絵馬", supported = "応援した", fulfilled = "叶った"
    var id: String { rawValue }
}
enum CollectionOrder: String, CaseIterable, Identifiable {
    case newest = "新しい順", oldest = "古い順"
    var id: String { rawValue }
}
struct CollectionSelection {
    static func charms(_ records: [Omamori], userID: String, filter: CharmCollectionFilter, order: CollectionOrder) -> [Omamori] {
        records.filter { charm in
            guard !userID.isEmpty, charm.senderID == userID || charm.recipientID == userID else { return false }
            switch filter {
            case .all: return true
            case .received: return charm.recipientID == userID
            case .sent: return charm.senderID == userID
            case .dedicated: return charm.recipientID == userID && charm.dedicatedAt != nil
            }
        }.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return order == .newest ? lhs.createdAt > rhs.createdAt : lhs.createdAt < rhs.createdAt
        }
    }
    static func emas(_ records: [Ema], charms: [Omamori], userID: String, filter: EmaCollectionFilter, order: CollectionOrder) -> [Ema] {
        let supported = Set(charms.filter { $0.senderID == userID && !$0.emaID.isEmpty }.map(\.emaID))
        return records.filter { ema in
            guard !userID.isEmpty, ema.ownerID == userID || supported.contains(ema.id) else { return false }
            switch filter {
            case .all: return true
            case .mine: return ema.ownerID == userID
            case .supported: return supported.contains(ema.id)
            case .fulfilled: return ema.fulfilled
            }
        }.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return order == .newest ? lhs.createdAt > rhs.createdAt : lhs.createdAt < rhs.createdAt
        }
    }
}
