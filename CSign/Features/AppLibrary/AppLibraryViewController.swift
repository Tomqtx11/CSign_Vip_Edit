import UIKit

class AppLibraryViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var emptyStateView: EmptyStateView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "App Library"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let importMenu = UIMenu(title: "", children: [
            UIAction(title: "Import from Files", image: UIImage(systemName: "folder")) { _ in },
            UIAction(title: "Import from URL", image: UIImage(systemName: "link")) { _ in }
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
        
        // Hide empty state if data exists
        // emptyStateView.isHidden = true
    }
}

extension AppLibraryViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0 // Update with actual data
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath) as? AppCell else {
            return UITableViewCell()
        }
        return cell
    }
}
