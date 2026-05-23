import SwiftUI

// MARK: - REAL DATA MODELS (نماذج البيانات الحقيقية للهيكل السحابي)

enum CloudPlatformType: String, CaseIterable, Identifiable {
    case googleDrive = "Google Drive"
    case dropbox = "Dropbox"
    case customWebDAV = "Custom WebDAV / Server"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .googleDrive: return "cloud.fill"
        case .dropbox: return "icloud.fill"
        case .customWebDAV: return "network"
        }
    }
}

struct CloudAccount: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: CloudPlatformType
    var usedStorage: Int64
    var totalStorage: Int64
    var serverURL: String? // مخصص لمنصات WebDAV المفتوحة أو السيرفرات الشخصية
}

// MARK: - CORE STORAGE VIEWMODEL (متحكم منطق التوجيه والمساحة الفعلي المحدث)

class StorageViewModel: ObservableObject {
    @Published var connectedAccounts: [CloudAccount] = []
    @Published var isConnecting = false
    @Published var connectionError: String? = nil
    
    // حساب المساحة التراكمية الكلية حقيقياً من المنصات المرتبطة
    var totalAggregateStorage: Int64 {
        connectedAccounts.reduce(0) { $0 + $1.totalStorage }
    }
    
    // حساب المساحة المستهلكة الفعلية من إجمالي المنصات
    var totalAggregateUsedStorage: Int64 {
        connectedAccounts.reduce(0) { $0 + $1.usedStorage }
    }
    
    // دالة إعادة ترتيب الأولويات (Priority Routing)
    func moveAccountPriority(from source: IndexSet, to destination: Int) {
        connectedAccounts.move(fromOffsets: source, toOffset: destination)
    }
    
    // دالة مخصصة لإضافة حساب تقليدي مؤقت (جوجل / دروب بوكس) لحين ربط الـ OAuth الخاص بهم
    func addNewAuthenticatedAccount(name: String, type: CloudPlatformType, totalSpaceGB: Int64, url: String? = nil) {
        let bytesInGB: Int64 = 1024 * 1024 * 1024
        let newAccount = CloudAccount(
            id: UUID(),
            name: name,
            type: type,
            usedStorage: 0,
            totalStorage: totalSpaceGB * bytesInGB,
            serverURL: url
        )
        connectedAccounts.append(newAccount)
    }
    
    // الدالة المحدثة: تتصل بالخادم حقيقياً وتتحقق من البيانات وتجلب مساحته التخزينية الفعلية
    @MainActor
    func linkRealWebDAVAccount(customName: String, urlString: String, user: String, pass: String) async {
        guard let url = URL(string: urlString) else {
            self.connectionError = "Invalid server URL scheme."
            return
        }
        
        self.isConnecting = true
        self.connectionError = nil
        
        // استدعاء ملف الـ WebDAVService الحقيقي الذي قمنا ببنائه
        let service = WebDAVService(serverURL: url, username: user, password: pass)
        
        do {
            // محاولة جلب كوتة المساحة الفعلية عبر الشبكة
            let quota = try await service.fetchStorageQuota()
            
            let newAccount = CloudAccount(
                id: UUID(),
                name: customName,
                type: .customWebDAV,
                usedStorage: quota.usedBytes,
                totalStorage: quota.totalBytes,
                serverURL: urlString
            )
            
            self.connectedAccounts.append(newAccount)
            self.isConnecting = false
        } catch {
            self.isConnecting = false
            self.connectionError = "Failed to connect: Check URL or Credentials."
        }
    }
}

// MARK: - CLOUD SETTINGS VIEW (واجهة الإعدادات والربط الحقيقي المحدثة)

struct CloudSettingsView: View {
    @EnvironmentObject var manager: StorageViewModel
    @State private var showAuthSheet = false
    
    // متغيرات نموذج إضافة حساب جديد
    @State private var selectedType: CloudPlatformType = .googleDrive
    @State private var accountCustomName = ""
    @State private var customWebDAVURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var allocatedSizeGB = "15" // الحجم الافتراضي للمنصات العادية
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // 1. شريط عداد الذاكرة التراكمية المشتركة الحقيقي
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Aggregate Cloud Storage").font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        let usedGB = Double(manager.totalAggregateUsedStorage) / (1024*1024*1024)
                        let totalGB = Double(manager.totalAggregateStorage) / (1024*1024*1024)
                        Text(String(format: "%.2f GB / %.2f GB", usedGB, totalGB))
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    // شريط العداد الرسومي المستمر (متوافق مع iOS 14)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                            
                            let percentage = manager.totalAggregateStorage > 0 ? CGFloat(manager.totalAggregateUsedStorage) / CGFloat(manager.totalAggregateStorage) : 0.0
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
                
                // نص توجيهي يوضح فكرة الـ Priority Hierarchy للمستخدم
                Text("Priority Routing Hierarchy: Upload traffic starts directed to Platform #1. If capacity fills up, overflow streams automatically transfer to node #2, and subsequent lines sequentially. Drag rows to adjust priority.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.leading)
                
                // 2. قائمة المنصات المرتبطة الفعلية والمرتبة من الرقم 1
                List {
                    Section(header: Text("Connected Nodes (Priority Order)")) {
                        if manager.connectedAccounts.isEmpty {
                            Text("No cloud accounts connected yet. Tap the button below to link storage.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(0..<manager.connectedAccounts.count, id: \.self) { index in
                                let account = manager.connectedAccounts[index]
                                HStack(spacing: 12) {
                                    // الرقم التسلسلي الفعلي القائم عليه منطق ضخ الملفات
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(index == 0 ? Color.blue : Color.gray)
                                        .clipShape(Circle())
                                    
                                    Image(systemName: account.type.iconName)
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.name)
                                            .font(.system(size: 15, weight: .bold))
                                        let nodeUsed = Double(account.usedStorage) / (1024*1024*1024)
                                        let nodeTotal = Double(account.totalStorage) / (1024*1024*1024)
                                        Text(String(format: "Capacity: %.1f GB of %.1f GB used", nodeUsed, nodeTotal))
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onMove(perform: manager.moveAccountPriority) // مستشعر الـ Drag & Drop الفوري
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // 3. زر فتح شاشة الربط السحابي الحقيقي
                Button(action: {
                    // تفريغ الأخطاء السابقة عند فتح النافذة مجدداً
                    manager.connectionError = nil
                    showAuthSheet = true
                }) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Connect Storage Provider")
                            .font(.system(size: 16, weight: .bold))
                    }
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
            .navigationBarItems(trailing: EditButton()) // زر التحرير المتوافق مع نظام iOS 14 لإعادة الترتيب
            .sheet(isPresented: $showAuthSheet) {
                // شاشة إعداد واستقبال بيانات الاتصال الحقيقية (الـ APIs)
                NavigationView {
                    Form {
                        Section(header: Text("Storage Node Configuration")) {
                            Picker("Provider Type", selection: $selectedType) {
                                ForEach(CloudPlatformType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            TextField("Account Label (e.g., Personal NAS)", text: $accountCustomName)
                            
                            // الحقول تظهر ديناميكياً بناءً على نوع المنصة المختارة
                            if selectedType == .customWebDAV {
                                TextField("Server URL (e.g., https://nas.local/dav)", text: $customWebDAVURL)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                TextField("Username", text: $username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                SecureField("Password", text: $password)
                            } else {
                                TextField("Allocated Space Size (in GB)", text: $allocatedSizeGB)
                                    .keyboardType(.numberPad)
                            }
                        }
                        
                        Section(header: Text("Authentication Status")) {
                            // مؤشر التحميل الحقيقي عند محاولة الاتصال بالـ API
                            if manager.isConnecting {
                                HStack {
                                    Spacer()
                                    ProgressView("Verifying Protocol Connection...")
                                    Spacer()
                                }
                            }
                            
                            // إظهار الخطأ الحقيقي القادم من السيرفر إن وجد
                            if let error = manager.connectionError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            
                            Button(action: {
                                if !accountCustomName.isEmpty {
                                    let size = Int64(allocatedSizeGB) ?? 15
                                    
                                    // تشغيل عملية الاتصال بالخلفية بشكل غير متزامن وآمن (Async Task)
                                    Task {
                                        if selectedType == .customWebDAV {
                                            await manager.linkRealWebDAVAccount(
                                                customName: accountCustomName,
                                                urlString: customWebDAVURL,
                                                user: username,
                                                pass: password
                                            )
                                        } else {
                                            manager.addNewAuthenticatedAccount(
                                                name: accountCustomName,
                                                type: selectedType,
                                                totalSpaceGB: size
                                            )
                                        }
                                        
                                        // إذا نجح الاتصال ولم يحدث خطأ، نغلق الـ Sheet ونفرغ الحقول
                                        if manager.connectionError == nil {
                                            accountCustomName = ""
                                            customWebDAVURL = ""
                                            username = ""
                                            password = ""
                                            showAuthSheet = false
                                        }
                                    }
                                }
                            }) {
                                Text(manager.isConnecting ? "Connecting..." : "Initialize Protocol Connection")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(accountCustomName.isEmpty || manager.isConnecting ? .gray : .blue)
                            }
                            .disabled(accountCustomName.isEmpty || manager.isConnecting)
                        }
                    }
                    .navigationTitle("Link Platform")
                    .navigationBarItems(leading: Button("Cancel") { showAuthSheet = false }.disabled(manager.isConnecting))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
