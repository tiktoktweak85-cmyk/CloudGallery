import Foundation

class WebDAVService: CloudStorageService {
    let serverBaseURL: URL
    private let credentialString: String // نص التشفير الخاص بـ Base64 لبيانات الدخول
    
    // تفعيل الاتصال ببيانات المستخدم الحقيقية
    init(serverURL: URL, username: String, password: String) {
        self.serverBaseURL = serverURL
        let loginData = "\(username):\(password)".data(using: .utf8)!
        self.credentialString = loginData.base64EncodedString()
    }
    
    // محرك متوافق بنسبة 100% مع iOS 14 لدمج الـ URLSession القديم مع نظام Async/Await الحديث
    private func executeSecureRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                continuation.resume(returning: (data, httpResponse))
            }.resume()
        }
    }
    
    // MARK: - 1. FETCH REAL STORAGE QUOTA (جلب مساحة التخزين الحقيقية عبر PROPFIND)
    func fetchStorageQuota() async throws -> CloudStorageQuota {
        var request = URLRequest(url: serverBaseURL)
        request.httpMethod = "PROPFIND" // الأمر القياسي لـ WebDAV لجلب الخصائص
        request.setValue("Basic \(credentialString)", forHTTPHeaderField: "Authorization")
        request.setValue("0", forHTTPHeaderField: "Depth") // جلب بيانات المجلد الرئيسي فقط
        request.setValue("application/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        
        // جسم طلب الـ XML الحقيقي لمطالبة السيرفر بالمساحة المستهلكة والمتاحة
        let xmlBody = """
        <?xml version="1.0" encoding="utf-8" ?>
        <d:propfind xmlns:d="DAV:">
          <d:prop>
            <d:quota-available-bytes/>
            <d:quota-used-bytes/>
          </d:prop>
        </d:propfind>
        """
        request.httpBody = xmlBody.data(using: .utf8)
        
        let (data, response) = try await executeSecureRequest(request)
        
        guard response.statusCode == 207 else { // 207 Multi-Status هو الرد الناجح لـ WebDAV
            throw URLError(.badServerResponse)
        }
        
        // استخراج البيانات حقيقياً عبر معالجة النص المسترجع من الـ XML لضمان خفة وسرعة الأداء على iOS 14
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        let availableBytes = parseXMLTag(xmlString, tagName: "quota-available-bytes") ?? 0
        let usedBytes = parseXMLTag(xmlString, tagName: "quota-used-bytes") ?? 0
        
        // حساب السعة الكلية الفعلية من السيرفر
        let totalBytes = usedBytes + availableBytes
        
        return CloudStorageQuota(usedBytes: usedBytes, totalBytes: totalBytes)
    }
    
    // MARK: - 2. UPLOAD FILE TO REAL CLOUD (رفع حقيقي للملفات عبر PUT)
    func uploadFile(fileData: Data, filename: String, mimeType: String) async throws -> RemoteAssetMetadata {
        // بناء الرابط الحقيقي للملف على السيرفر السحابي
        let fileURL = serverBaseURL.appendingPathComponent(filename)
        var request = URLRequest(url: fileURL)
        request.httpMethod = "PUT" // الأمر القياسي لرفع الملفات
        request.setValue("Basic \(credentialString)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = fileData
        
        let (_, response) = try await executeSecureRequest(request)
        
        // السيرفرات تعيد 201 Created أو 204 No Content عند نجاح الرفع الحقيقي
        guard response.statusCode == 201 || response.statusCode == 204 else {
            throw URLError(.cannotCreateFile)
        }
        
        return RemoteAssetMetadata(
            id: UUID().uuidString,
            remotePath: fileURL.absoluteString,
            size: Int64(fileData.count),
            createdAt: Date()
        )
    }
    
    // MARK: - 3. DOWNLOAD FILE FROM CLOUD (تحميل حقيقي للملفات عبر GET)
    func downloadFile(remotePath: String) async throws -> Data {
        guard let url = URL(string: remotePath) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(credentialString)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await executeSecureRequest(request)
        guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
        
        return data
    }
    
    // دالة مساعدة لاستخراج قيم الأرقام من داخل وسوم الـ XML بدون مكتبات خارجية
    private func parseXMLTag(_ xml: String, tagName: String) -> Int64? {
        let pattern = "<\(tagName)[^>]*>([^<]+)</"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = xml as NSString
        let results = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first, match.numberOfRanges > 1 {
            let valueString = nsString.substring(with: match.range(at: 1))
            return Int64(valueString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // تجربة البحث عن النطاقات المتقدمة بوجود بادئات مثل d:quota
        let advancedPattern = ":\(tagName)[^>]*>([^<]+)</"
        guard let advRegex = try? NSRegularExpression(pattern: advancedPattern, options: []) else { return nil }
        let advResults = advRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = advResults.first, match.numberOfRanges > 1 {
            let valueString = nsString.substring(with: match.range(at: 1))
            return Int64(valueString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return nil
    }
}
