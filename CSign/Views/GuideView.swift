import SwiftUI
import WebKit
import NimbleViews

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView(_:)), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        context.coordinator.refreshControl = refreshControl
        
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var refreshControl: UIRefreshControl?
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        @objc func refreshWebView(_ sender: UIRefreshControl) {
            if let scrollView = sender.superview as? UIScrollView,
               let webView = scrollView.superview as? WKWebView {
                webView.reload()
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            refreshControl?.endRefreshing()
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            refreshControl?.endRefreshing()
            parent.isLoading = false
        }
    }
}

struct GuideView: View {
    @State private var isLoading = true
    
    var body: some View {
        NBNavigationView("Hướng Dẫn") {
            ZStack {
                WebViewWrapper(url: URL(string: "https://cuongqtx11.github.io/huongdan/")!, isLoading: $isLoading)
                    .ignoresSafeArea(edges: .bottom)
                
                if isLoading {
                    ProgressView("Đang tải...")
                }
            }
        }
    }
}
