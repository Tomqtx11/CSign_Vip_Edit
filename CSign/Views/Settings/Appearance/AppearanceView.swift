//
//  AppearanceView.swift
//  CSign
//
//  Created by samara on 7.05.2025.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
// dear god help me
struct AppearanceView: View {
	@AppStorage("CSign.userInterfaceStyle")
	private var _userIntefacerStyle: Int = UIUserInterfaceStyle.unspecified.rawValue
	
	@AppStorage("CSign.shouldTintIcons")
	private var _shouldTintIcons: Bool = false
	
	@AppStorage("CSign.shouldChangeIconsBasedOffStyle")
	private var _shouldChangeIconsBasedOffStyle: Bool = false
	
	@AppStorage("CSign.storeCellAppearance")
	private var _storeCellAppearance: Int = 0
	private let _storeCellAppearanceMethods: [(name: String, desc: String)] = [
		(.localized("Standard"), .localized("Default style for the app, only includes subtitle.")),
		(.localized("Big Description"), .localized("Adds the localized description of the app."))
	]
	
	@AppStorage("CSign.userTintColor")
	private var _selectedColorHex: String = "#848ef9"
	
	private var _tintColorBinding: Binding<Color> {
		Binding(
			get: { Color(hex: _selectedColorHex) },
			set: { _selectedColorHex = $0.toHex() }
		)
	}
	
	@State private var showingIconAlert = false
	@State private var _currentIcon: String = UIApplication.shared.alternateIconName ?? "Default"
	private let _appIcons: [(name: String, image: String)] = [
		("Default", "Glyph"),
		("Cyberpunk", "Icon-Cyberpunk"),
		("Hacker", "Icon-Hacker")
	]
	
	// MARK: Body
	var body: some View {
		NBList(.localized("Appearance")) {
			Section {
				Picker(.localized("Appearance"), selection: $_userIntefacerStyle) {
					ForEach(UIUserInterfaceStyle.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { style in
						Text(style.label).tag(style.rawValue)
					}
				}
				.pickerStyle(.segmented)
			}
			
			NBSection(.localized("Theme")) {
				AppearanceTintColorView()
					.listRowInsets(EdgeInsets())
					.listRowBackground(EmptyView())
			}
			
			Section {
				ColorPicker(
					.localized("Custom Theme Color"),
					selection: _tintColorBinding,
					supportsOpacity: false
				)
			}
			
			NBSection(.localized("App Icon")) {
				Picker(.localized("App Icon"), selection: $_currentIcon) {
					ForEach(_appIcons, id: \.name) { icon in
						HStack(spacing: 12) {
							let uiImage: UIImage? = {
								// For Asset Catalog appiconsets, load via the 60x60@2x naming convention
								if let img = UIImage(named: icon.image) { return img }
								// Fallback: try raw file in bundle root (for CustomIcons copied by Makefile)
								let path2x = Bundle.main.bundleURL.appendingPathComponent(icon.image + "@2x.png")
								if let img = UIImage(contentsOfFile: path2x.path) { return img }
								// Fallback: try 60x60 naming (Asset Catalog compiled icons)
								let path60 = Bundle.main.bundleURL.appendingPathComponent(icon.image + "60x60@2x.png")
								return UIImage(contentsOfFile: path60.path)
							}()
							if let uiImage {
								Image(uiImage: uiImage)
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 40, height: 40)
									.cornerRadius(10)
							} else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
							Text(icon.name).font(.body)
						}
						.tag(icon.name)
					}
				}
				.pickerStyle(.inline)
				.labelsHidden()
				.onChange(of: _currentIcon) { newValue in
					let iconName: String? = newValue == "Default" ? nil : newValue
					UIApplication.shared.setAlternateIconName(iconName) { error in
						if let error = error {
							print("Icon change error: \(error.localizedDescription)")
						}
						DispatchQueue.main.async {
							showingIconAlert = true
						}
					}
				}
			}
			
			if #available(iOS 18.0, *) {
				NBSection(.localized("Library")) {
					Toggle(.localized("Dynamic Icons"), isOn: $_shouldChangeIconsBasedOffStyle)
					if #available(iOS 18.2, *) {
						Toggle(.localized("Tinted Icons"), isOn: $_shouldTintIcons)
					}
				}
			}
			
			NBSection(.localized("Sources")) {
				Picker(.localized("Store Cell Appearance"), selection: $_storeCellAppearance) {
					ForEach(0..<_storeCellAppearanceMethods.count, id: \.self) { index in
						let method = _storeCellAppearanceMethods[index]
						NBTitleWithSubtitleView(
							title: method.name,
							subtitle: method.desc
						)
						.tag(index)
					}

				}
				.labelsHidden()
				.pickerStyle(.inline)
			}
		}
		.alert(.localized("Khởi động lại ứng dụng"), isPresented: $showingIconAlert) {
			Button(.localized("Thoát ngay"), role: .destructive) { exit(0) }
			Button(.localized("Để sau"), role: .cancel) { }
		} message: {
			Text(.localized("Để thay đổi biểu tượng ứng dụng có hiệu lực hoàn toàn (đặc biệt khi cài qua TrollStore hoặc sideload), vui lòng khởi động lại ứng dụng."))
		}
		.onChange(of: _userIntefacerStyle) { value in
			if let style = UIUserInterfaceStyle(rawValue: value) {
				UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
			}
		}
	}
}
