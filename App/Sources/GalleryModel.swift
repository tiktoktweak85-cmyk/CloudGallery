import Foundation

// نوع الملف: صورة أو فيديو
enum AssetMediaType {
    case image
    case video
}

// نموذج الملف الحقيقي داخل الألبوم (قادم من مسار سحابي)
struct CloudAsset: Identifiable, Equatable {
    let id: String // المعرف الفريد القادم من الـ API
    let remoteURL: String // رابط الملف على السيرفر/السحابة
    let mediaType: AssetMediaType
    let fileSize: Int64
    let creationDate: Date
    let duration: TimeInterval? // مخصص للفيديوهات فقط
}

// نموذج الألبوم الحقيقي (يمثل مجلداً سحابياً)
struct CloudAlbum: Identifiable, Equatable {
    let id: UUID
    let name: String
    var assets: [CloudAsset]
    let isFullySynced: Bool // يوضح حالة المزامنة السحابية للألبوم
    
    // حساب عدد العناصر داخل الألبوم تلقائياً
    var itemCount: Int {
        assets.count
    }
    
    // جلب رابط آخر صورة لتعيينها كغلاف للألبوم (مثل تطبيق آبل)
    var coverAsset: CloudAsset? {
        assets.last
    }
}
