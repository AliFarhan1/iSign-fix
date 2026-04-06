import SwiftUI

struct SigningView: View {
    @StateObject private var engine = iSignEngine.shared
    @StateObject private var certStore = CertificateStore.shared
    @State private var selectedCert: Certificate?
    @State private var bundleIDOverride = ""
    @State private var signedIPAURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // IPA Status
                    HStack {
                        Image(systemName: engine.ipaInfo != nil
                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(engine.ipaInfo != nil ? .green : .red)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(engine.ipaInfo != nil ? "IPA محمّل" : "لا يوجد IPA")
                                .font(.headline)
                            if let info = engine.ipaInfo {
                                Text("\(info.displayName) · v\(info.version)")
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("قم بتحميل IPA من تبويب الملفات")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    // Certificate
                    VStack(alignment: .leading, spacing: 8) {
                        Label("الشهادة", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                        if certStore.certificates.isEmpty {
                            Text("لا توجد شهادات. أضف من تبويب الشهادات.")
                                .font(.caption).foregroundColor(.orange)
                        } else {
                            Picker("اختر شهادة", selection: $selectedCert) {
                                Text("اختر...").tag(nil as Certificate?)
                                ForEach(certStore.certificates) { cert in
                                    Text("\(cert.name) (\(cert.teamID))")
                                        .tag(cert as Certificate?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    // Bundle ID
                    VStack(alignment: .leading, spacing: 8) {
                        Label("تعديل Bundle ID (اختياري)", systemImage: "pencil.circle")
                            .font(.headline)
                        TextField(engine.ipaInfo?.bundleID ?? "com.example.app",
                                  text: $bundleIDOverride)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    // Sign Button
                    Button(action: signIPA) {
                        HStack {
                            if engine.isProcessing { ProgressView().tint(.white) }
                            Image(systemName: "signature")
                            Text(engine.isProcessing
                                 ? engine.statusMessage : "توقيع التطبيق")
                                .bold()
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(canSign ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(14)
                    }
                    .disabled(!canSign || engine.isProcessing)

                    if let signedURL = signedIPAURL {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("IPA موقّع جاهز!", systemImage: "checkmark.seal.fill")
                                    .foregroundColor(.green).font(.headline)
                                Text(signedURL.lastPathComponent)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { showShareSheet = true }) {
                                Label("مشاركة", systemImage: "square.and.arrow.up")
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white).cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("التوقيع")
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .sheet(isPresented: $showShareSheet) {
                if let url = signedIPAURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    var canSign: Bool { engine.ipaInfo != nil && selectedCert != nil }

    func signIPA() {
        guard let cert = selectedCert, let extracted = engine.extractedPath else { return }
        Task {
            do {
                let url = try await engine.signIPA(
                    extractedURL: extracted, certificate: cert,
                    bundleIDOverride: bundleIDOverride.isEmpty ? nil : bundleIDOverride,
                    entitlementsOverride: nil)
                await MainActor.run { signedIPAURL = url }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription; showError = true
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
