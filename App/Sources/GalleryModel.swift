import Foundation

// دعم Codable لضمان الحفظ المستمر والآمن في ذاكرة الهاتف
enum AssetMediaType: String, Codable {
    case image
    case video
}

struct CloudAsset: Identifiable, Equatable, Codable {
    let id: String
    let remoteURL: String
    let mediaType: AssetMediaType
    let fileSize: Int64
    let creationDate: Date
    let duration: TimeInterval?
}

struct CloudAlbum: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    var assets: [CloudAsset]
    var isFullySynced: Bool
    var isSystemAlbum: Bool // لتمييز ألبومات النظام (Recent / Favorite) لمنع حذفها وتغيير خصائصها
    
    var itemCount: Int {
        assets.count
    }
    
    var coverAsset: CloudAsset? {
        assets.last
    }
}
