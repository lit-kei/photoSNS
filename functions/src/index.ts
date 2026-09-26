import {initializeApp} from "firebase-admin/app";
import {DocumentData, FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging, MulticastMessage} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";

initializeApp();

const db = getFirestore();
const region = "asia-northeast1";

type StickerTarget = "blog" | "group";

interface StickerPostData {
  id: string;
  target: StickerTarget;
  assetId: string;
  groupId: string;
  diaryId: string;
  dateKey: string;
  authorId: string;
  authorName: string;
  authorAvatar: string;
  comment: string;
  shape: string;
  decoration: string;
  outlineColorHex: string;
  creationMode: string;
  effect: string;
  stickerImageURL: string;
  originalStickerImageURL: string;
  layout: StickerLayoutData;
  createdAt: Timestamp;
}

interface StickerLayoutData {
  stickerId: string;
  x: number;
  y: number;
  scale: number;
  rotation: number;
  zIndex: number;
}

interface GroupData {
  id: string;
  name: string;
  memberIds: string[];
}

interface FinalizedStickerJob {
  jobId: string;
  userId: string;
  authorName: string;
  posts: StickerPostData[];
  groups: GroupData[];
  publishToBlog: boolean;
}

export const onStickerUploadJobCreated = onDocumentCreated(
  {document: "stickerUploadJobs/{jobId}", region},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const jobId = event.params.jobId;
    try {
      const finalized = await finalizeStickerUploadJob(jobId, snapshot.data());
      if (!finalized) return;
      await sendStickerNotifications(finalized);
      await snapshot.ref.set(
        {
          notificationsSent: true,
          notificationsSentAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    } catch (error) {
      logger.error("Sticker upload job failed", {jobId, error});
      await snapshot.ref.set(
        {
          status: "failed",
          errorMessage: userFacingErrorMessage(error),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }
  }
);

export const onFriendRequestCreated = onDocumentCreated(
  {document: "friendRequests/{requestId}", region},
  async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== "pending") return;

    const toUserId = stringValue(data.toUserId);
    const fromName = stringValue(data.fromName) || "petanko user";
    if (!toUserId) return;

    await sendToUser(toUserId, {
      notification: {
        title: "友達申請が届きました",
        body: `${fromName} から友達申請が届いています。`,
      },
      data: {
        petankoDestination: "friendRequests",
        friendRequestId: event.params.requestId,
        recipientUserId: toUserId,
      },
    });
  }
);

export const onGroupMemberCreated = onDocumentCreated(
  {document: "groupMembers/{memberId}", region},
  async (event) => {
    const data = event.data?.data();
    if (!data || data.joinSource !== "friend_invite") return;

    const groupId = stringValue(data.groupId);
    const userId = stringValue(data.userId);
    const invitedById = stringValue(data.invitedById);
    const invitedByName = stringValue(data.invitedByName) || "petanko user";
    if (!groupId || !userId || userId === invitedById) return;

    const group = await fetchGroupForNotification(groupId);
    await sendToUser(userId, {
      notification: {
        title: `${group.name}に追加されました`,
        body: `${invitedByName} があなたをグループに招待しました。`,
      },
      data: {
        petankoDestination: "groupDiary",
        groupId,
        dateKey: tokyoDateKey(new Date()),
        stickerId: "",
        groupMemberId: event.params.memberId,
        recipientUserId: userId,
      },
    });
  }
);

export const sendMemoryReminderNotifications = onSchedule(
  {
    schedule: "0 19 * * *",
    timeZone: "Asia/Tokyo",
    region,
    retryCount: 1,
  },
  async () => {
    const now = new Date();
    const sourceDateKey = tokyoDateKeyOneMonthAgo(now);
    if (!sourceDateKey) return;

    const diarySnapshot = await db.collection("diaries")
      .where("dateKey", "==", sourceDateKey)
      .get();
    const eligibleDiaries = diarySnapshot.docs
      .map((document) => ({
        groupId: stringValue(document.data().groupId),
        stickerCount: diaryStickerCount(document.data()),
      }))
      .filter((diary) => diary.groupId && diary.stickerCount >= 3);
    if (eligibleDiaries.length === 0) return;

    const uniqueGroupIds = Array.from(new Set(eligibleDiaries.map((diary) => diary.groupId)));
    const groups = await Promise.all(uniqueGroupIds.map(fetchGroupForNotification));
    const candidatesByUser = new Map<string, GroupData[]>();
    for (const group of groups) {
      for (const userId of group.memberIds) {
        const candidates = candidatesByUser.get(userId) ?? [];
        candidates.push(group);
        candidatesByUser.set(userId, candidates);
      }
    }

    for (const [userId, candidates] of candidatesByUser) {
      const stateRef = db.collection("memoryReminderStates").doc(userId);
      const stateSnapshot = await stateRef.get();
      const state = stateSnapshot.data() ?? {};
      const nextEligibleAt = state.nextEligibleAt;
      if (nextEligibleAt instanceof Timestamp && nextEligibleAt.toDate() > now) continue;
      if (stringValue(state.lastSourceDateKey) === sourceDateKey) continue;

      const candidate = candidates[Math.floor(Math.random() * candidates.length)];
      const sent = await sendToUser(userId, {
        notification: {
          title: "これ覚えてる？",
          body: `${candidate.name}の1か月前の絵日記を見返してみよう。`,
        },
        data: {
          petankoDestination: "groupDiary",
          groupId: candidate.id,
          dateKey: sourceDateKey,
          stickerId: "",
          recipientUserId: userId,
          reminderType: "oneMonthMemory",
          petankoNotificationCategory: "PETANKO_MEMORY_REMINDER",
        },
      });
      if (!sent) continue;

      const previousIntervalDays = numberValue(state.lastIntervalDays);
      const nextIntervalDays = memoryReminderIntervalDays(previousIntervalDays);
      await stateRef.set(
        {
          lastSentAt: FieldValue.serverTimestamp(),
          lastSourceDateKey: sourceDateKey,
          lastGroupId: candidate.id,
          lastIntervalDays: nextIntervalDays,
          nextEligibleAt: Timestamp.fromMillis(
            now.getTime() + nextIntervalDays * 24 * 60 * 60 * 1000
          ),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }
  }
);

async function finalizeStickerUploadJob(
  jobId: string,
  initialData: DocumentData
): Promise<FinalizedStickerJob | null> {
  const jobRef = db.collection("stickerUploadJobs").doc(jobId);
  const latestJob = await jobRef.get();
  const latestData = latestJob.data() ?? initialData;
  const status = stringValue(latestData.status);
  if (status === "completed") {
    if (latestData.notificationsSent === true) return null;
    return finalizedJobFromCompletedData(jobId, latestData);
  }
  if (status !== "pending") return null;

  const userId = requireString(latestData.userId, "ログイン情報を確認できませんでした。");
  const assetId = requireString(latestData.assetId, "ステッカー情報を確認できませんでした。");
  const storagePath = requireString(latestData.storagePath, "ステッカー画像を確認できませんでした。");
  const downloadURL = requireString(latestData.downloadURL, "ステッカー画像を確認できませんでした。");
  const originalStoragePath = stringValue(latestData.originalStoragePath);
  const originalDownloadURL = stringValue(latestData.originalDownloadURL);
  const publishToBlog = latestData.publishToBlog === true;
  const groupIds = stringArrayValue(latestData.groupIds);
  const uniqueGroupIds = Array.from(new Set(groupIds)).filter(Boolean);
  if (!publishToBlog && uniqueGroupIds.length === 0) {
    throw new Error("投稿先を選択してください。");
  }
  if (storagePath !== `stickerAssets/${userId}/${assetId}.png`) {
    throw new Error("ステッカー画像の保存先を確認できませんでした。");
  }
  if (originalStoragePath && originalStoragePath !== `stickerAssets/${userId}/${assetId}-original.png`) {
    throw new Error("色戻し用画像の保存先を確認できませんでした。");
  }

  const userSnapshot = await db.collection("users").doc(userId).get();
  if (!userSnapshot.exists) {
    throw new Error("ユーザー情報を確認できませんでした。");
  }
  const userData = userSnapshot.data() ?? {};
  const authorName = stringValue(userData.displayName) || stringValue(latestData.authorName) || "petanko user";
  const authorAvatar = stringValue(userData.avatar) || stringValue(latestData.authorAvatar);
  const groups = await fetchAndValidateGroups(uniqueGroupIds, userId);
  const createdAt = latestData.createdAt instanceof Timestamp ? latestData.createdAt : Timestamp.now();
  const posts = buildStickerPosts({
    jobId,
    userId,
    authorName,
    authorAvatar,
    assetId,
    downloadURL,
    originalDownloadURL,
    draft: objectValue(latestData.draft),
    publishToBlog,
    groups,
    createdAt,
  });

  await db.runTransaction(async (transaction) => {
    const transactionJob = await transaction.get(jobRef);
    const transactionData = transactionJob.data() ?? {};
    if (transactionData.status === "completed") return;
    if (transactionData.status !== "pending") {
      throw new Error("投稿処理を開始できませんでした。");
    }

    const postRefs = posts.map((post) => db.collection("stickers").doc(post.id));
    const postSnapshots = await Promise.all(postRefs.map((ref) => transaction.get(ref)));
    const assetRef = db.collection("stickerAssets").doc(assetId);
    transaction.set(
      assetRef,
      {
        ownerId: userId,
        storagePath,
        downloadURL,
        originalStoragePath,
        originalDownloadURL,
        referenceCount: posts.length,
        createdAt,
      },
      {merge: true}
    );

    posts.forEach((post, index) => {
      if (postSnapshots[index].exists) return;
      const {id, ...postDocumentData} = post;
      transaction.set(postRefs[index], postDocumentData);
      if (post.target === "group") {
        transaction.set(
          db.collection("diaries").doc(post.diaryId),
          {
            groupId: post.groupId,
            dateKey: post.dateKey,
            stickerLayout: FieldValue.arrayUnion(post.layout),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
        transaction.update(db.collection("groups").doc(post.groupId), {
          diaryCount: FieldValue.increment(1),
        });
      }
    });

    transaction.set(
      jobRef,
      {
        status: "completed",
        posts,
        completedAt: FieldValue.serverTimestamp(),
        notificationsSent: false,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  });

  return {jobId, userId, authorName, posts, groups, publishToBlog};
}

function finalizedJobFromCompletedData(
  jobId: string,
  data: DocumentData
): FinalizedStickerJob | null {
  const userId = stringValue(data.userId);
  const posts = (data.posts as StickerPostData[] | undefined) ?? [];
  if (!userId || posts.length === 0) return null;
  const groupIds = Array.from(new Set(posts.filter((post) => post.target === "group").map((post) => post.groupId)));
  const groups = groupIds.map((groupId) => ({
    id: groupId,
    name: "",
    memberIds: [],
  }));
  return {
    jobId,
    userId,
    authorName: stringValue(data.authorName) || "petanko user",
    posts,
    groups,
    publishToBlog: data.publishToBlog === true,
  };
}

async function fetchAndValidateGroups(groupIds: string[], userId: string): Promise<GroupData[]> {
  const groups: GroupData[] = [];
  for (const groupId of groupIds) {
    const snapshot = await db.collection("groups").doc(groupId).get();
    if (!snapshot.exists) {
      throw new Error("投稿先グループを確認できませんでした。");
    }
    const data = snapshot.data() ?? {};
    const memberIds = stringArrayValue(data.memberIds);
    if (!memberIds.includes(userId)) {
      throw new Error("参加していないグループには投稿できません。");
    }
    groups.push({
      id: groupId,
      name: stringValue(data.name) || "グループ",
      memberIds,
    });
  }
  return groups;
}

function buildStickerPosts(input: {
  jobId: string;
  userId: string;
  authorName: string;
  authorAvatar: string;
  assetId: string;
  downloadURL: string;
  originalDownloadURL: string;
  draft: Record<string, unknown>;
  publishToBlog: boolean;
  groups: GroupData[];
  createdAt: Timestamp;
}): StickerPostData[] {
  const dateKey = tokyoDateKey(input.createdAt.toDate());
  const baseZIndex = Math.floor(input.createdAt.toMillis() / 1000);
  const common = {
    assetId: input.assetId,
    dateKey,
    authorId: input.userId,
    authorName: input.authorName,
    authorAvatar: input.authorAvatar,
    comment: stringValue(input.draft.comment).trim(),
    shape: stringValue(input.draft.shape) || "circle",
    decoration: stringValue(input.draft.decoration) || "none",
    outlineColorHex: stringValue(input.draft.outlineColorHex) || "#FFFFFF",
    creationMode: stringValue(input.draft.creationMode) || "crop",
    effect: stringValue(input.draft.effect) || "original",
    stickerImageURL: input.downloadURL,
    originalStickerImageURL: input.originalDownloadURL,
    createdAt: input.createdAt,
  };
  const posts: StickerPostData[] = [];

  if (input.publishToBlog) {
    const id = `${input.jobId}_blog`;
    posts.push({
      id,
      target: "blog",
      groupId: "",
      diaryId: "",
      layout: makeLayout(id, baseZIndex),
      ...common,
    });
  }

  input.groups.forEach((group, index) => {
    const id = `${input.jobId}_${group.id}`;
    posts.push({
      id,
      target: "group",
      groupId: group.id,
      diaryId: `${group.id}_${dateKey}`,
      layout: makeLayout(id, baseZIndex + index),
      ...common,
    });
  });

  return posts;
}

function makeLayout(stickerId: string, zIndex: number): StickerLayoutData {
  return {
    stickerId,
    x: seededRange(`${stickerId}:x`, -80, 80),
    y: seededRange(`${stickerId}:y`, -140, 140),
    scale: seededRange(`${stickerId}:scale`, 0.86, 1.12),
    rotation: seededRange(`${stickerId}:rotation`, -13, 13),
    zIndex,
  };
}

async function sendStickerNotifications(job: FinalizedStickerJob): Promise<void> {
  const groupPosts = job.posts.filter((post) => post.target === "group");
  const primaryGroupPost = groupPosts[0];
  await sendToUser(job.userId, {
    notification: {
      title: "投稿が完了しました",
      body: "ステッカーを保存しました。",
    },
    data: {
      petankoDestination: "postComplete",
      primaryGroupId: primaryGroupPost?.groupId ?? "",
      dateKey: primaryGroupPost?.dateKey ?? "",
      stickerId: primaryGroupPost?.id ?? "",
      jobId: job.jobId,
      recipientUserId: job.userId,
    },
  });

  const groupsById = new Map(job.groups.map((group) => [group.id, group]));
  for (const post of groupPosts) {
    const cachedGroup = groupsById.get(post.groupId);
    const group = cachedGroup && cachedGroup.memberIds.length > 0 ?
      cachedGroup :
      await fetchGroupForNotification(post.groupId);
    const recipientIds = group.memberIds.filter((memberId) => memberId !== job.userId);
    await Promise.all(
      recipientIds.map((recipientId) =>
        sendToUser(recipientId, {
          notification: {
            title: `${group.name}に新しいステッカー`,
            body: `${job.authorName} がステッカーを貼りました。`,
          },
          data: {
            petankoDestination: "groupDiary",
            groupId: post.groupId,
            dateKey: post.dateKey,
            stickerId: post.id,
            jobId: job.jobId,
            recipientUserId: recipientId,
          },
        })
      )
    );
  }
}

async function fetchGroupForNotification(groupId: string): Promise<GroupData> {
  const snapshot = await db.collection("groups").doc(groupId).get();
  const data = snapshot.data() ?? {};
  return {
    id: groupId,
    name: stringValue(data.name) || "グループ",
    memberIds: stringArrayValue(data.memberIds),
  };
}

async function sendToUser(
  userId: string,
  message: Omit<MulticastMessage, "tokens">
): Promise<boolean> {
  const tokenSnapshot = await db.collection("users").doc(userId).collection("fcmTokens").get();
  const tokenDocs = tokenSnapshot.docs
    .map((document) => ({
      document,
      token: stringValue(document.data().token),
    }))
    .filter((entry) => entry.token);
  if (tokenDocs.length === 0) return false;
  const notificationCategory = message.data?.petankoNotificationCategory;

  const response = await getMessaging().sendEachForMulticast({
    ...message,
    tokens: tokenDocs.map((entry) => entry.token),
    apns: {
      payload: {
        aps: {
          sound: "default",
          ...(notificationCategory ? {category: notificationCategory} : {}),
        },
      },
    },
  });

  await Promise.all(
    response.responses.map(async (sendResponse, index) => {
      const code = sendResponse.error?.code;
      if (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token") {
        await tokenDocs[index].document.ref.delete();
      }
    })
  );
  return response.successCount > 0;
}

function tokyoDateKey(date: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = new Map(parts.map((part) => [part.type, part.value]));
  return `${values.get("year")}-${values.get("month")}-${values.get("day")}`;
}

function tokyoDateKeyOneMonthAgo(date: Date): string | null {
  const parts = tokyoDateParts(date);
  let year = parts.year;
  let month = parts.month - 1;
  if (month === 0) {
    year -= 1;
    month = 12;
  }
  const daysInPreviousMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (parts.day > daysInPreviousMonth) return null;
  return `${year.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}-${parts.day.toString().padStart(2, "0")}`;
}

function tokyoDateParts(date: Date): {year: number; month: number; day: number} {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);
  const values = new Map(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.get("year")),
    month: Number(values.get("month")),
    day: Number(values.get("day")),
  };
}

function diaryStickerCount(data: DocumentData): number {
  if (!Array.isArray(data.stickerLayout)) return 0;
  const stickerIds = data.stickerLayout
    .map((layout) => objectValue(layout))
    .map((layout) => stringValue(layout.stickerId))
    .filter(Boolean);
  return new Set(stickerIds).size;
}

function memoryReminderIntervalDays(previousIntervalDays: number): number {
  if (previousIntervalDays > 0 && previousIntervalDays <= 13) {
    return randomInteger(18, 30);
  }
  const roll = Math.random();
  if (roll < 0.12) return randomInteger(7, 13);
  if (roll < 0.56) return randomInteger(14, 21);
  return randomInteger(22, 30);
}

function randomInteger(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function seededRange(seed: string, min: number, max: number): number {
  const unit = hashToUnit(seed);
  return min + (max - min) * unit;
}

function hashToUnit(seed: string): number {
  let hash = 2166136261;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967295;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function requireString(value: unknown, message: string): string {
  const string = stringValue(value);
  if (!string) throw new Error(message);
  return string;
}

function stringArrayValue(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === "string") : [];
}

function numberValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function objectValue(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function userFacingErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "投稿処理に失敗しました。もう一度お試しください。";
}
