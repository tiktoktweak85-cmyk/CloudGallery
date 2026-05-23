import SwiftUI

struct AlbumGridView: View {
    @ObservedObject var galleryVM: GalleryViewModel
    @State private var showCreateAlbumAlert = false
    @State private var newAlbumName = ""
    
    // تحديد الهيكل الشبكي: عمودين متساويين ومرنين بنفس أبعاد تطبيق Photos الأصلي
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // زر إنشاء ألبوم جديد (يظهر في الأعلى كخيار سريع ونظيف)
                HStack {
                    Text("My Albums")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button(action: { showCreateAlbumAlert = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if galleryVM.albums.isEmpty {
                    // واجهة فارغة احترافية عند عدم وجود ألبومات
                    VStack(spacing: 12) {
                        Spacer(minLength: 100)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(Color(.systemGray4))
                        Text("No Albums Yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Tap the plus icon above to create your first cloud-routed album.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // الشبكة الحقيقية للألبومات (مربعات جنباً إلى جنب)
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(galleryVM.albums) { album in
                            // عند الضغط على الألبوم يفتح شبكة الصور الداخلية الخاصة به
                            NavigationLink(destination: MediaGridView(album: album, galleryVM: galleryVM)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    
                                    // 1. حاوية غلاف الألبوم المربعة تماماً
                                    GeometryReader { geo in
                                        ZStack(alignment: .bottomTrailing) {
                                            if let _ = album.coverAsset {
                                                // هنا سيتم عرض غلاف الصورة الحقيقي بعد اكتمال محرك التحميل
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(.systemGray5))
                                            } else {
                                                // غلاف افتراضي أنيق للألبوم الفارغ
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(.systemGray6))
                                                Image(systemName: "photo")
                                                    .font(.system(size: 35))
                                                    .foregroundColor(Color(.systemGray3))
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }
                                            
                                            // مؤشر المزامنة السحابية الخاص بتطبيقك في الزاوية
                                            Image(systemName: album.isFullySynced ? "checkmark.cloud.fill" : "arrow.clockwise.cloud")
                                                .font(.system(size: 14))
                                                .foregroundColor(album.isFullySynced ? .blue : .orange)
                                                .padding(6)
                                                .background(Color(.systemBackground).opacity(0.8))
                                                .clipShape(Circle())
                                                .padding(8)
                                        }
                                        .frame(width: geo.size.width, height: geo.size.width) // ضمان المربع الكامل 1:1
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    
                                    // 2. تفاصيل الألبوم السفلى (نفس خطوط وتنسيق آبل تماماً)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(album.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text("\(album.itemCount)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 2)
                                }
                            }
                            .buttonStyle(PlainButtonStyle()) // إلغاء تأثير الضغط الأزرق التلقائي للحفاظ على الهوية
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Gallery")
        // نافذة الإدخال لإنشاء ألبوم حقيقي
        .sheet(isPresented: $showCreateAlbumAlert) {
            NavigationView {
                Form {
                    Section(header: Text("New Cloud Album Description")) {
                        TextField("Album Name", text: $newAlbumName)
                    }
                }
                .navigationTitle("New Album")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        newAlbumName = ""
                        showCreateAlbumAlert = false
                    },
                    trailing: Button("Create") {
                        if !newAlbumName.isEmpty {
                            galleryVM.createNewCloudAlbum(named: newAlbumName)
                            newAlbumName = ""
                            showCreateAlbumAlert = false
                        }
                    }
                    .disabled(newAlbumName.isEmpty)
                )
            }
        }
    }
}
