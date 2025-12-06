import UIKit
import Social
import UniformTypeIdentifiers
import Security

// MARK: - Keychain Helper for Share Extension
private struct ShareKeychainHelper {
    static let accessGroup = "group.com.hongkeilung.radar"
    
    static func readAccessToken() -> String? {
        // Try with App Groups first
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        // Fallback: Try without App Groups
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true
        ]
        
        result = nil
        status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        return nil
    }
}

// MARK: - API Config
private struct ShareAPIConfig {
    static let baseURL = "https://radar-production-0277.up.railway.app"
}

// MARK: - Response Models
struct PlaceResponse: Codable {
    let id: Int
    let name: String
    let address: String?
    let district: String?
    let lat: Double
    let lng: Double
    let category: String
    let emoji: String
    let photo_url: String?
    let rating: Double?
    let is_visited: Bool
    let is_favorite: Bool
    let tags: [String]?
    let source_url: String?
    let created_at: String
}

struct GooglePlaceResult: Codable {
    let place_id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let rating: Double?
    let photoUrl: String?
}

struct GoogleSearchResponse: Codable {
    let results: [GooglePlaceResult]
}

struct ErrorResponse: Codable {
    let detail: String
}

// MARK: - Share View Controller
class ShareViewController: UIViewController {
    
    private var sharedURL: String?
    private var savedPlace: PlaceResponse?
    private var searchResults: [GooglePlaceResult] = []
    
    // UI Elements - Loading State
    private let loadingContainerView = UIView()
    private let loadingEmojiLabel = UILabel()
    private let loadingStatusLabel = UILabel()
    
    // UI Elements - Success State (Corner-style)
    private let successContainerView = UIView()
    private var successBottomConstraint: NSLayoutConstraint!
    private let headerLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let placeCardView = UIView()
    private let placeImageView = UIImageView()
    private let placeNameLabel = UILabel()
    private let placeAddressLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    private let savedByYouView = UIView()
    private let savedIconLabel = UILabel()
    private let savedLabel = UILabel()
    private let searchTextField = UITextField()
    private let addButton = UIButton(type: .system)
    
    // UI Elements - Search Mode
    private let searchContainerView = UIView()
    private let searchBarView = UIView()
    private let searchIconImageView = UIImageView()
    private let searchInputField = UITextField()
    private let searchCloseButton = UIButton(type: .system)
    private let searchResultsTableView = UITableView()
    
    // UI Elements - Error State
    private let errorContainerView = UIView()
    private let errorIconLabel = UILabel()
    private let errorMessageLabel = UILabel()
    private let errorCloseButton = UIButton(type: .system)
    
    private enum State {
        case loading
        case success(PlaceResponse)
        case searching
        case error(String)
    }
    
    private var currentState: State = .loading {
        didSet {
            updateUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedURL()
        
        // Keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        setupLoadingUI()
        setupSuccessUI()
        setupSearchUI()
        setupErrorUI()
        
        // Show loading by default
        loadingContainerView.isHidden = false
        successContainerView.isHidden = true
        searchContainerView.isHidden = true
        errorContainerView.isHidden = true
    }
    
    private func setupLoadingUI() {
        // Container - White background
        loadingContainerView.backgroundColor = .white
        loadingContainerView.layer.cornerRadius = 24
        loadingContainerView.layer.shadowColor = UIColor.black.cgColor
        loadingContainerView.layer.shadowOpacity = 0.1
        loadingContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        loadingContainerView.layer.shadowRadius = 12
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingContainerView)
        
        // Emoji
        loadingEmojiLabel.text = "🌍"
        loadingEmojiLabel.font = .systemFont(ofSize: 60)
        loadingEmojiLabel.textAlignment = .center
        loadingEmojiLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(loadingEmojiLabel)
        
        // Status label - Black text
        loadingStatusLabel.text = "finding your next hangout spot..."
        loadingStatusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        loadingStatusLabel.textAlignment = .center
        loadingStatusLabel.textColor = .black
        loadingStatusLabel.numberOfLines = 0
        loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(loadingStatusLabel)
        
        NSLayoutConstraint.activate([
            loadingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            loadingContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            loadingEmojiLabel.topAnchor.constraint(equalTo: loadingContainerView.topAnchor, constant: 40),
            loadingEmojiLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            
            loadingStatusLabel.topAnchor.constraint(equalTo: loadingEmojiLabel.bottomAnchor, constant: 20),
            loadingStatusLabel.leadingAnchor.constraint(equalTo: loadingContainerView.leadingAnchor, constant: 24),
            loadingStatusLabel.trailingAnchor.constraint(equalTo: loadingContainerView.trailingAnchor, constant: -24),
            loadingStatusLabel.bottomAnchor.constraint(equalTo: loadingContainerView.bottomAnchor, constant: -40)
        ])
    }
    
    private func setupSuccessUI() {
        // Container - White background, bottom sheet style
        successContainerView.backgroundColor = .white
        successContainerView.layer.cornerRadius = 24
        successContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        successContainerView.layer.shadowColor = UIColor.black.cgColor
        successContainerView.layer.shadowOpacity = 0.1
        successContainerView.layer.shadowOffset = CGSize(width: 0, height: -4)
        successContainerView.layer.shadowRadius = 12
        successContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(successContainerView)
        
        // Header label
        headerLabel.text = "add to radar"
        headerLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = .black
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(headerLabel)
        
        // Close button (X)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.black, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .light)
        closeButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(closeButton)
        
        // Place card
        placeCardView.backgroundColor = .white
        placeCardView.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(placeCardView)
        
        // Place image (Google photo)
        placeImageView.contentMode = .scaleAspectFill
        placeImageView.clipsToBounds = true
        placeImageView.layer.cornerRadius = 8
        placeImageView.backgroundColor = .systemGray6
        placeImageView.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeImageView)
        
        // Place name
        placeNameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        placeNameLabel.textColor = .black
        placeNameLabel.numberOfLines = 2
        placeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeNameLabel)
        
        // Place address
        placeAddressLabel.font = .systemFont(ofSize: 14)
        placeAddressLabel.textColor = .systemGray
        placeAddressLabel.numberOfLines = 2
        placeAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeAddressLabel)
        
        // Checkmark
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = .black
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(checkmarkImageView)
        
        // "saved by you" view (icon + text)
        savedByYouView.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(savedByYouView)
        
        savedIconLabel.text = "🍜" // Placeholder, will be set dynamically
        savedIconLabel.font = .systemFont(ofSize: 12)
        savedIconLabel.translatesAutoresizingMaskIntoConstraints = false
        savedByYouView.addSubview(savedIconLabel)
        
        savedLabel.text = "saved by you"
        savedLabel.font = .systemFont(ofSize: 12)
        savedLabel.textColor = .systemGray2
        savedLabel.translatesAutoresizingMaskIntoConstraints = false
        savedByYouView.addSubview(savedIconLabel)
        savedByYouView.addSubview(savedLabel)
        
        // Search text field - Light gray background
        searchTextField.placeholder = "find a different place"
        searchTextField.font = .systemFont(ofSize: 16)
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = UIColor.systemGray6
        searchTextField.layer.cornerRadius = 12
        searchTextField.delegate = self
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(searchTextField)
        
        // Add magnifying glass icon
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = .systemGray
        searchIcon.contentMode = .scaleAspectFit
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.addSubview(searchIcon)
        
        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchTextField.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchTextField.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        searchTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 48))
        searchTextField.leftViewMode = .always
        
        // Add button
        addButton.setTitle("add 1 place", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        addButton.backgroundColor = .black
        addButton.layer.cornerRadius = 28
        addButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(addButton)
        
        successBottomConstraint = successContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            successContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            successContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            successBottomConstraint,
            
            headerLabel.topAnchor.constraint(equalTo: successContainerView.topAnchor, constant: 24),
            headerLabel.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            
            closeButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            placeCardView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 24),
            placeCardView.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            placeCardView.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            placeCardView.heightAnchor.constraint(equalToConstant: 90),
            
            placeImageView.leadingAnchor.constraint(equalTo: placeCardView.leadingAnchor),
            placeImageView.centerYAnchor.constraint(equalTo: placeCardView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 60),
            placeImageView.heightAnchor.constraint(equalToConstant: 60),
            
            placeNameLabel.topAnchor.constraint(equalTo: placeCardView.topAnchor, constant: 8),
            placeNameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            placeNameLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            placeAddressLabel.topAnchor.constraint(equalTo: placeNameLabel.bottomAnchor, constant: 4),
            placeAddressLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            placeAddressLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: placeCardView.trailingAnchor),
            checkmarkImageView.topAnchor.constraint(equalTo: placeCardView.topAnchor, constant: 8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            
            savedByYouView.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 4),
            savedByYouView.trailingAnchor.constraint(equalTo: placeCardView.trailingAnchor),
            savedByYouView.heightAnchor.constraint(equalToConstant: 20),
            
            savedIconLabel.leadingAnchor.constraint(equalTo: savedByYouView.leadingAnchor),
            savedIconLabel.centerYAnchor.constraint(equalTo: savedByYouView.centerYAnchor),
            
            savedLabel.leadingAnchor.constraint(equalTo: savedIconLabel.trailingAnchor, constant: 4),
            savedLabel.trailingAnchor.constraint(equalTo: savedByYouView.trailingAnchor),
            savedLabel.centerYAnchor.constraint(equalTo: savedByYouView.centerYAnchor),
            
            searchTextField.topAnchor.constraint(equalTo: placeCardView.bottomAnchor, constant: 24),
            searchTextField.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            searchTextField.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            searchTextField.heightAnchor.constraint(equalToConstant: 48),
            
            addButton.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 24),
            addButton.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            addButton.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            addButton.bottomAnchor.constraint(equalTo: successContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupSearchUI() {
        // Full screen search container
        searchContainerView.backgroundColor = .white
        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainerView)
        
        // Search bar at top
        searchBarView.backgroundColor = .black
        searchBarView.layer.cornerRadius = 24
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchBarView)
        
        // Search icon
        searchIconImageView.image = UIImage(systemName: "magnifyingglass")
        searchIconImageView.tintColor = .white
        searchIconImageView.contentMode = .scaleAspectFit
        searchIconImageView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.addSubview(searchIconImageView)
        
        // Search input field
        searchInputField.font = .systemFont(ofSize: 18)
        searchInputField.textColor = .white
        searchInputField.attributedPlaceholder = NSAttributedString(
            string: "bar",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        searchInputField.borderStyle = .none
        searchInputField.backgroundColor = .clear
        searchInputField.returnKeyType = .search
        searchInputField.autocorrectionType = .no
        searchInputField.delegate = self
        searchInputField.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        searchInputField.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.addSubview(searchInputField)
        
        // Close button
        searchCloseButton.setTitle("✕", for: .normal)
        searchCloseButton.setTitleColor(.black, for: .normal)
        searchCloseButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .light)
        searchCloseButton.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
        searchCloseButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchCloseButton)
        
        // Results table
        searchResultsTableView.backgroundColor = .white
        searchResultsTableView.separatorStyle = .none
        searchResultsTableView.delegate = self
        searchResultsTableView.dataSource = self
        searchResultsTableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        searchResultsTableView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchResultsTableView)
        
        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            searchBarView.topAnchor.constraint(equalTo: searchContainerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchBarView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 24),
            searchBarView.trailingAnchor.constraint(equalTo: searchCloseButton.leadingAnchor, constant: -12),
            searchBarView.heightAnchor.constraint(equalToConstant: 48),
            
            searchIconImageView.leadingAnchor.constraint(equalTo: searchBarView.leadingAnchor, constant: 16),
            searchIconImageView.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            searchIconImageView.widthAnchor.constraint(equalToConstant: 20),
            searchIconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            searchInputField.leadingAnchor.constraint(equalTo: searchIconImageView.trailingAnchor, constant: 12),
            searchInputField.trailingAnchor.constraint(equalTo: searchBarView.trailingAnchor, constant: -16),
            searchInputField.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            
            searchCloseButton.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            searchCloseButton.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -24),
            searchCloseButton.widthAnchor.constraint(equalToConstant: 32),
            searchCloseButton.heightAnchor.constraint(equalToConstant: 32),
            
            searchResultsTableView.topAnchor.constraint(equalTo: searchBarView.bottomAnchor, constant: 16),
            searchResultsTableView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor),
            searchResultsTableView.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor),
            searchResultsTableView.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor)
        ])
    }
    
    private func setupErrorUI() {
        // Container - White background
        errorContainerView.backgroundColor = .white
        errorContainerView.layer.cornerRadius = 24
        errorContainerView.layer.shadowColor = UIColor.black.cgColor
        errorContainerView.layer.shadowOpacity = 0.1
        errorContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        errorContainerView.layer.shadowRadius = 12
        errorContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorContainerView)
        
        // Error icon
        errorIconLabel.text = "⚠️"
        errorIconLabel.font = .systemFont(ofSize: 60)
        errorIconLabel.textAlignment = .center
        errorIconLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorIconLabel)
        
        // Error message
        errorMessageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorMessageLabel.textAlignment = .center
        errorMessageLabel.textColor = .systemRed
        errorMessageLabel.numberOfLines = 0
        errorMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorMessageLabel)
        
        // Close button
        errorCloseButton.setTitle("Done", for: .normal)
        errorCloseButton.setTitleColor(.white, for: .normal)
        errorCloseButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        errorCloseButton.backgroundColor = .black
        errorCloseButton.layer.cornerRadius = 12
        errorCloseButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        errorCloseButton.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorCloseButton)
        
        NSLayoutConstraint.activate([
            errorContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            errorIconLabel.topAnchor.constraint(equalTo: errorContainerView.topAnchor, constant: 40),
            errorIconLabel.centerXAnchor.constraint(equalTo: errorContainerView.centerXAnchor),
            
            errorMessageLabel.topAnchor.constraint(equalTo: errorIconLabel.bottomAnchor, constant: 20),
            errorMessageLabel.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 24),
            errorMessageLabel.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -24),
            
            errorCloseButton.topAnchor.constraint(equalTo: errorMessageLabel.bottomAnchor, constant: 24),
            errorCloseButton.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 24),
            errorCloseButton.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -24),
            errorCloseButton.heightAnchor.constraint(equalToConstant: 50),
            errorCloseButton.bottomAnchor.constraint(equalTo: errorContainerView.bottomAnchor, constant: -32)
        ])
    }
    
    // MARK: - Extract Shared URL
    private func extractSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            currentState = .error("No content shared")
            return
        }
        
        // Check for URL
        if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self?.sharedURL = url.absoluteString
                        self?.importPlace()
                    } else {
                        self?.currentState = .error("Could not read URL")
                    }
                }
            }
        } else {
            currentState = .error("Please share an Instagram post")
        }
    }
    
    // MARK: - Import Place from Backend
    private func importPlace() {
        guard let urlString = sharedURL else {
            currentState = .error("No URL found")
            return
        }
        
        guard let token = ShareKeychainHelper.readAccessToken() else {
            currentState = .error("Please log in to Radar first")
            return
        }
        
        guard let url = URL(string: "\(ShareAPIConfig.baseURL)/import-url") else {
            currentState = .error("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = ["url": urlString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.currentState = .error("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.currentState = .error("No response from server")
                    return
                }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        self?.currentState = .error(errorResponse.detail)
                    } else {
                        self?.currentState = .error("Server error (\(httpResponse.statusCode))")
                    }
                    return
                }
                
                // Parse success response
                do {
                    let place = try JSONDecoder().decode(PlaceResponse.self, from: data)
                    self?.savedPlace = place
                    self?.currentState = .success(place)
                } catch {
                    self?.currentState = .error("Failed to parse response")
                }
            }
        }.resume()
    }
    
    // MARK: - Search Google Places
    @objc private func searchTextDidChange() {
        let query = searchInputField.text ?? ""
        if query.count > 2 {
            searchGooglePlaces(query: query)
        } else {
            searchResults = []
            searchResultsTableView.reloadData()
        }
    }
    
    private func searchGooglePlaces(query: String) {
        guard let token = ShareKeychainHelper.readAccessToken() else { return }
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        guard let url = URL(string: "\(ShareAPIConfig.baseURL)/search/autocomplete?query=\(encodedQuery)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data else { return }
            
            do {
                let searchResponse = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.searchResults = searchResponse.results
                    self?.searchResultsTableView.reloadData()
                }
            } catch {
                print("Search error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Update UI
    private func updateUI() {
        switch currentState {
        case .loading:
            loadingContainerView.isHidden = false
            successContainerView.isHidden = true
            searchContainerView.isHidden = true
            errorContainerView.isHidden = true
            startPulseAnimation()
            
        case .success(let place):
            stopPulseAnimation()
            loadingContainerView.isHidden = true
            successContainerView.isHidden = false
            searchContainerView.isHidden = true
            errorContainerView.isHidden = true
            
            // Update place info
            placeNameLabel.text = place.name
            placeAddressLabel.text = place.address ?? "\(place.district ?? ""), Hong Kong"
            savedIconLabel.text = place.emoji
            
            // Load Google photo
            if let photoURLString = place.photo_url,
               let photoURL = URL(string: photoURLString) {
                loadImage(from: photoURL)
            } else {
                placeImageView.backgroundColor = .systemGray6
            }
            
            // Animate in from bottom
            successContainerView.transform = CGAffineTransform(translationX: 0, y: 400)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.successContainerView.transform = .identity
            }
            
        case .searching:
            loadingContainerView.isHidden = true
            successContainerView.isHidden = true
            searchContainerView.isHidden = false
            errorContainerView.isHidden = true
            searchInputField.becomeFirstResponder()
            
        case .error(let message):
            stopPulseAnimation()
            loadingContainerView.isHidden = true
            successContainerView.isHidden = true
            searchContainerView.isHidden = true
            errorContainerView.isHidden = false
            errorMessageLabel.text = message
        }
    }
    
    // MARK: - Image Loading
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.placeImageView.image = image
            }
        }.resume()
    }
    
    // MARK: - Animations
    private func startPulseAnimation() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.loadingEmojiLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    private func stopPulseAnimation() {
        loadingEmojiLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) {
            self.loadingEmojiLabel.transform = .identity
        }
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        successBottomConstraint.constant = -keyboardFrame.height
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        successBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func closeSearch() {
        searchInputField.text = ""
        searchResults = []
        currentState = .success(savedPlace!)
    }
}

// MARK: - UITextFieldDelegate
extension ShareViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == searchTextField {
            // Expand to full screen search
            currentState = .searching
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDelegate & DataSource
extension ShareViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        cell.configure(with: searchResults[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // TODO: Add place to radar
        closeSearch()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

// MARK: - Search Result Cell
class SearchResultCell: UITableViewCell {
    private let placeImageView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let checkboxView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        placeImageView.contentMode = .scaleAspectFill
        placeImageView.clipsToBounds = true
        placeImageView.layer.cornerRadius = 8
        placeImageView.backgroundColor = .systemGray6
        placeImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeImageView)
        
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .black
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .systemGray
        addressLabel.numberOfLines = 2
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addressLabel)
        
        checkboxView.layer.borderWidth = 2
        checkboxView.layer.borderColor = UIColor.systemGray4.cgColor
        checkboxView.layer.cornerRadius = 15
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkboxView)
        
        NSLayoutConstraint.activate([
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 60),
            placeImageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            checkboxView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            checkboxView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxView.widthAnchor.constraint(equalToConstant: 30),
            checkboxView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(with result: GooglePlaceResult) {
        nameLabel.text = result.name
        addressLabel.text = result.address
        
        if let photoURLString = result.photoUrl, let photoURL = URL(string: photoURLString) {
            URLSession.shared.dataTask(with: photoURL) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.placeImageView.image = image
                }
            }.resume()
        }
    }
}
