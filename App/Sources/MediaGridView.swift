import SwiftUI

struct MediaGridView: View {
    let album: CloudAlbum
    @ObservedObject var galleryVM: GalleryViewModel
    @EnvironmentObject var storageManager: StorageViewModel // استقبال السيرفرات المرتبطة لتوجيه تدفق الصور إليها
    
    private let mediaColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            VStack {
                // إظهار مؤشر رفع حقيقي علوي عند ضخ الملفات للسحاب
                if galleryVM.isUploading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 6)
                        Text("Streaming and routing assets via priority line...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBlue).opacity(0.08))
                }
                
                // إظهار رسائل الخطأ الحقيقية إن وجد خلل في مساحات الخوادم
                if let error = galleryVM.uploadError {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                if getAlbumAssets().isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 120)
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Photos or Videos")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Tap the upload icon in the toolbar to route files to this cloud node directory.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: mediaColumns, spacing: 2) {
                        ForEach(getAlbumAssets()) { asset in
                            GeometryReader { geo in
                                ZStack(alignment: .bottomTrailing) {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                    
                                    if asset.mediaType == .video {
                                        HStack(spacing: 3) {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 9))
                                            Text("0:05")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.white)
                                        .padding(4)
                                    }
                                }
                                .frame(width: geo.size.width, height: geo.size.width)
                            }
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        // إضافة زر الرفع الحقيقي في شريط القائمة العلوي متوافق مع iOS 14
        .navigationBarItems(trailing: Button(action: {
            simulatePhotoUploadSelection()
        }) {
            Image(systemName: "square.and.arrow.up") // أيقونة الرفع الرسمية لنظام آبل
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
        }.disabled(galleryVM.isUploading))
    }
    
    // دالة مساعدة لجلب أحدث بيانات الألبوم بشكل مستمر من الـ ViewModel لمنع الجمود في الواجهة
    private func getAlbumAssets() -> [CloudAsset] {
        return galleryVM.albums.first(where: { $0.id == album.id })?.assets ?? []
    }
    
    // محاكاة اختيار صورة حقيقية من الاستوديو وضخها فوراً في محرك التوجيه بالأولويات
    private func simulatePhotoUploadSelection() {
        // توليد بيانات صورة وهمية بحجم 5 ميجابايت للتجربة البرمجية للشبكة والـ API
        let dummyImageData = Data(repeating: 0, count: 5 * 1024 * 1024)
        let uniqueFilename = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
        
        Task {
            await galleryVM.uploadAndRouteAsset(
                fileData: dummyImageData,
                filename: uniqueFilename,
                mimeType: "image/jpeg",
                targetAlbumId: album.id,
                storageManager: storageManager
            )
        }
    }
}
