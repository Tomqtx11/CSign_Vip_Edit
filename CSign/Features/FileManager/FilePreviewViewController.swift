import UIKit

class FilePreviewViewController: UIViewController {
    var filePath: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
    }
    
    private func setupUI() {
        title = (filePath as NSString).lastPathComponent
        view.backgroundColor = .systemBackground
        
        let shareBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareTapped))
        navigationItem.rightBarButtonItem = shareBtn
    }
    
    private func loadContent() {
        let fileType = FileSystemHelper.shared.fileType(at: filePath)
        
        switch fileType {
        case .image:
            let imageView = UIImageView(image: UIImage(contentsOfFile: filePath))
            imageView.contentMode = .scaleAspectFit
            imageView.frame = view.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(imageView)
            
        case .text, .plist:
            let textView = UITextView(frame: view.bounds)
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            textView.isEditable = false
            textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            if let content = try? String(contentsOfFile: filePath) {
                textView.text = content
            }
            view.addSubview(textView)
            
        case .ipa, .p12, .mobileprovision:
            let infoLabel = UILabel()
            infoLabel.text = "File: \((filePath as NSString).lastPathComponent)\nSize: \(FileSystemHelper.shared.fileSize(at: filePath)) bytes"
            infoLabel.numberOfLines = 0
            infoLabel.textAlignment = .center
            infoLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 100)
            view.addSubview(infoLabel)
            
            let actionBtn = UIButton(type: .system)
            actionBtn.frame = CGRect(x: 20, y: 220, width: view.bounds.width - 40, height: 50)
            
            if fileType == .ipa { actionBtn.setTitle("Import to App Library", for: .normal) }
            else if fileType == .p12 { actionBtn.setTitle("Import as Certificate", for: .normal) }
            else { actionBtn.setTitle("Import as Profile", for: .normal) }
            
            actionBtn.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            view.addSubview(actionBtn)
            
        default:
            let infoLabel = UILabel()
            infoLabel.text = "Unsupported Preview\nFile: \((filePath as NSString).lastPathComponent)\nSize: \(FileSystemHelper.shared.fileSize(at: filePath)) bytes"
            infoLabel.numberOfLines = 0
            infoLabel.textAlignment = .center
            infoLabel.frame = view.bounds
            infoLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(infoLabel)
        }
    }
    
    @objc private func shareTapped() {
        let activity = UIActivityViewController(activityItems: [URL(fileURLWithPath: filePath)], applicationActivities: nil)
        present(activity, animated: true)
    }
    
    @objc private func actionTapped() {
        showSuccess("Import feature placeholder")
    }
}
