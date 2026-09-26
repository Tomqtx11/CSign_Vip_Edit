import UIKit

// MARK: - ProfileCell
class ProfileCell: UITableViewCell {


    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        iv.image = UIImage(systemName: "doc.badge.gearshape.fill", withConfiguration: config)
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let detailLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = .tertiaryLabel
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
        ])
    }

    func configure(with profile: ProvisionProfile) {
        titleLabel.text = profile.name

        subtitleLabel.text = "\(profile.teamName) · \(profile.bundleIdentifier)"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let expiryStr = dateFormatter.string(from: profile.expirationDate)
        if profile.isExpired {
            detailLabel.text = "⛔️ Expired: \(expiryStr)"
            detailLabel.textColor = .systemRed
            iconImageView.tintColor = .systemRed
        } else {
            detailLabel.text = "Expires: \(expiryStr) · \(profile.deviceUDIDs.count) devices"
            detailLabel.textColor = .tertiaryLabel
            iconImageView.tintColor = .systemBlue
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailLabel.textColor = .tertiaryLabel
        iconImageView.tintColor = .systemBlue
    }
}
