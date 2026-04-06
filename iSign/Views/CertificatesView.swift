import SwiftUI
import UniformTypeIdentifiers

struct Certificate: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var teamName: String
    var teamID: String
    var expiryDate: Date
    var isValid: Bool
    var p12Data: Data?
    var provisionData: Data?
    static func == (lhs: Certificate, rhs: Certificate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

class CertificateStore: ObservableObject {
    static let shared = CertificateStore()
    @Published var certificates: [Certificate] = []
    private let savePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("certificates.json")
    }()
    init() { load() }
    func add(_ cert: Certificate) { certificates.append(cert); save() }
    func remove(at offsets: IndexSet) { certificates.remove(atOffsets: offsets); save() }
    private func save() {
        let meta = certificates.map { c in
            ["id": c.id.uuidString, "name": c.name, "teamID": c.teamID,
             "teamName": c.teamName, "expiry": c.expiryDate.timeIntervalSince1970]
        }
        let data = try? JSONSerialization.data(withJSONObject: meta)
        try? data?.write(to: savePath)
    }
    private func load() {
        guard let data = try? Data(contentsOf: savePath),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }
        certificates = arr.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let teamID = dict["teamID"] as? String,
                  let teamName = dict["teamName"] as? String,
                  let expiry = dict["expiry"] as? Double
            else { return nil }
            return Certificate(
                name: name, teamName: teamName, teamID: teamID,
                expiryDate: Date(timeIntervalSince1970: expiry),
                isValid: Date(timeIntervalSince1970: expiry) > Date())
        }
    }
}

struct CertificatesView: View {
    @StateObject private var store = CertificateStore.shared
    @State private var showAddSheet = false
    var body: some View {
        NavigationView {
            List {
                if store.certificates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("لا توجد شهادات")
                            .font(.headline)
                        Text("اضغط + لإضافة شهادة")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(store.certificates) { cert in
                        CertRow(cert: cert)
                    }
                    .onDelete { store.remove(at: $0) }
                }
            }
            .navigationTitle("الشهادات")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddCertificateView()
            }
        }
    }
}

struct CertRow: View {
    let cert: Certificate
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(cert.isValid ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: cert.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundColor(cert.isValid ? .green : .red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(cert.name).font(.headline)
                Text(cert.teamName).font(.caption).foregroundColor(.secondary)
                Text("Team ID: \(cert.teamID)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.blue)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(cert.isValid ? "صالحة" : "منتهية")
                    .font(.caption)
                    .foregroundColor(cert.isValid ? .green : .red)
                Text(cert.expiryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCertificateView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = CertificateStore.shared
    @State private var certName = ""
    @State private var teamName = ""
    @State private var teamID = ""
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 3600)
    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var showP12Picker = false
    @State private var showProvisionPicker = false
    @State private var isImporting = false

    var canAdd: Bool { !certName.isEmpty && !teamID.isEmpty && teamID.count == 10 }

    var body: some View {
        NavigationView {
            Form {
                Section("معلومات الشهادة") {
                    HStack {
                        Text("الاسم"); Spacer()
                        TextField("iPhone Distribution", text: $certName)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Team Name"); Spacer()
                        TextField("My Company", text: $teamName)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Team ID"); Spacer()
                        TextField("XXXXXXXXXX", text: $teamID)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    DatePicker("تاريخ الانتهاء", selection: $expiryDate,
                               displayedComponents: .date)
                }
                Section("ملفات الشهادة") {
                    Button(action: { showP12Picker = true }) {
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(.orange)
                            Text("اختيار P12"); Spacer()
                            Text(p12URL?.lastPathComponent ?? "لم يتم الاختيار")
                                .font(.caption)
                                .foregroundColor(p12URL != nil ? .green : .secondary)
                        }
                    }
                    Button(action: { showProvisionPicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.checkmark").foregroundColor(.blue)
                            Text("Provisioning Profile"); Spacer()
                            Text(provisionURL?.lastPathComponent ?? "اختياري")
                                .font(.caption)
                                .foregroundColor(provisionURL != nil ? .green : .secondary)
                        }
                    }
                }
                Section {
                    Button(action: addCertificate) {
                        HStack {
                            if isImporting { ProgressView().padding(.trailing, 4) }
                            Text("إضافة الشهادة").bold()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!canAdd || isImporting)
                }
            }
            .navigationTitle("إضافة شهادة")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showP12Picker,
                allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result { p12URL = urls.first }
            }
            .fileImporter(
                isPresented: $showProvisionPicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "mobileprovision") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result { provisionURL = urls.first }
            }
        }
    }

    func addCertificate() {
        isImporting = true
        var p12Data: Data? = nil
        var provData: Data? = nil
        if let url = p12URL {
            _ = url.startAccessingSecurityScopedResource()
            p12Data = try? Data(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
        }
        if let url = provisionURL {
            _ = url.startAccessingSecurityScopedResource()
            provData = try? Data(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
        }
        let certsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Certificates")
        try? FileManager.default.createDirectory(
            at: certsDir, withIntermediateDirectories: true)
        if let p12 = p12Data {
            try? p12.write(to: certsDir.appendingPathComponent("\(teamID).p12"))
        }
        if let prov = provData {
            try? prov.write(
                to: certsDir.appendingPathComponent("\(teamID).mobileprovision"))
        }
        store.add(Certificate(
            name: certName,
            teamName: teamName.isEmpty ? certName : teamName,
            teamID: teamID, expiryDate: expiryDate,
            isValid: expiryDate > Date(),
            p12Data: p12Data, provisionData: provData))
        isImporting = false
        dismiss()
    }
}
