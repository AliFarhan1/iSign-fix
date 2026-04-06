import SwiftUI
import UniformTypeIdentifiers

struct IPABrowserView: View {
    @StateObject private var engine = iSignEngine.shared
    @State private var showFilePicker = false
    @State private var showFileExplorer = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let info = engine.ipaInfo {
                    AppInfoCard(info: info).padding()
                } else {
                    DropZoneView(showFilePicker: $showFilePicker).padding()
                }

                if engine.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView(value: engine.progress).tint(.blue)
                        Text(engine.statusMessage)
                            .font(.caption).foregroundColor(.secondary)
                    }.padding(.horizontal)
                }

                if engine.ipaInfo != nil {
                    List {
                        Section("معلومات التطبيق") {
                            if let info = engine.ipaInfo {
                                InfoRow(label: "Bundle ID", value: info.bundleID)
                                InfoRow(label: "الإصدار", value: "v\(info.version) (\(info.buildNumber))")
                                InfoRow(label: "iOS", value: "\(info.minOSVersion)+")
                                InfoRow(label: "المكتبات", value: "\(info.embeddedDylibs.count) مكتبة")
                            }
                        }
                        if let dylibs = engine.ipaInfo?.embeddedDylibs, !dylibs.isEmpty {
                            Section("المكتبات") {
                                ForEach(dylibs, id: \.self) { dylib in
                                    Label(dylib, systemImage: "cpu.fill")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                Spacer()
            }
            .navigationTitle("iSign")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if engine.ipaInfo != nil {
                        Button(action: clearIPA) {
                            Image(systemName: "xmark.circle")
                        }
                    }
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "ipa") ?? .data,
                    UTType(filenameExtension: "zip") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in handleFileImport(result) }
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            Task {
                do {
                    _ = try await engine.extractIPA(at: url)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func clearIPA() {
        engine.ipaInfo = nil
        engine.extractedPath = nil
        engine.currentIPAPath = nil
    }
}

struct DropZoneView: View {
    @Binding var showFilePicker: Bool
    var body: some View {
        Button(action: { showFilePicker = true }) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48)).foregroundColor(.blue)
                Text("اسحب IPA أو اضغط للاختيار").font(.headline)
                Text("يدعم ملفات .ipa و .zip")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).frame(height: 180)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
        .buttonStyle(.plain)
    }
}

struct AppInfoCard: View {
    let info: IPAInfo
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let iconData = info.iconData, let img = UIImage(data: iconData) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32)).foregroundColor(.blue)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(info.displayName).font(.headline)
                Text(info.bundleID).font(.caption).foregroundColor(.secondary)
                HStack {
                    Label("v\(info.version)", systemImage: "tag.fill")
                    Label("iOS \(info.minOSVersion)+", systemImage: "iphone")
                }
                .font(.caption2).foregroundColor(.blue)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced))
        }
    }
}
