import FirebaseFirestore
import Foundation

final class DiaryService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func diaryId(groupId: String, dateKey: String) -> String {
        "\(groupId)_\(dateKey)"
    }

    func ensureTodayDiary(group: PetankoGroup, dateKey: String) async throws -> DiaryPage {
        let id = diaryId(groupId: group.id, dateKey: dateKey)
        let ref = db.collection("diaries").document(id)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(), snapshot.exists {
            return DiaryPage(id: id, data: data)
        }

        let page = DiaryPage(id: id, groupId: group.id, dateKey: dateKey, title: Date().petankoShortTitle)
        try await ref.setData(page.dictionary, merge: true)
        return page
    }

    func observeDiary(groupId: String, dateKey: String, onChange: @escaping (DiaryPage?, Error?) -> Void) -> ListenerRegistration {
        let id = diaryId(groupId: groupId, dateKey: dateKey)
        return db.collection("diaries").document(id).addSnapshotListener { snapshot, error in
            if let error {
                onChange(nil, error)
                return
            }
            guard let snapshot, let data = snapshot.data(), snapshot.exists else {
                onChange(nil, nil)
                return
            }
            onChange(DiaryPage(id: id, data: data), nil)
        }
    }

    func saveDiaryLayout(_ diary: DiaryPage) async throws {
        try await db.collection("diaries").document(diary.id).setData(diary.dictionary, merge: true)
    }

    func acquireEditLock(groupId: String, diaryId: String, user: AppUser) async throws -> Bool {
        let ref = db.collection("editLocks").document(diaryId)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(),
           let lockedBy = data["lockedBy"] as? String,
           lockedBy != user.id,
           let expiresAt = data["expiresAt"] as? Timestamp,
           expiresAt.dateValue() > Date() {
            return false
        }

        try await ref.setData(
            [
                "groupId": groupId,
                "diaryId": diaryId,
                "lockedBy": user.id,
                "lockedByName": user.displayName,
                "expiresAt": Timestamp(date: Date().addingTimeInterval(10 * 60)),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
        return true
    }

    func releaseEditLock(diaryId: String, userId: String) async throws {
        let ref = db.collection("editLocks").document(diaryId)
        let snapshot = try await ref.getDocument()
        guard snapshot.data()?["lockedBy"] as? String == userId else { return }
        try await ref.delete()
    }
}
