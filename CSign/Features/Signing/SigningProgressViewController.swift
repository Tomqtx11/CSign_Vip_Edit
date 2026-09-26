import UIKit

class SigningProgressViewController: UIViewController {
    
    private let progressView = ProgressView()
    private let stepLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.text = "Extracting IPA..."
        return label
    }()
    
    private let logTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        tv.textColor = .systemGreen
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.isEditable = false
        tv.layer.cornerRadius = 8
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
    }
    
    private func setupUI() {
        title = "Signing..."
        view.backgroundColor = .systemBackground
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        view.addSubview(stepLabel)
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 160),
            progressView.heightAnchor.constraint(equalToConstant: 160),
            
            stepLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 32),
            stepLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stepLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            logTextView.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 24),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func cancelTapped() {
        // Cancel signing process
        navigationController?.popViewController(animated: true)
    }
}
