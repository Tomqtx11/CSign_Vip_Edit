//
//  SigningTweaksView.swift
//  CSign
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	@State private var _isBuiltInPresenting = false
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		NBList(.localized("Tweaks")) {
			NBSection(.localized("Injection")) {
				SigningOptionsView.picker(
					.localized("Injection Path"),
					systemImage: "doc.badge.gearshape",
					selection: $options.injectPath,
					values: Options.InjectPath.allCases
				)
				SigningOptionsView.picker(
					.localized("Injection Folder"),
					systemImage: "folder.badge.gearshape",
					selection: $options.injectFolder,
					values: Options.InjectFolder.allCases
				)
				
				Toggle(isOn: $options.injectIntoExtensions) {
					Label(.localized("Inject into Extensions"), systemImage: "syringe")
				}
			}
			
			NBSection(.localized("Tweaks")) {
				if !options.injectionFiles.isEmpty {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak)
					}
				} else {
					Text(verbatim: .localized("No files chosen."))
						.font(.footnote)
						.foregroundColor(.disabled())
				}
			}
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button(.localized("Choose from Files"), systemImage: "folder") {
						_isAddingPresenting = true
					}
					Button(.localized("Built-In Tweaks"), systemImage: "puzzlepiece") {
						_isBuiltInPresenting = true
					}
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.dylib, .deb],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					guard !urls.isEmpty else { return }
					
					for url in urls {
						FileManager.default.moveAndStore(url, with: "CSignTweak") { url in
							options.injectionFiles.append(url)
						}
					}
				}
			)
			.ignoresSafeArea()
		}
		.sheet(isPresented: $_isBuiltInPresenting) {
			BuiltInTweaksView(options: $options)
		}
		.animation(.smooth, value: options.injectionFiles)
	}
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL) -> some View {
		Label(tweak.lastPathComponent, systemImage: "folder.fill")
			.lineLimit(2)
			.frame(maxWidth: .infinity, alignment: .leading)
			.swipeActions(edge: .trailing, allowsFullSwipe: true) {
				_fileActions(tweak: tweak)
			}
			.contextMenu {
				_fileActions(tweak: tweak)
			}
	}
	
	@ViewBuilder
	private func _fileActions(tweak: URL) -> some View {
		Button(role: .destructive) {
			FileManager.default.deleteStored(tweak) { url in
				if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
					options.injectionFiles.remove(at: index)
				}
			}
		} label: {
			Label(.localized("Delete"), systemImage: "trash")
		}
	}
}

struct BuiltInTweaksView: View {
	@Environment(\.dismiss) var dismiss
	@Binding var options: Options
	
	@State private var builtInURLs: [URL] = []
	
	let descriptions: [String: String] = [
		"AdSkip.dylib": "Tự động đóng quảng cáo khi truy cập app.",
		"AlwaysOnScreen.dylib": "Giữ màn hình luôn sáng, không tự tắt.",
		"AutoKill.dylib": "Dylib hẹn giờ tự động thoát App.",
		"FixCrash.dylib": "Sửa lỗi văng ứng dụng (crash).",
		"FixCrash1.dylib": "Sửa lỗi văng ứng dụng bổ sung (cách 1).",
		"FixCrash2.dylib": "Sửa lỗi văng ứng dụng bổ sung (cách 2).",
		"H5GG.dylib": "Công cụ cheat game/thay đổi giá trị bộ nhớ (Memory Editor).",
		"LocalIAPStore14.dylib": "Bẻ khoá mua hàng trong ứng dụng (In-App Purchase) miễn phí.",
		"LuckySpeeder_1.0.1.dylib": "Tăng giảm tốc độ game.",
		"NoADS 2.dylib": "Chặn quảng cáo trong ứng dụng.",
		"SatellaJailed.dylib": "Bẻ khoá mua hàng trong ứng dụng (không cần Jailbreak).",
		"adSpeed-Noads-purchase.dylib": "Tổng hợp: Tăng tốc, chặn QC và bẻ khoá mua hàng.",
		"adspeed.dylib": "Tăng tốc độ quảng cáo dùng mục đích xem quảng cáo nhận thưởng.",
		"autoclick.dylib": "Tự động bấm màn hình (Auto Clicker)."
	]
	
	var body: some View {
		NavigationView {
			NBList(.localized("Built-In Tweaks")) {
				if builtInURLs.isEmpty {
					Text(verbatim: .localized("No built-in tweaks found."))
						.foregroundColor(.gray)
				} else {
					ForEach(builtInURLs, id: \.absoluteString) { url in
						Button(action: {
							if options.injectionFiles.contains(where: { $0.lastPathComponent == url.lastPathComponent }) {
								if let idx = options.injectionFiles.firstIndex(where: { $0.lastPathComponent == url.lastPathComponent }) {
									options.injectionFiles.remove(at: idx)
								}
							} else {
								options.injectionFiles.append(url)
							}
						}) {
							HStack {
								VStack(alignment: .leading, spacing: 4) {
									Label(url.lastPathComponent, systemImage: "puzzlepiece")
										.font(.headline)
									if let desc = descriptions[url.lastPathComponent] {
										Text(desc)
											.font(.caption)
											.foregroundColor(.secondary)
									}
								}
								Spacer()
								if options.injectionFiles.contains(where: { $0.lastPathComponent == url.lastPathComponent }) {
									Image(systemName: "checkmark")
										.foregroundColor(.blue)
								}
							}
						}
						.foregroundColor(.primary)
					}
				}
			}
			.navigationTitle(.localized("Built-In Tweaks"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(.localized("Done")) {
						dismiss()
					}
				}
			}
		}
		.onAppear {
			if let builtInPath = Bundle.main.resourceURL?.appendingPathComponent("BuiltInTweaks"),
			   let files = try? FileManager.default.contentsOfDirectory(at: builtInPath, includingPropertiesForKeys: nil) {
				builtInURLs = files.filter { $0.pathExtension == "dylib" }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
			}
		}
	}
}
