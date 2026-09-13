# おまもり — SwiftUIアプリ

## コレクション画面の更新（2026-09-14）

元アプリに統合済みです。Xcodeで実行し、下部の「コレクション」から開けます。

お守り4列・絵馬3列の一覧、絞り込み、並び替え、詳細表示、絵馬からの応援、お礼を添えて奉納する操作を追加しました。文字サイズと画面幅に合わせて列数を調整します。以前の保存データも読み込めます。

Firebase接続済みの場合は、奉納機能用に `Backend/firestore.rules` を再反映してください。本番ルールの自動公開は行っていません。


メッセージと曲をお守りに込めて贈り、絵馬で願いを共有するiOSアプリです。Xcode 16.2 / iOS 18.2以上。元のXcodeプロジェクトに実装しています。

## まず動かす

1. `OmamoriApp.xcodeproj` をXcodeで開きます。
2. 実行先にiOS 18.2以上のiPhoneシミュレータを選び、Run（⌘R）を押します。
3. 「端末内で体験する」を選びます。Firebaseは不要です。
4. 「つくる → お守り」で宛先を「友達：はる」にし、メッセージと曲を添えて贈ります。
5. 「わたし → 受け取りを体験する → はる」に切り替えると、お守りが届いています。
6. お守りをタップするとメッセージと曲が開きます。「コレクション」で贈った／もらったを絞り込めます。
7. 「みんなの絵馬」で別の人の絵馬を開き、「お守りで応援する」から贈れます。
8. 「つくる → 絵馬を書く」で願いを奉納できます。自分の絵馬は「願いが叶いました」に切り替えられます。

体験データはApplication Supportの `omamori-demo-v1.json` に保存されます。再起動しても残ります。体験アカウントは本物の認証アカウントではなく、別の端末には共有されません。曲の検索と試聴には通信が必要です。検索できない場合はApple Music・Spotify・YouTubeのHTTPSリンクを直接入力できます。

## Firebaseを接続する

Firebaseの設定ファイルは提供されていないため、クラウド認証・共有の実通信は未検証です。コードはFirebase公式REST APIを利用しており、Firebase SDKの追加は不要です。

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクトを作成または選択します。
2. iOSアプリを登録します。Bundle IDは `app.kanai.natsuki.OmamoriApp` です。
3. `GoogleService-Info.plist` をダウンロードし、プロジェクト内の `OmamoriApp/GoogleService-Info.plist` に置きます。XcodeのOmamoriAppターゲットに含まれていることを確認します。**サービスアカウントの秘密鍵は入れません。**
4. Authentication → Sign-in method で「メール／パスワード」を有効にします。
5. Cloud Firestoreの `(default)` データベースを作成します。
6. Firestore → ルールに `Backend/firestore.rules` の内容を貼り付けて公開します。「すべて読み書き可能」のテスト用ルールにはしないでください。
7. アプリを再ビルドします。開始画面に「ログイン・新規登録」が表示されます。
8. 2つのアカウントを作り、一方の「わたし」に表示される友達IDを、もう一方の「友達に追加する」に入力します。
9. お守りの作成画面で友達を指定して贈ります。相手側は画面を下に引くか、アプリを開き直して更新します。

Firebase CLIを既に使っている場合は、Backendフォルダで `firebase deploy --only firestore:rules --project YOUR_PROJECT_ID` でもルールを反映できます。自動的な本番デプロイは行っていません。

## 共有の仕組み

- **アプリ内**：友達IDで宛先を指定。友達以外にも公開絵馬からその作者宛てに応援できます。友達リストは自分用の連絡先です。相互承認型の申請ではありません。
- **リンク・AirDrop**：リンクで渡す宛先を選んで作成すると `omamori://receive/UUID` が発行されます。送る側と受け取る側の両方に、このアプリとログインが必要です。アプリ未インストール時のWeb受け取りページは含みません。
- **受け取り**：リンクを知っている人が1回だけ受け取れる招待方式です。名前は宛名の表示であり、本人確認には使いません。特定の人だけに限定する場合は友達宛て送信を使います。
- **NFC**：NDEF対応の書き込み可能な物理タグにリンクを書き込みます。既存のタグ内容は上書きされるため、空のタグを使用してください。受け取る側は「わたし → NFCタグから読み取る」で読み取ります。iPhone同士をかざす直接転送ではありません。
- **NFC実機設定**：Signing & Capabilitiesで利用できる開発チームを設定し、Near Field Communication Tag Readingを有効にします。利用説明文とNDEF entitlementは同梱済みです。シミュレータではNFCは使えません。
- **曲**：曲名、アーティスト、サービスへのリンクを保存します。iTunesに試聴URLがある曲はアプリ内で試聴できます。フル再生は各音楽サービスで行います。音源のコピー・アップロードは行いません。

## 公開範囲と保存

- `users/{uid}`：ログインユーザーはIDを指定して表示名を取得できます。メールやトークンは保存しません。一覧取得は禁止。
- `users/{uid}/friends/{friendID}`：自分だけが読み書きできます。
- `emas/{id}`：ログインユーザー全員が読めます。作成は本人、成就状態の変更は作者のみ。
- `omamori/{id}`：送信者と受取人だけが一覧から読めます。宛先未確定のものは秘密のUUIDリンクを知るログインユーザーだけが個別取得できます。受取人の確定後に再配布・再取得はできません。
- 認証トークンはKeychainに保存し、自動更新します。パスワードは保存しません。
- クラウドでは送信成功後に一覧に追加します。通信失敗は画面に表示し、入力内容を残します。
- 体験データとクラウドデータは分離し、体験データをクラウドへ自動アップロードしません。
- SwiftのDateはJSONEncoderの標準形式（2001-01-01からの秒数）でFirestoreの数値に保存します。

## 主なファイル

| ファイル | 役割 |
| --- | --- |
| `Views/Design.swift` | 布・縫い目・結び目を持つお守り、木目入り絵馬、共通色 |
| `Views/CreationViews.swift` | お守り・絵馬の作成とライブプレビュー、曲選択 |
| `Views/CharmDetail.swift` | お守りを開く動き、メッセージ、試聴、共有 |
| `Views/CollectionViews.swift` | 公開絵馬、応援、コレクション、プロフィール |
| `Services/AppStore.swift` | 作成、保存、送受信、体験アカウントの切り替え |
| `Services/FirebaseService.swift` | Authentication、Keychain、Firestore REST通信 |
| `Services/NFCService.swift` | NFCタグへのリンク書き込み・読み取り |
| `Backend/firestore.rules` | クラウド上のアクセス制御 |

## 検証状況（2026-09-10）

- iOS Simulator向けアプリの `xcodebuild build` 成功。
- 単体テストを含む `xcodebuild build-for-testing` 成功。
- `Scripts/verify-core.sh` で実際のモデルとAppStoreを使う16項目の検証に成功。端末保存、再起動後の復元、宛先別一覧、成就変更権限、リンクの受け取り、二重受け取り拒否、Firestoreへの変換など。
- SwiftUIの実装パーツを画像にレンダリングして描画を確認。
- この実行環境ではCoreSimulatorサービスへの接続が制限されたため、iOSシミュレータ上の画面操作・XCTest実行は未実施。
- Firebase実プロジェクト接続、Security Rulesのエミュレータ実行、実ユーザー間の送受信、曲検索・試聴の端末実通信、AirDrop・NFCの実機送受信は未検証。

## 接続後の確認

2アカウントで登録・ログイン・再ログイン → 友達ID追加 → お守り送信 → 相手の受信一覧更新 → 公開絵馬作成 → 別アカウントから応援 → 絵馬作者の応援一覧 → 未指定宛先のリンク受け取り → 3人目による同じリンクの受け取り拒否 → AirDrop → NFCタグ書き込み・読み取りの順に確認します。

## 使用した公式資料

- [Firebase Authentication REST](https://firebase.google.com/docs/reference/rest/auth)
- [Firestore RESTとFirebase ID token](https://firebase.google.com/docs/firestore/use-rest-api)
- [Firestore runQuery](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/runQuery)
- [Apple iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html)
- [Apple Core NFC](https://developer.apple.com/documentation/corenfc/nfcndefreadersession)
