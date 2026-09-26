//
//  SettingsView.swift
//  CSign
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("csign.selectedCert") private var _storedSelectedCert: Int = 0

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

    
	
    
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				                

                
				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
				}
                
				NBSection(.localized("Certificates")) {
                    
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("No Certificate"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificates"), systemImage: "checkmark.seal")
					}
                 
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}
                
				NBSection(.localized("Features")) {
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Chọn máy chủ ký"), systemImage: "arrow.down.circle")
					}
				} footer: {
					Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
				}
                
				_directories()
                
				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
				
				NBSection("Giới thiệu") {
					Link(destination: URL(string: "https://t.me/tomqtx1111")!) {
						Label("Liên hệ admin", systemImage: "person.crop.circle")
					}
					Link(destination: URL(string: "https://t.me/chungchicuios")!) {
						Label("Tham gia group", systemImage: "person.3")
					}
					Link(destination: URL(string: "https://t.me/chungchifree11")!) {
						Label("Kênh thông báo", systemImage: "bell.badge")
					}
				}
				
				NBSection("Credits & Acknowledgement") {
					Link(destination: URL(string: "https://github.com/khcrysalis/CSign")!) {
						Label("Original Source Code: Samara (khcrysalis)", systemImage: "heart.fill")
							.foregroundColor(.red)
					}
				} footer: {
					Text("A special thanks to Samara for developing this amazing open-source project.")
				}
				
			}

			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: {
						let current = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "vi"
						let newLanguage = current == "en" ? "vi" : "en"
						UserDefaults.standard.set([newLanguage], forKey: "AppleLanguages")
						UserDefaults.standard.synchronize()
						
						let alert = UIAlertController(title: "Language Changed", message: "Ứng dụng sẽ thoát để áp dụng ngôn ngữ mới.", preferredStyle: .alert)
						alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
							exit(0)
						})
						UIApplication.topViewController()?.present(alert, animated: true)
					}) {
						Image(systemName: "globe")
					}
				}
			}
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}
    
}
