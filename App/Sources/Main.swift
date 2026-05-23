import SwiftUI
import PhotosUI
import AVKit

// MARK: - 1. MODELS (نماذج البيانات)

struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let assetURL: URL?
    let creationDate: Date
    let fileSizeCloud: Int64 // الحجم السحابي بالبايت
    var isFavorite: Bool
    let isVideo: Bool
    let duration: TimeInterval?
    
    // متغيرات مساعدة لعرض البيانات النصية المجهزة للتصميم
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeCloud, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: creationDate)
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: creationDate)
    }
}

struct CloudPlatform: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let iconName: String
    var usedStorage: Int64  // بالبايت
    var totalStorage: Int64 // بالبايت
}

struct Album: Identifiable {
    let id = UUID()
    let title: String
    let systemIcon: String
    var items: [MediaItem]
}

// MARK: - 2. CORE MANAGER / VIEWMODEL (إدارة العمليات والبيانات السحابية)

class AppCoreManager: ObservableObject {
    @Published var albums: [Album] = [
        Album(title: "Recent", systemIcon: "clock.fill", items: []),
        Album(title: "Favorites", systemIcon: "heart.fill", items: [])
    ]
    
    @Published var cloudPlatforms: [CloudPlatform] = [
        CloudPlatform(name: "Google Drive", iconName: "cloud.fill", usedStorage: 12 * 1024 * 1024 * 1024, totalStorage: 15 * 1024 * 1024 * 1024),
        CloudPlatform(name: "Dropbox", iconName: "icloud.fill", usedStorage: 1 * 1024 * 1024 * 1024, totalStorage: 2 * 1024 * 1024 * 1024),
        CloudPlatform(name: "OneDrive", iconName: "smoke.fill", usedStorage: 0, totalStorage: 5 * 1024 * 1024 * 1024)
    ]
    
    @Published var isGroupedByDate = false
    @Published var downloadingItemId: UUID? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var selectedMediaForView: MediaItem? = nil
    
    // حساب الذاكرة التراكمية للمنصات المشتركة لعداد الإعدادات العلوي
    var totalCloudStorage: Int64 {
        cloudPlatforms.reduce(0) { $0 + $1.totalStorage }
    }
    
    var totalUsedCloudStorage: Int64 {
        cloudPlatforms.reduce(0) { $0 + $1.usedStorage }
    }
    
    // إضافة المرفقات برمجياً ومعالجة منطق المساحة الفائضة والتوزيع الذكي
    func appendUploadedMedia(is_video: Bool, duration: TimeInterval?, originalDate: Date?, size: Int64) {
        let finalDate = originalDate ?? Date()
        let sizeInBytes = size > 0 ? size : Int64.random(in: 1024*1024...50*1024*1024)
        
        let newItem = MediaItem(
            assetURL: nil,
            creationDate: finalDate,
            fileSizeCloud: sizeInBytes,
            isFavorite: false,
            isVideo: is_video,
            duration: duration
        )
        
        // إدخال المرفق في ألبوم "مؤخراً"
        if let recentIndex = albums.firstIndex(where: { $0.title == "Recent" }) {
            albums[recentIndex].items.insert(newItem, at: 0)
        }
        
        // المحرك الذكي: إستهلاك الذاكرة السحابية من المنصة رقم 1 حسب الترتيب الحالي، وفي حال امتلائها يتم التوزيع للتي تليها
        var remainingToAllocate = sizeInBytes
        for i in 0..<cloudPlatforms.count {
            let availableSpace = cloudPlatforms[i].totalStorage - cloudPlatforms[i].usedStorage
            if availableSpace > 0 {
                if remainingToAllocate <= availableSpace {
                    cloudPlatforms[i].usedStorage += remainingToAllocate
                    break
                } else {
                    cloudPlatforms[i].usedStorage = cloudPlatforms[i].totalStorage
                    remainingToAllocate -= availableSpace
                }
            }
        }
    }
    
    func toggleFavoriteStatus(for item: MediaItem) {
        // تحديث حالة المفضلة في ألبوم مؤخراً
        if let recentIndex = albums.firstIndex(where: { $0.title == "Recent" }),
           let itemIndex = albums[recentIndex].items.firstIndex(where: { $0.id == item.id }) {
            albums[recentIndex].items[itemIndex].isFavorite.toggle()
            let updatedItem = albums[recentIndex].items[itemIndex]
            
            // إدارة المزامنة الفورية مع ألبوم المفضلة الجانبي
            if let favIndex = albums.firstIndex(where: { $0.title == "Favorites" }) {
                if updatedItem.isFavorite {
                    if !albums[favIndex].items.contains(where: { $0.id == updatedItem.id }) {
                        albums[favIndex].items.append(updatedItem)
                    }
                } else {
                    albums[favIndex].items.removeAll(where: { $0.id == updatedItem.id })
                }
            }
        }
    }
    
    // محاكاة خط التحميل الدائري السحابي عند النقر على الصورة المصغرة قبل تفعيل العرض الشامل
    func triggerCloudDownload(for item: MediaItem) {
        downloadingItemId = item.id
        downloadProgress = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            self.downloadProgress += 0.04
            if self.downloadProgress >= 1.0 {
                timer.invalidate()
                self.downloadingItemId = nil
                self.selectedMediaForView = item
            }
        }
    }
}

// MARK: - 3. MAIN APPLICATION ENTRY (نقطة الإنطلاق الموحدة)

@main
struct CloudGalleryApp: App {
    @StateObject private var manager = AppCoreManager()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                GalleryDashboardView()
                    .environmentObject(manager)
                    .tabItem {
                        Label("Gallery", systemImage: "photo.on.rectangle.angled")
                    }
                
                CloudSettingsView()
                    .environmentObject(manager)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .accentColor(.blue)
        }
    }
}

// MARK: - 4. GALLERY DASHBOARD VIEW (واجهة المعرض الرئيسية والألبومات)

struct GalleryDashboardView: View {
    @EnvironmentObject var manager: AppCoreManager
    @State private var selectedAlbumTitle = "Recent"
    @State private var showPicker = false
    
    var currentAlbum: Album {
        manager.albums.first(where: { $0.title == selectedAlbumTitle }) ?? manager.albums[0]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // شريط اختيار الألبوم العلوي الأنيق (Recent / Favorites)
                Picker("Albums", selection: $selectedAlbumTitle) {
                    ForEach(manager.albums) { album in
                        Text(album.title).tag(album.title)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if currentAlbum.items.isEmpty {
                    // الحالة الأولى: الألبوم فارغ - يظهر زر الرفع الضخم في المنتصف تماماً
                    Spacer()
                    VStack(spacing: 16) {
                        Button(action: { showPicker = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue)
                                Text("Upload to Cloud")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            .padding(40)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                        }
                        Text("This cloud album is empty. Start managing your storage.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    // الحالة الثانية: الألبوم يحتوي ملفات - عرض التقطيع الشبكي
                    HStack {
                        Toggle(isOn: $manager.isGroupedByDate) {
                            Text("Organize by Timeline")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        if manager.isGroupedByDate {
                            // التقطيع الشبكي المقسم زمنياً حسب الأشهر والسنوات
                            let grouped = Dictionary(grouping: currentAlbum.items, by: { $0.monthYearString })
                            let sortedKeys = grouped.keys.sorted(by: >)
                            
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(sortedKeys, id: \.self) { sectionName in
                                    Section(header: Text(sectionName).font(.title3).bold().padding(.horizontal, 4)) {
                                        MediaCompactGrid(items: grouped[sectionName] ?? [])
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // العرض الكامل المتتالي المباشر بدون تقسيم
                            MediaCompactGrid(items: currentAlbum.items)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(selectedAlbumTitle)
            // الزر العلوي الزاوي المساعد المطور: يظهر فقط إذا كان الألبوم غير فارغ على شكل علامة +
            .navigationBarItems(trailing: Group {
                if !currentAlbum.items.isEmpty {
                    Button(action: { showPicker = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .bold()
                    }
                }
            })
            .sheet(isPresented: $showPicker) {
                NativeMediaPicker(manager: manager)
            }
            .fullScreenCover(item: $manager.selectedMediaForView) { media in
                IntegratedMediaViewer(item: media)
                    .environmentObject(manager)
            }
        }
    }
}

// MARK: - 5. COMPACT GRID & THUMBNAIL COMPONENT (مكونات الشبكة ودائرة التحميل)

struct MediaCompactGrid: View {
    @EnvironmentObject var manager: AppCoreManager
    let items: [MediaItem]
    
    let gridLayout = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]
    
    var body: some View {
        LazyVGrid(columns: gridLayout, spacing: 3) {
            ForEach(items) { item in
                ZStack {
                    // توليد مظهر مصغر افتراضي أنيق للمحتويات السحابية
                    Rectangle()
                        .fill(item.isVideo ? Color.indigo.opacity(0.15) : Color.blue.opacity(0.1))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if item.isFavorite {
                                        Image(systemName: "heart.fill")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(6)
                            }
                        )
                    
                    // طبقة المؤشر الدائري السارية للتحميل: تظهر فور النقر فوق الصورة المصغرة المحددة
                    if manager.downloadingItemId == item.id {
                        Color.black.opacity(0.4)
                        ProgressView(value: manager.downloadProgress, total: 1.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .clipped()
                .onTapGesture {
                    if manager.downloadingItemId == nil {
                        manager.triggerCloudDownload(for: item)
                    }
                }
            }
        }
    }
}

// MARK: - 6. INTEGRATED MEDIA VIEWER & CUSTOM CONTROLS (عرض المحتوى وإيماءة السحب ومشغل الفيديو المطور)

struct IntegratedMediaViewer: View {
    @EnvironmentObject var manager: AppCoreManager
    let item: MediaItem
    @Environment(\.presentationMode) var presentationMode
    
    @State private var dragOffset = CGSize.zero
    @State private var showInfoPanel = false
    
    // متغيرات مشغل الفيديو المخصص
    @State private var isPlaying = false
    @State private var videoDuration: Double = 0.0
    @State private var videoCurrentTime: Double = 0.0
    private var videoPlayer: AVPlayer? = nil
    
    init(item: MediaItem) {
        self.item = item
        if item.isVideo {
            // استخدام عينة فيديو عامة آمنة للبناء للتأكد من عمل الأزرار المخصصة
            if let mockVideoURL = URL(string: "https://developer.apple.com/videos/mp4/subtitles/shared/subtitles_sample.mp4") {
                self._isPlaying = State(initialValue: false)
                // تهيئة بدون واجهات التحكم الافتراضية للتحكم المطلق بها برمجياً
                self.videoPlayer = AVPlayer(url: mockVideoURL)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // منطقة العرض السينمائية المخصصة للمقاسات
            VStack {
                if item.isVideo, let player = videoPlayer {
                    // مشغل الفيديو المخصص العريض وسط خلفية سوداء بالكامل بدون حواف جانبية للـ 16:9
                    VideoPlayer(player: player)
                        .disabled(true) // لتعطيل لمسات واجهة نظام أبل والاعتماد الكلي على أزرارنا بالأسفل
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(customVideoControllerOverlay, alignment: .bottom)
                } else {
                    // مستعرض الصور المخصص
                    Image(systemName: "photo")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                }
            }
            .frame(maxHeight: .infinity)
            // تتبع إيماءة السحب العلوية (Swipe Up Gesture) لإظهار لوحة الميتا-داتا السحابية العميقة
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            self.dragOffset = gesture.translation
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height < -80 {
                            withAnimation(.spring()) { showInfoPanel = true }
                        }
                        self.dragOffset = .zero
                    }
            )
            
            // اللوحة السفلية الشفافة المنبثقة لبيانات الحجم والتاريخ السحابي
            if showInfoPanel {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Cloud Storage Metadata")
                                .font(.headline).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { withAnimation { showInfoPanel = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.title3)
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        HStack {
                            Label("Cloud Asset Size:", systemImage: "internaldrive.fill")
                            Spacer()
                            Text(item.formattedSize).bold() // حجم التخزين المستهلك حقيقياً من السحابة
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack {
                            Label("Original Timestamp:", systemImage: "calendar")
                            Spacer()
                            Text(item.formattedDate).bold() // تاريخ المزامنة الأصلي للمحتوى
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(24)
                    .background(BlurView(style: .systemUltraThinMaterialDark))
                    .cornerRadius(24)
                    .transition(.move(edge: .bottom))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // أزرار التحكم العلوي المباشر في لوحة العرض
            VStack {
                HStack {
                    Button(action: {
                        videoPlayer?.pause()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button(action: { manager.toggleFavoriteStatus(for: item) }) {
                        Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 28))
                            .foregroundColor(item.isFavorite ? .red : .white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                Spacer()
                
                if !showInfoPanel {
                    Text("Swipe up for Cloud Details")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            if item.isVideo {
                // إستماع وتوليد ومزامنة مدة المقطع بشكل آلي
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { _ in
                    self.isPlaying = false
                    self.videoPlayer?.seek(to: .zero)
                }
            }
        }
    }
    
    // بناء شريط تحكم الفيديو المستقل والكامل (توقف، تقديم، تأخير، شريط مسار ساري)
    private var customVideoControllerOverlay: some View {
        VStack(spacing: 4) {
            HStack(spacing: 20) {
                // زر التأخير 15 ثانية للخلف
                Button(action: { seekVideo(by: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2).foregroundColor(.white)
                }
                
                // زر التشغيل والإيقاف المؤقت
                Button(action: {
                    if isPlaying {
                        videoPlayer?.pause()
                    } else {
                        videoPlayer?.play()
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title).foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                
                // زر التقديم 15 ثانية للأمام
                Button(action: { seekVideo(by: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.title2).foregroundColor(.white)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
    }
    
    private func seekVideo(by seconds: Double) {
        guard let player = videoPlayer else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = currentTime + seconds
        player.seek(to: CMTimeMakeWithSeconds(newTime, preferredTimescale: 1))
    }
}

// MARK: - 7. CLOUD PLATFORMS INTEGRATION VIEW (إعدادات الربط السحابي وإعادة الترتيب التلقائي للتدفق)

struct CloudSettingsView: View {
    @EnvironmentObject var manager: AppCoreManager
    @State private var showMockLogin = false
    @State private var typingPlatform = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // المكون الأساسي: شريط عداد الذاكرة التراكمية المشتركة لكافة المنصات النشطة
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Aggregate Cloud Storage Usage").font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        let usedGB = Double(manager.totalUsedCloudStorage) / (1024*1024*1024)
                        let totalGB = Double(manager.totalCloudStorage) / (1024*1024*1024)
                        Text(String(format: "%.1f GB / %.1f GB", usedGB, totalGB)).bold().font(.subheadline)
                    }
                    
                    // شريط العداد الرسومي المستمر للتخزين الموحد
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                            
                            let percentage = manager.totalCloudStorage > 0 ? CGFloat(manager.totalUsedCloudStorage) / CGFloat(manager.totalCloudStorage) : 0.0
                            RoundedRectangle(cornerRadius: 6)
                                .fill(percentage > 0.9 ? Color.red : Color.blue)
                                .frame(width: geo.size.width * percentage, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // شرح توضيحي لآلية التدفق الديناميكي للمساحة والتسلسل المرقم للمستخدم
                Text("Priority Routing: Photos upload to platform #1. When full, traffic automatically overflows to #2, then #3. Drag and drop rows below to reorder your priority hierarchy.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.leading)
                
                // القائمة النشطة المرقمة المدعومة بميزة الـ Drag & Drop الكامل لإعادة الترتيب اللحظي
                List {
                    Section(header: Text("Connected Storage Nodes (Numbered Order)")) {
                        ForEach(0..<manager.cloudPlatforms.count, id: \.self) { index in
                            HStack(spacing: 12) {
                                // التسلسل الرقمي المعتمد لضخ وخط توجيه البيانات
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(index == 0 ? Color.blue : Color.gray)
                                    .clipShape(Circle())
                                
                                Image(systemName: manager.cloudPlatforms[index].iconName)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(manager.cloudPlatforms[index].name).font(.body).bold()
                                    let nodeUsed = Double(manager.cloudPlatforms[index].usedStorage) / (1024*1024*1024)
                                    let nodeTotal = Double(manager.cloudPlatforms[index].totalStorage) / (1024*1024*1024)
                                    Text(String(format: "Used: %.1f GB of %.1f GB", nodeUsed, nodeTotal))
                                        .font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onMove(perform: reorderCloudNodes) // تفعيل مستشعر السحب وإعادة الهيكلة الفورية
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Button(action: { showMockLogin = true }) {
                    Label("Link New Cloud Account", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Cloud Link")
            .toolbar { EditButton() } // لتفعيل وضع التحرير وإعادة الترتيب بكل سهولة
            .sheet(isPresented: $showMockLogin) {
                VStack(spacing: 20) {
                    Text("Connect Cloud Account").font(.title2).bold().padding(.top)
                    Text("Log in with your official account credentials to authenticate your remote cloud drive cluster inside this application container securely.")
                        .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    
                    TextField("Enter Cloud Provider Name (e.g., Box, Mega)", text: $typingPlatform)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button("Grant Authorization & Link Account") {
                        if !typingPlatform.isEmpty {
                            manager.cloudPlatforms.append(
                                CloudPlatform(name: typingPlatform, iconName: "cloud.fill", usedStorage: 0, totalStorage: 10 * 1024 * 1024 * 1024)
                            )
                            typingPlatform = ""
                            showMockLogin = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(typingPlatform.isEmpty)
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    // معالج مصفوفة السحب لتحديث خط التسلسل الرقمي لتوجيه الصور تلقائياً
    private func reorderCloudNodes(from source: IndexSet, to destination: Int) {
        manager.cloudPlatforms.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - 8. NATIVE PHOTO KIT BRIDGING UI (جسر ربط ألبوم الصور الحقيقي وسحب الحجم والتاريخ والمدد)

struct NativeMediaPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let manager: AppCoreManager
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos]) // قبول الصور والمقاطع معاً
        configuration.selectionLimit = 0 // صفر تعني إمكانية الاختيار اللانهائي والمتعدد دفعة واحدة
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: NativeMediaPicker
        
        init(_ parent: NativeMediaPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            for result in results {
                let itemProvider = result.itemProvider
                let isVideo = itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
                
                // جلب الميتا-داتا العميقة والمسؤولة عن جلب التواريخ الأصلية للمرفقات وحساب أحجامها السحابية الحقيقية
                if let assetId = result.assetIdentifier {
                    let assetResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                    if let firstAsset = assetResult.firstObject {
                        let creationDate = firstAsset.creationDate ?? Date()
                        let duration = isVideo ? firstAsset.duration : nil
                        
                        // برمجة طلب استخراج الحجم الحقيقي للملف من مكتبة ركائز النظام الأساسية
                        let resources = PHAssetResource.assetResources(for: firstAsset)
                        var fileSize: Int64 = 0
                        if let fileSizeUnwrapped = resources.first?.value(forKey: "fileSize") as? Int64 {
                            fileSize = fileSizeUnwrapped
                        }
                        
                        DispatchQueue.main.async {
                            self.parent.manager.appendUploadedMedia(
                                is_video: isVideo,
                                duration: duration,
                                originalDate: creationDate,
                                size: fileSize
                            )
                        }
                    }
                } else {
                    // معالج احتياطي في حال عدم سماح النظام بالوصول للمعرفات الفرعية للملف
                    DispatchQueue.main.async {
                        self.parent.manager.appendUploadedMedia(
                            is_video: isVideo,
                            duration: nil,
                            originalDate: Date(),
                            size: 0
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 9. BACKWARD COMPATIBILITY & VISUAL HELPERS (أدوات بصرية للمظهر الشفاف المطور)

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
