//
//  TabEnum.swift
//  csign
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews
import Combine

enum TabEnum: String, CaseIterable, Hashable {
	case sources
	case library
	case history
	case settings
	case certificates
	case guide
	
	var title: String {
		switch self {
		case .sources:     	return "IPA Mod"
		case .library: 		return .localized("Thư viện")
		case .history:      return .localized("Lịch sử")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		case .guide:		return "Hướng Dẫn"
		}
	}
	
	var icon: String {
		switch self {
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .history:      return "clock.arrow.circlepath"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .guide:		return "book.closed"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .sources: SourcesView()
		case .library: LibraryView()
		case .history: HistoryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		case .guide: GuideView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.library,
			.sources,
			.history,
			.guide,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}

// MARK: - History Feature


struct DownloadRowView: View {
    @ObservedObject var download: Download
    var cancelAction: () -> Void
    
    var displayName: String {
        if let appName = download.sourceProvenance?.sourceAppName { return appName }
        let name = download.fileName.replacingOccurrences(of: ".ipa", with: "", options: .caseInsensitive)
        return name
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.headline)
                
                ProgressView(value: download.overallProgress)
                HStack {
                    Text(String(format: "%.1f%%", download.overallProgress * 100))
                    Spacer()
                    if download.totalBytes > 0 {
                        Text("\(formatBytes(download.bytesDownloaded)) / \(formatBytes(download.totalBytes))")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: cancelAction) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct HistoryView: View {
    @StateObject var downloadManager = DownloadManager.shared
    @StateObject var updateManager = UpdateManager.shared
    
    @State private var _selectedInfoAppPresenting: AnyApp?
    @State private var _selectedSigningAppPresenting: AnyApp?
    @State private var _selectedInstallAppPresenting: AnyApp?
    @State private var _selectedAppUUIDs: Set<String> = []
    @State private var _editMode: EditMode = .inactive
    @State private var _searchText = ""
    @Namespace private var _namespace
    @State private var selectedTab = 0 // 0: Lịch sử Ký, 1: Lịch sử Download
    
    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
        animation: .snappy
    ) private var _signedApps: FetchedResults<Signed>
    
    private var _filteredSignedApps: [Signed] {
        _signedApps.filter {
            _searchText.isEmpty ||
                (($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
        }
    }
    
    
    var body: some View {
        NBNavigationView(.localized("Lịch sử")) {
            NBListAdaptable {
                Picker("", selection: $selectedTab) {
                    Text("Đã Ký").tag(0)
                    Text("Tải Xuống").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                if selectedTab == 0 {
                    signedHistoryContent
                } else {
                    downloadHistoryContent
                }
            }
            .searchable(text: $_searchText, placement: .platform())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                    if _editMode.isEditing {
                        NBToolbarButton(
                            .localized("Delete"),
                            systemImage: "trash",
                            isDisabled: _selectedAppUUIDs.isEmpty
                        ) {
                            _bulkDeleteSelectedApps()
                        }
                    }
                }
            }
            .environment(\.editMode, $_editMode)
            .sheet(item: $_selectedInfoAppPresenting) { app in
                LibraryInfoView(app: app.base)
            }
            .sheet(item: $_selectedInstallAppPresenting) { app in
                InstallPreviewView(app: app.base, isSharing: app.archive)
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $_selectedSigningAppPresenting) { app in
                SigningView(app: app.base, restoredOptions: app.restoredOptions)
                    .compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
            }
            .onChange(of: _editMode) { mode in
                if mode == .inactive {
                    _selectedAppUUIDs.removeAll()
                }
            }
        }
    }
    
    var signedHistoryContent: some View {
        Group {
            if _filteredSignedApps.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("Chưa có lịch sử ký nào."), systemImage: "clock.badge.exclamationmark")
                    } description: {
                        Text(.localized("Khi bạn ký một ứng dụng, nó sẽ xuất hiện ở đây cùng với toàn bộ cấu hình đã chọn."))
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                NBSection(
                    .localized("Signed"),
                    secondary: _filteredSignedApps.count.description
                ) {
                    ForEach(_filteredSignedApps, id: \.uuid) { app in
                        LibraryCellView(
                            app: app,
                            selectedInfoAppPresenting: $_selectedInfoAppPresenting,
                            selectedSigningAppPresenting: $_selectedSigningAppPresenting,
                            selectedInstallAppPresenting: $_selectedInstallAppPresenting,
							isSelected: _selectedAppUUIDs.contains(app.uuid ?? ""),
							toggleSelection: {
								guard let uuid = app.uuid else { return }
								if _selectedAppUUIDs.contains(uuid) {
									_selectedAppUUIDs.remove(uuid)
								} else {
									_selectedAppUUIDs.insert(uuid)
								}
							}
                        )
                    }
                }
            }
        }
    }
    
    var downloadHistoryContent: some View {
        Group {
            if downloadManager.downloads.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label("Không có tệp tải xuống", systemImage: "arrow.down.circle")
                    } description: {
                        Text("Các ứng dụng đang tải xuống sẽ hiển thị ở đây.")
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                NBSection("Đang Tải Xuống") {
                    ForEach(downloadManager.downloads) { dl in
                        DownloadRowView(download: dl) {
                            downloadManager.cancelDownload(dl)
                        }
                    }
                }
            }
        }
    }


    private func _bulkDeleteSelectedApps() {
        let selectedApps = _filteredSignedApps.filter { app in
            guard let uuid = app.uuid else { return false }
            return _selectedAppUUIDs.contains(uuid)
        }
        for app in selectedApps {
            Storage.shared.deleteApp(for: app)
        }
        _selectedAppUUIDs.removeAll()
    }
}
