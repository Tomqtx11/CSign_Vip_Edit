import UIKit

class FileCell: UITableViewCell {
    
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])
    }
    
    func configure(name: String, path: String, isDirectory: Bool, size: Int64, modDate: Date) {
        titleLabel.text = name
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: modDate)
        
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        subtitleLabel.text = isDirectory ? "\(dateStr)" : "\(sizeStr) · \(dateStr)"
        
        accessoryType = isDirectory ? .disclosureIndicator : .none
        
        let type = FileSystemHelper.shared.fileType(at: path)
        let iconName = FileSystemHelper.shared.iconName(for: type)
        iconView.image = UIImage(systemName: iconName)
        
        switch type {
        case .directory: iconView.tintColor = .systemBlue
        case .ipa: iconView.tintColor = .systemPurple
        case .p12: iconView.tintColor = .systemGreen
        case .image: iconView.tintColor = .systemOrange
        case .text: iconView.tintColor = .systemGray
        default: iconView.tintColor = .label
        }
    }
}
