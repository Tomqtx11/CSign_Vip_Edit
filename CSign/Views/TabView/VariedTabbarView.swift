//
//  VariedTabbarView.swift
//  CSign
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: []
	) private var _certificates: FetchedResults<CertificatePair>
	
	@State private var _showMissingCertAlert = false
	@State private var _showCertificatesModal = false
	@State private var hasPromptedMissingCert = false

	var body: some View {
		Group {
			if #available(iOS 18, *) {
				ExtendedTabbarView()
			} else {
				TabbarView()
			}
		}
		.onAppear {
			// Check periodically in case defaults take time, or just show if it's really empty
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
				if _certificates.isEmpty && !hasPromptedMissingCert {
					_showMissingCertAlert = true
				}
			}
		}
		.onChange(of: _certificates.count) { _ in
			if _certificates.isEmpty && !hasPromptedMissingCert {
				_showMissingCertAlert = true
			}
		}
		.alert("Chưa Có Chứng Chỉ", isPresented: $_showMissingCertAlert) {
			Button("Hủy", role: .cancel) {
				hasPromptedMissingCert = true
			}
			Button("Nhập Ngay") {
				hasPromptedMissingCert = true
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					_showCertificatesModal = true
				}
			}
		} message: {
			Text("Bạn cần thêm ít nhất một chứng chỉ (Certificate) trước khi có thể ký ứng dụng. Vui lòng nhập chứng chỉ ngay.")
		}
		.sheet(isPresented: $_showCertificatesModal) {
			NavigationView {
				CertificatesView()
					.navigationBarTitleDisplayMode(.inline)
			}
		}
	}
}
