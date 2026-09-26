import UIKit

class SigningProgressViewController: UIViewController, IPASignerDelegate {
    
    var ipaFile: IPAFile?
    var options: IPASigner.SigningOptions?
    private let signer = IPASigner()
    
    private let progressView = ProgressView()
    private let stepLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.text = "Preparing..."
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
        
        startSigning()
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
    
    private func startSigning() {
        guard let ipaFile = ipaFile, let options = options else {
            stepLabel.text = "Error: Missing data"
            return
        }
        
        signer.delegate = self
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.signer.sign(ipa: ipaFile, options: options)
        }
    }
    
    @objc private func cancelTapped() {
        signer.cancel()
        navigationController?.popViewController(animated: true)
    }
    
    func signerDidUpdateProgress(_ progress: Float, message: String) {
        DispatchQueue.main.async {
            self.stepLabel.text = message
            self.progressView.progress = CGFloat(progress)
            self.logTextView.text += message + "\n"
            
            let range = NSMakeRange(self.logTextView.text.count - 1, 1)
            self.logTextView.scrollRangeToVisible(range)
        }
    }
    
    func signerDidComplete(signedIPAPath: String, log: String) {
        DispatchQueue.main.async {
            self.progressView.progress = 1.0
            self.stepLabel.text = "Finished!"
            self.logTextView.text += log + "\n"
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.finishTapped))
        }
    }
    
    func signerDidFail(error: Error, log: String) {
        DispatchQueue.main.async {
            self.stepLabel.text = "Failed"
            self.logTextView.text += "Error: \(error.localizedDescription)\n" + log + "\n"
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(self.cancelTapped))
        }
    }
    
    @objc private func finishTapped() {
        dismiss(animated: true)
    }
}
