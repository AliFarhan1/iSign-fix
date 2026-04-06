import SwiftUI
import UniformTypeIdentifiers

struct DylibManagerView: View {
    @StateObject private var engine = iSignEngine.shared
    @State private var dylibs: [DylibInfo] = []
    @State private var showDylibPicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showDetail: DylibInfo?

    var body: some View {
        NavigationView {
            Group {
                if engine.ipaInfo == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "cpu")
                            .font(.system(size: 50)).foregroundColor(.secondary)
                        Text("لا يوجد IPA محمّل").font(.headline)
                        Text("قم بتحميل IPA من تبويب الملفات")
                            .font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("إجمالي المكتبات")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("\(dylibs.count) مكتبة")
                                        .font(.title2).bold()
                                }
                                Spacer()
                                Image(systemName: "cpu.fill")
                                    .font(.largeTitle).foregroundColor(.orange.opacity(0.7))
                            }
                        }
                        Section("المكتبات") {
                            if dylibs.isEmpty {
                                Text("لا توجد مكتبات")
                                    .foregroundColor(.secondary).font(.caption)
                            } else {
                                ForEach(dylibs) { dylib in
                                    DylibRow(dylib: dylib)
                                        .onTapGesture { showDetail = dylib }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                removeDylib(dylib)
                                            } label: {
                                                Label("حذف", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { loadDylibs() }
                }
            }
            .navigationTitle("المكتبات")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if engine.ipaInfo != nil {
                        Button(action: { showDylibPicker = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showDylibPicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "dylib") ?? .data,
                    UTType(filenameExtension: "framework") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in handleDylibImport(result) }
            .sheet(item: $showDetail) { dylib in DylibDetailView(dylib: dylib) }
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .onAppear { loadDylibs() }
            .onChange(of: engine.ipaInfo?.bundleID) { _ in loadDylibs() }
        }
    }

    func loadDylibs() {
        guard let info = engine.ipaInfo,
              let extracted = engine.extractedPath else { dylibs = []; return }
        var result: [DylibInfo] = []
        let fm = FileManager.default
        let payloadDir = extracted.appendingPathComponent("Payload")
        let appDirs = (try? fm.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }) ?? []
        if let appDir = appDirs.first {
            let frameworksDir = appDir.appendingPathComponent("Frameworks")
            let items = (try? fm.contentsOfDirectory(
                at: frameworksDir,
                includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for item in items {
                let size = (try? item.resourceValues(
                    forKeys: [.fileSizeKey]).fileSize) ?? 0
                result.append(DylibInfo(
                    name: item.lastPathComponent, path: item.path,
                    size: Int64(size), isInjected: false,
                    archs: detectArchs(at: item)))
            }
        }
        for dylibPath in info.embeddedDylibs where dylibPath.hasPrefix("@") {
            let name = URL(fileURLWithPath: dylibPath).lastPathComponent
            if !result.contains(where: { $0.name == name }) {
                result.append(DylibInfo(name: name, path: dylibPath,
                                        size: 0, isInjected: true, archs: []))
            }
        }
        dylibs = result
    }

    func detectArchs(at url: URL) -> [String] {
        guard let data = FileManager.default.contents(atPath: url.path),
              data.count >= 4 else { return [] }
        var magic: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &magic) { data.copyBytes(to: $0) }
        switch magic {
        case 0xCAFEBABE, 0xBEBAFECA: return ["armv7", "arm64"]
        case 0xFEEDFACF, 0xCFFAEDFE: return ["arm64"]
        case 0xFEEDFACE, 0xCEFAEDFE: return ["armv7"]
        default: return ["unknown"]
        }
    }

    func handleDylibImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let extracted = engine.extractedPath else { return }
            _ = url.startAccessingSecurityScopedResource()
            Task {
                do {
                    try await engine.injectDylib(dylibURL: url, into: extracted)
                    await MainActor.run { loadDylibs() }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription; showError = true
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let e):
            errorMessage = e.localizedDescription; showError = true
        }
    }

    func removeDylib(_ dylib: DylibInfo) {
        guard let extracted = engine.extractedPath else { return }
        try? engine.removeDylib(named: dylib.name, from: extracted)
        loadDylibs()
    }
}

struct DylibRow: View {
    let dylib: DylibInfo
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(dylib.isInjected
                          ? Color.orange.opacity(0.15)
                          : Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: dylib.isInjected ? "syringe.fill" : "cpu.fill")
                    .foregroundColor(dylib.isInjected ? .orange : .blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dylib.name)
                    .font(.system(.body, design: .monospaced)).lineLimit(1)
                if dylib.size > 0 {
                    Text(formatSize(dylib.size))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    func formatSize(_ b: Int64) -> String {
        let kb = Double(b) / 1024
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb/1024)
    }
}

struct DylibDetailView: View {
    let dylib: DylibInfo
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                Section("معلومات المكتبة") {
                    HStack { Text("الاسم").foregroundColor(.secondary); Spacer(); Text(dylib.name) }
                    HStack { Text("النوع").foregroundColor(.secondary); Spacer()
                        Text(dylib.isInjected ? "محقونة" : "مدمجة") }
                    if dylib.size > 0 {
                        HStack { Text("الحجم").foregroundColor(.secondary); Spacer()
                            Text(formatSize(dylib.size)) }
                    }
                }
                if !dylib.archs.isEmpty {
                    Section("المعماريات") {
                        ForEach(dylib.archs, id: \.self) { arch in
                            Label(arch, systemImage: "cpu")
                        }
                    }
                }
            }
            .navigationTitle(dylib.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }
    func formatSize(_ b: Int64) -> String {
        let kb = Double(b) / 1024
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb/1024)
    }
}
