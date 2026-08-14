import FirebaseFirestore
import FirebaseStorage
import Foundation

final class AppServices {
    static let shared = AppServices()

    let db = Firestore.firestore()
    let storage = Storage.storage()

    lazy var auth = AuthService(db: db)
    lazy var groups = GroupService(db: db)
    lazy var diaries = DiaryService(db: db)
    lazy var stickers = StickerService(db: db, storage: storage)

    private init() {}
}
