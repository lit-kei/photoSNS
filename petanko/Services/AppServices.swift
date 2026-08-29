import FirebaseFirestore
import FirebaseStorage
import Foundation

final class AppServices {
    static let shared = AppServices()

    let db = Firestore.firestore()
    let storage = Storage.storage()

    lazy var auth = AuthService(db: db, storage: storage)
    lazy var groups = GroupService(db: db, storage: storage)
    lazy var friends = FriendService(db: db)
    lazy var diaries = DiaryService(db: db)
    lazy var stickers = StickerService(db: db, storage: storage)
    lazy var blocks = BlockService(db: db)
    lazy var accountDeletion = AccountDeletionService(db: db, storage: storage, auth: auth)

    private init() {}
}
