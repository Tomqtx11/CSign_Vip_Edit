//
//  InstallationView.swift
//  CSign
//
//  Created by samara on 3.06.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct InstallationView: View {
	@AppStorage("CSign.installationMethod") private var _installationMethod: Int = 0

	// MARK: Body
	var body: some View {
		NBList(.localized("Cài Đặt Cục Bộ")) {
			Section {
				HStack {
					Label(.localized("Máy Chủ Local (Mặc Định)"), systemImage: "server.rack")
					Spacer()
					Image(systemName: "checkmark").foregroundColor(.accentColor)
				}
			} footer: {
				Text("Phương thức cài đặt qua Máy Chủ Local (itms-services://) đảm bảo tính ổn định và an toàn nhất.")
			}
			
			ServerView()
		}
		.onAppear {
			// Luôn ép kiểu là 0 (Server Local)
			if _installationMethod != 0 {
				_installationMethod = 0
			}
		}
	}
}

