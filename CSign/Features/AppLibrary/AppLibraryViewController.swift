import UIKit
import UniformTypeIdentifiers
import ZIPFoundation

class AppLibraryViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var emptyStateView: EmptyStateView!
    private var ipaFiles: [IPAFile] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        title = "App Library"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let importMenu = UIMenu(title: "", children: [
            UIAction(title: "Import from Files", image: UIImage(systemName: "folder")) { [weak self] _ in self?.openDocumentPicker() },
            UIAction(title: "Import from URL", image: UIImage(systemName: "link")) { [weak self] _ in self?.openURLPrompt() }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", image: UIImage(systemName: "plus"), primaryAction: nil, menu: importMenu)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 72
        tableView.register(AppCell.self, forCellReuseIdentifier: "AppCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        emptyStateView = EmptyStateView(iconName: "square.grid.2x2", title: "No Apps Yet", detail: "Import IPA files to get started")
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadData() {
        ipaFiles = StorageManager.shared.loadIPAs()
        tableView.reloadData()
        emptyStateView.isHidden = !ipaFiles.isEmpty
    }
    
    private func openDocumentPicker() {
        let types: [String] = ["com.apple.itunes.ipa", "public.zip-archive"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func openURLPrompt() {
        let alert = UIAlertController(title: "Import from URL", message: "Enter direct download link to IPA", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "https://example.com/app.ipa"
            tf.keyboardType = .URL
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in
            guard let urlStr = alert.textFields?.first?.text, let url = URL(string: urlStr) else { return }
            self?.downloadIPA(from: url)
        })
        present(alert, animated: true)
    }
    
    private func downloadIPA(from url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                guard let localURL = localURL else { return }
                self?.importIPA(from: localURL, originalName: url.lastPathComponent)
            }
        }
        task.resume()
    }
    
    private func importIPA(from url: URL, originalName: String) {
        let name = originalName.hasSuffix(".ipa") ? originalName : originalName + ".ipa"
        let destPath = StorageManager.shared.ipaLibraryDirectory + "/" + name
        
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
            
            let fileManager = FileManager.default
            let tempExtract = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempExtract, withIntermediateDirectories: true)
            
            var bundleId = "com.unknown"
            var appName = name
            var version = "1.0"
            var minOS = "14.0"
            
            if let archive = Archive(url: URL(fileURLWithPath: destPath), accessMode: .read) {
                if let infoPlistEntry = archive.first(where: { $0.path.hasPrefix("Payload/") && $0.path.hasSuffix(".app/Info.plist") }) {
                    let extractedPlistURL = tempExtract.appendingPathComponent("Info.plist")
                    _ = try archive.extract(infoPlistEntry, to: extractedPlistURL)
                    
                    if let dict = NSDictionary(contentsOf: extractedPlistURL) {
                        bundleId = dict["CFBundleIdentifier"] as? String ?? bundleId
                        appName = dict["CFBundleDisplayName"] as? String ?? dict["CFBundleName"] as? String ?? appName
                        version = dict["CFBundleShortVersionString"] as? String ?? version
                        minOS = dict["MinimumOSVersion"] as? String ?? minOS
                    }
                }
            }
            
            let fileSize = FileSystemHelper.shared.fileSize(at: destPath)
            let newIPA = IPAFile(
                id: UUID().uuidString,
                fileName: name,
                bundleName: appName,
                bundleIdentifier: bundleId,
                version: version,
                buildVersion: "1",
                minOSVersion: minOS,
                iconPath: nil,
                filePath: destPath,
                fileSize: fileSize,
                importDate: Date()
            )
            
            ipaFiles.append(newIPA)
            StorageManager.shared.saveIPAs(ipaFiles)
            loadData()
            showAlert(title: "Success", message: "Imported \(appName) successfully")
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
}

extension AppLibraryViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ipaFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath) as? AppCell else {
            return UITableViewCell()
        }
        let ipa = ipaFiles[indexPath.row]
        cell.textLabel?.text = ipa.bundleName
        cell.detailTextLabel?.text = ipa.version + " • " + ipa.bundleIdentifier
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let signingVC = SigningViewController()
        signingVC.ipaFile = ipaFiles[indexPath.row]
        let nav = UINavigationController(rootViewController: signingVC)
        present(nav, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let ipa = ipaFiles[indexPath.row]
            try? FileManager.default.removeItem(atPath: ipa.filePath)
            ipaFiles.remove(at: indexPath.row)
            StorageManager.shared.saveIPAs(ipaFiles)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            emptyStateView.isHidden = !ipaFiles.isEmpty
        }
    }
}

extension AppLibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        importIPA(from: url, originalName: url.lastPathComponent)
    }
}
