//
//  CertificatesAddView.swift
//  CSign
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	@State private var _zipFileName: String = ""
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isImportingZipPresenting = false
	
	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
			Form {
				NBSection("Tệp Chứng Chỉ") {
					Button(action: {
                        _isImportingZipPresenting = true
                    }) {
                        HStack {
                            if _zipFileName.isEmpty {
                                Text("Nhập từ file .zip")
                            } else {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text(_zipFileName)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                    }
				}
				NBSection(.localized("Password")) {
					SecureField(.localized("Enter Password"), text: $_p12Password)
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
				}
				
				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
									.sheet(isPresented: $_isImportingZipPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.zip],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						ZipCertificateHandler.extractCertificate(from: selectedFileURL) { p12, prov in
							if let p12 = p12, let prov = prov {
								DispatchQueue.main.async {
									self._p12URL = p12
									self._provisionURL = prov
                                    self._zipFileName = selectedFileURL.lastPathComponent
								}
							} else {
								DispatchQueue.main.async {
									UIAlertController.showAlertWithOk(title: "Lỗi", message: "Không tìm thấy file .p12 và .mobileprovision trong file ZIP.")
								}
							}
						}
					}
				)
				.ignoresSafeArea()
			}
		}
	}
}

// MARK: - Extension: View
// MARK: - Extension: View (import)
extension CertificatesAddView {
	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("Bad Password"),
				message: .localized("Please check the password and try again.")
			)
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { _ in
			dismiss()
		}
	}
}

