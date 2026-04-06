import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultTeamID") var defaultTeamID = ""
    @AppStorage("keepOriginal") var keepOriginal = true

    var body: some View {
        NavigationView {
            Form {
                Section("إعدادات التوقيع") {
                    HStack {
                        Text("Team ID الافتراضي")
                        Spacer()
                        TextField("XXXXXXXXXX", text: $defaultTeamID)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.allCharacters)
                            .frame(width: 120)
                    }
                    Toggle("الاحتفاظ بالنسخة الأصلية", isOn: $keepOriginal)
                }
                Section("معلومات") {
                    HStack {
                        Text("الإصدار").foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0")
                    }
                    HStack {
                        Text("الوضع").foregroundColor(.secondary)
                        Spacer()
                        Text("IPA Editor + Signer")
                    }
                    HStack {
                        Text("متطلبات").foregroundColor(.secondary)
                        Spacer()
                        Text("iOS 16+")
                    }
                }
                Section("مسارات العمل") {
                    let docsPath = FileManager.default
                        .urls(for: .documentDirectory, in: .userDomainMask)[0].path
                    VStack(alignment: .leading, spacing: 4) {
                        Text("مجلد العمل").foregroundColor(.secondary).font(.caption)
                        Text("\(docsPath)/iSign_Work")
                            .font(.system(.caption2, design: .monospaced))
                    }
                    Button("مسح ملفات العمل المؤقتة", role: .destructive) {
                        clearWorkDir()
                    }
                }
            }
            .navigationTitle("الإعدادات")
        }
    }

    func clearWorkDir() {
        let docsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let workDir = docsDir.appendingPathComponent("iSign_Work")
        try? FileManager.default.removeItem(at: workDir)
        try? FileManager.default.createDirectory(
            at: workDir, withIntermediateDirectories: true)
    }
}
