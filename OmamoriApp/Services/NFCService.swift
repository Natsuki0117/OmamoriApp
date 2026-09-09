import Foundation
import CoreNFC

final class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var message: String?
    private var session: NFCNDEFReaderSession?
    private var pendingWrite: URL?
    private var receive: ((URL) -> Void)?
    func write(_ url: URL) {
        pendingWrite = url
        receive = nil
        begin("お守りを渡すNFCタグを、iPhoneの上部に近づけてください。")
    }
    func read(_ completion: @escaping (URL) -> Void) {
        pendingWrite = nil
        receive = completion
        begin("お守りのNFCタグを、iPhoneの上部に近づけてください。")
    }
    private func begin(_ instruction: String) {
        guard NFCNDEFReaderSession.readingAvailable else { message = "この端末ではNFCを利用できません。対応する実機のiPhoneで試すか、リンク・AirDropをご利用ください。"; return }
        guard session == nil else { return }
        let value = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        value.alertMessage = instruction
        session = value
        value.begin()
    }
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        let value = error as? NFCReaderError
        if value?.code != .readerSessionInvalidationErrorUserCanceled && value?.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
            DispatchQueue.main.async { self.message = "NFCを利用できませんでした。タグと接続を確認してください。実機ではNFCの署名設定も必要です。" }
        }
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        process(messages, session: session)
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else { session.alertMessage = "タグを1枚だけ近づけてください。"; session.restartPolling(); return }
        session.connect(to: tag) { error in
            if error != nil { session.invalidate(errorMessage: "タグに接続できませんでした。"); return }
            if let url = self.pendingWrite {
                tag.queryNDEFStatus { status, capacity, error in
                    guard error == nil, status == .readWrite else { session.invalidate(errorMessage: "書き込み可能なNFCタグを使ってください。"); return }
                    guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else { session.invalidate(errorMessage: "リンクを作成できませんでした。"); return }
                    let record = NFCNDEFMessage(records: [payload])
                    guard record.length <= capacity else { session.invalidate(errorMessage: "このタグは容量が足りません。"); return }
                    tag.writeNDEF(record) { error in
                        if error != nil { session.invalidate(errorMessage: "書き込みに失敗しました。もう一度お試しください。"); return }
                        session.alertMessage = "お守りを書き込みました。相手にタグを渡しましょう。"
                        session.invalidate()
                        DispatchQueue.main.async { self.message = "NFCタグにお守りの受け取りリンクを書き込みました。" }
                    }
                }
            } else {
                tag.readNDEF { message, error in
                    guard error == nil, let message else { session.invalidate(errorMessage: "タグを読み取れませんでした。"); return }
                    self.process([message], session: session)
                }
            }
        }
    }
    private func process(_ messages: [NFCNDEFMessage], session: NFCNDEFReaderSession) {
        for message in messages {
            for record in message.records {
                if let url = record.wellKnownTypeURIPayload(), Validation.receivedID(url) != nil {
                    session.alertMessage = "お守りが見つかりました。"
                    session.invalidate()
                    DispatchQueue.main.async { self.receive?(url) }
                    return
                }
            }
        }
        session.invalidate(errorMessage: "お守りの受け取りリンクが入ったタグではありません。")
    }
}
