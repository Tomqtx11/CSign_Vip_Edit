import UIKit
import UniformTypeIdentifiers

class FileManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIDocumentPickerDelegate {
    
    private let tableView = UITableView()
    private let searchBar = UISearchBar()
    
    var currentDirectory: String = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "")
    private var allItems: [(name: String, path: String, isDirectory: Bool, size: Int64, modDate: Date)] = []
    private var filteredItems: [(name: String, path: String, isDirectory: Bool, size: Int64, modDate: Date)] = []
    private var currentSort: SortOption = .name
    
    enum SortOption { case name, date, size, type }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        title = (currentDirectory as NSString).lastPathComponent
        view.backgroundColor = .systemBackground
        
        let newFolderBtn = UIBarButtonItem(image: UIImage(systemName: "folder.badge.plus"), style: .plain, target: self, action: #selector(newFolderTapped))
        let importBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importTapped))
        let sortBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: self, action: #selector(sortTapped))
        navigationItem.rightBarButtonItems = [sortBtn, importBtn, newFolderBtn]
        
        searchBar.delegate = self
        searchBar.placeholder = "Search files"
        searchBar.sizeToFit()
        tableView.tableHeaderView = searchBar
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FileCell.self, forCellReuseIdentifier: FileCell.reuseIdentifier)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(loadData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func loadData() {
        allItems = FileSystemHelper.shared.listContents(of: currentDirectory)
        applyFilterAndSort()
        tableView.refreshControl?.endRefreshing()
    }
    
    private func applyFilterAndSort() {
        let searchText = searchBar.text ?? ""
        var items = searchText.isEmpty ? allItems : allItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        items.sort { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            
            switch currentSort {
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date: return a.modDate > b.modDate
            case .size: return a.size > b.size
            case .type: return FileSystemHelper.shared.fileType(at: a.path).rawValue < FileSystemHelper.shared.fileType(at: b.path).rawValue
            }
        }
        
        filteredItems = items
        tableView.reloadData()
    }
    
    // Actions
    @objc private func newFolderTapped() {
        let alert = UIAlertController(title: "New Folder", message: "Enter folder name", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Folder Name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let path = (self.currentDirectory as NSString).appendingPathComponent(name)
            do {
                try FileSystemHelper.shared.createDirectory(at: path)
                self.loadData()
            } catch {
                self.showError(error)
            }
        })
        present(alert, animated: true)
    }
    
    @objc private func importTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func sortTapped() {
        let sheet = UIAlertController(title: "Sort by", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Name", style: .default) { _ in self.currentSort = .name; self.applyFilterAndSort() })
        sheet.addAction(UIAlertAction(title: "Date", style: .default) { _ in self.currentSort = .date; self.applyFilterAndSort() })
        sheet.addAction(UIAlertAction(title: "Size", style: .default) { _ in self.currentSort = .size; self.applyFilterAndSort() })
        sheet.addAction(UIAlertAction(title: "Type", style: .default) { _ in self.currentSort = .type; self.applyFilterAndSort() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
    
    // TableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuseIdentifier, for: indexPath) as! FileCell
        let item = filteredItems[indexPath.row]
        cell.configure(name: item.name, path: item.path, isDirectory: item.isDirectory, size: item.size, modDate: item.modDate)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        if item.isDirectory {
            let vc = FileManagerViewController()
            vc.currentDirectory = item.path
            navigationController?.pushViewController(vc, animated: true)
        } else {
            let vc = FilePreviewViewController()
            vc.filePath = item.path
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = filteredItems[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { return }
            do {
                try FileSystemHelper.shared.deleteItem(at: item.path)
                self.loadData()
                completion(true)
            } catch {
                self.showError(error)
                completion(false)
            }
        }
        
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            let activity = UIActivityViewController(activityItems: [URL(fileURLWithPath: item.path)], applicationActivities: nil)
            self?.present(activity, animated: true)
            completion(true)
        }
        shareAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, shareAction])
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let item = filteredItems[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copyAction = UIAction(title: "Copy Path", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = item.path
            }
            return UIMenu(title: "", children: [copyAction])
        }
    }
    
    // SearchBar
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilterAndSort()
    }
    
    // UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let dest = (currentDirectory as NSString).appendingPathComponent(url.lastPathComponent)
        do {
            try FileSystemHelper.shared.copyItem(from: url.path, to: dest)
            loadData()
        } catch {
            showError(error)
        }
    }
}
