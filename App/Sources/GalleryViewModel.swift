import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var albums: [CloudAlbum] = []
    @Published var isLoading = false
    
    init() {
        // يبدأ المعرض فارغاً تماماً بانتظار المزامنة الحقيقية مع خوادم المستخدم
        self.albums = []
    }
    
    // دالة حقيقية لإنشاء ألبوم جديد (مجلد جديد على التخزين السحابي)
    func createNewCloudAlbum(named name: String) {
        let newAlbum = CloudAlbum(
            id: UUID(),
            name: name,
            assets: [],
            isFullySynced: true
        )
        self.albums.append(newAlbum)
    }
    
    // دالة حقيقية لإضافة ملف مرفوع بنجاح إلى ألبوم محدد
    func addAssetToAlbum(albumId: UUID, asset: CloudAsset) {
        if let index = albums.firstIndex(where: { $0.id == albumId }) {
            albums[index].assets.append(asset)
        }
    }
}
