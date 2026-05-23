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

// MARK: - CORE STORAGE VIEWMODEL (متحكم منطق التوجيه والمساحة الفعلي)

class StorageViewModel: ObservableObject {
    @Published var connectedAccounts: [CloudAccount] = []
    @Published var isConnecting = false
    @Published var connectionError: String? = nil
    
    var totalAggregateStorage: Int64 {
        connectedAccounts.reduce(0) { $0 + $1.totalStorage }
    }
    
    var totalAggregateUsedStorage: Int64 {
        connectedAccounts.reduce(0) { $0 + $1.usedStorage }
    }
    
    func moveAccountPriority(from source: IndexSet, to destination: Int) {
        connectedAccounts.move(fromOffsets: source, toOffset: destination)
    }
    
    // الدالة المحدثة: تتصل بالخادم وتتحقق من صحة البيانات وتجلب مساحته التخزينية الحقيقية فوراً
    @MainActor
    func linkRealWebDAVAccount(customName: String, urlString: String, user: String, pass: String) async {
        guard let url = URL(string: urlString) else {
            self.connectionError = "Invalid server URL scheme."
            return
        }
        
        self.isConnecting = true
        self.connectionError = nil
        
        // إنشاء الخدمة وربطها بالخادم الحقيقي للمستخدم
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
// MARK: - CLOUD SETTINGS VIEW (واجهة الإعدادات والربط الحقيقي)

struct CloudSettingsView: View {
    @EnvironmentObject var manager: StorageViewModel
    @State private var showAuthSheet = false
    
    // متغيرات نموذج إضافة حساب جديد
    @State private var selectedType: CloudPlatformType = .googleDrive
    @State private var accountCustomName = ""
    @State private var customWebDAVURL = ""
    @State private var allocatedSizeGB = "15" // الحجم الافتراضي كمثال للتهيئة
    
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
                                .foregroundColor(.gray)
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
                Button(action: { showAuthSheet = true }) {
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
                            
                            TextField("Account Label (e.g., Personal Drive)", text: $accountCustomName)
                            
                            if selectedType == .customWebDAV {
                                TextField("Server URL (e.g., https://nas.local/dav)", text: $customWebDAVURL)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            TextField("Allocated Space Size (in GB)", text: $allocatedSizeGB)
                                .keyboardType(.numberPad)
                        }
                        
                        Section(header: Text("Authentication")) {
                            Text("Clicking below will initiate the secure connection process. Custom platforms will bind immediately, while corporate systems will forward to authentication protocols.")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                if !accountCustomName.isEmpty {
                                    let size = Int64(allocatedSizeGB) ?? 15
                                    let urlPath = selectedType == .customWebDAV ? customWebDAVURL : nil
                                    
                                    // هنا يتم استدعاء دالة الحفظ، وفي الخطوات القادمة سنربطها بدوال الـ APIs الحقيقية
                                    manager.addNewAuthenticatedAccount(
                                        name: accountCustomName,
                                        type: selectedType,
                                        totalSpaceGB: size,
                                        url: urlPath
                                    )
                                    
                                    // إعادة تهيئة الحقول وإغلاق النافذة
                                    accountCustomName = ""
                                    customWebDAVURL = ""
                                    showAuthSheet = false
                                }
                            }) {
                                Text("Initialize Protocol Connection")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            .disabled(accountCustomName.isEmpty)
                        }
                    }
                    .navigationTitle("Link Platform")
                    .navigationBarItems(leading: Button("Cancel") { showAuthSheet = false })
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
