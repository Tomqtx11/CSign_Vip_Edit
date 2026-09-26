import UIKit

class EmptyStateView: UIView {
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.isHidden = true
        return button
    }()
    
    private var action: (() -> Void)?
    
    init(iconName: String, title: String, detail: String, buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        super.init(frame: .zero)
        setupView()
        
        iconImageView.image = UIImage(systemName: iconName)
        titleLabel.text = title
        detailLabel.text = detail
        
        if let buttonTitle = buttonTitle {
            actionButton.setTitle(buttonTitle, for: .normal)
            actionButton.isHidden = false
            self.action = buttonAction
            actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            actionButton.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 24),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    @objc private func buttonTapped() {
        action?()
    }
}
