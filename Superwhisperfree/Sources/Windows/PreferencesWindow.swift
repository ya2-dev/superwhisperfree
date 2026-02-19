import Cocoa

// MARK: - Preferences Tab Enum

enum PreferencesTab: String, CaseIterable {
    case general = "General"
    case models = "Models"
    case language = "Language"
    
    var icon: NSImage? {
        switch self {
        case .general: return NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        case .models: return NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        case .language: return NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }
    }
}

// MARK: - Sidebar Delegate Protocol

protocol PreferencesSidebarDelegate: AnyObject {
    func sidebarDidSelectTab(_ tab: PreferencesTab)
}

// MARK: - Preferences Window Controller

final class PreferencesWindowController: NSWindowController {
    
    private var splitViewController: NSSplitViewController!
    private var sidebarViewController: PreferencesSidebarViewController!
    private var prefsContentViewController: PreferencesContentViewController!
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.swBackground
        window.minSize = NSSize(width: 700, height: 500)
        
        self.init(window: window)
        
        setupSplitView()
    }
    
    private func setupSplitView() {
        splitViewController = NSSplitViewController()
        
        sidebarViewController = PreferencesSidebarViewController()
        sidebarViewController.delegate = self
        
        prefsContentViewController = PreferencesContentViewController()
        
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 200
        sidebarItem.canCollapse = false
        
        let contentItem = NSSplitViewItem(viewController: prefsContentViewController)
        contentItem.minimumThickness = 400
        
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
        
        window?.contentViewController = splitViewController
        
        sidebarViewController.selectTab(.general)
    }
}

// MARK: - PreferencesSidebarDelegate

extension PreferencesWindowController: PreferencesSidebarDelegate {
    func sidebarDidSelectTab(_ tab: PreferencesTab) {
        prefsContentViewController.showContent(for: tab)
    }
}

// MARK: - Sidebar View Controller

final class PreferencesSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    weak var delegate: PreferencesSidebarDelegate?
    
    private var tableView: NSTableView!
    private let tabs = PreferencesTab.allCases
    
    override func loadView() {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.swSurface.cgColor
        self.view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    private func setupTableView() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TabColumn"))
        column.width = 180
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: DesignTokens.Spacing.xl + 28),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.sm),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
    }
    
    func selectTab(_ tab: PreferencesTab) {
        if let index = tabs.firstIndex(of: tab) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            delegate?.sidebarDidSelectTab(tab)
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tabs.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tab = tabs[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("TabCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? PreferencesSidebarCellView
        
        if cellView == nil {
            cellView = PreferencesSidebarCellView()
            cellView?.identifier = cellIdentifier
        }
        
        cellView?.configure(with: tab)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < tabs.count else { return }
        delegate?.sidebarDidSelectTab(tabs[selectedRow])
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PreferencesSidebarRowView()
    }
}

// MARK: - Sidebar Cell View

final class PreferencesSidebarCellView: NSTableCellView {
    
    private var iconImageView: NSImageView!
    private var titleLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        iconImageView = NSImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentTintColor = NSColor.swText
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconImageView)
        
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignTokens.Typography.body(size: 13)
        titleLabel.textColor = NSColor.swText
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: DesignTokens.Spacing.sm),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm)
        ])
    }
    
    func configure(with tab: PreferencesTab) {
        iconImageView.image = tab.icon
        titleLabel.stringValue = tab.rawValue
    }
}

// MARK: - Sidebar Row View

final class PreferencesSidebarRowView: NSTableRowView {
    
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 4, dy: 2)
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: DesignTokens.CornerRadius.medium, yRadius: DesignTokens.CornerRadius.medium)
            NSColor.swSurfaceHover.setFill()
            selectionPath.fill()
        }
    }
    
    override var isEmphasized: Bool {
        get { return true }
        set {}
    }
}

// MARK: - Content View Controller

final class PreferencesContentViewController: NSViewController {
    
    private var currentTab: PreferencesTab = .general
    private var currentContentView: NSView?
    
    override func loadView() {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.swBackground.cgColor
        self.view = containerView
    }
    
    func showContent(for tab: PreferencesTab) {
        currentTab = tab
        
        currentContentView?.removeFromSuperview()
        
        let contentView = createContentView(for: tab)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        currentContentView = contentView
    }
    
    private func createContentView(for tab: PreferencesTab) -> NSView {
        switch tab {
        case .general:
            return GeneralPreferencesView()
        case .models:
            return ModelsPreferencesView()
        case .language:
            return LanguagePreferencesView()
        }
    }
}
