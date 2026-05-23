import Foundation

// نماذج بيانات حقيقية ومستخرجة من الـ API مباشرة
struct CloudStorageQuota {
    let usedBytes: Int64
    let totalBytes: Int64
    
    var availableBytes: Int64 {
        max(0, totalBytes - usedBytes)
    }
}

struct RemoteAssetMetadata {
    let id: String
    let remotePath: String
    let size: Int64
    let createdAt: Date
}

// البروتوكول الموحد الذي يحكم أي منصة تخزين سحابي يتم ربطها بالتطبيق
protocol CloudStorageService {
    var serverBaseURL: URL { get }
    
    // دالة جلب المساحة الحقيقية من السيرفر/المنصة
    func fetchStorageQuota() async throws -> CloudStorageQuota
    
    // دالة رفع الملفات الحقيقية (صورة أو فيديو) إلى السحاب
    func uploadFile(fileData: Data, filename: String, mimeType: String) async throws -> RemoteAssetMetadata
    
    // دالة التحميل
    func downloadFile(remotePath: String) async throws -> Data
}
