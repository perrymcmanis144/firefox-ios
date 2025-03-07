// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import Storage
import UIKit

class JumpBackInViewModel: FeatureFlaggable {

    struct UX {
        static let jumpBackInCellHeight: CGFloat = 112
        static let syncedTabCellPortraitCompactHeight: CGFloat = 182
        static let syncedTabCellHeight: CGFloat = 232
        static let maxDisplayedSyncedTabs: Int = 1
        static let maxJumpBackInItemsPerGroup: Int = 2
    }

    // MARK: - Properties
    var headerButtonAction: ((UIButton) -> Void)?
    var onTapGroup: ((Tab) -> Void)?
    var syncedTabsShowAllAction: (() -> Void)?
    var openSyncedTabAction: ((URL) -> Void)?
    var prepareContextualHint: ((SyncedTabCell) -> Void)?

    weak var browserBarViewDelegate: BrowserBarViewDelegate?
    weak var delegate: HomepageDataModelDelegate?

    var jumpBackInList = JumpBackInList(group: nil, tabs: [Tab]())
    var mostRecentSyncedTab: JumpBackInSyncedTab?

    private lazy var siteImageHelper = SiteImageHelper(profile: profile)
    private var jumpBackInDataAdaptor: JumpBackInDataAdaptor

    var isZeroSearch: Bool
    var theme: Theme
    private let profile: Profile
    private var isPrivate: Bool
    private var hasSentJumpBackInTileEvent = false
    private var hasSentSyncedTabTileEvent = false
    private let tabManager: TabManagerProtocol
    private var wallpaperManager: WallpaperManager
    var sectionLayout: JumpBackInSectionLayout = .compactJumpBackIn // We use the compact layout as default

    init(
        isZeroSearch: Bool = false,
        profile: Profile,
        isPrivate: Bool,
        theme: Theme,
        tabManager: TabManagerProtocol,
        adaptor: JumpBackInDataAdaptor,
        wallpaperManager: WallpaperManager
    ) {
        self.profile = profile
        self.isZeroSearch = isZeroSearch
        self.isPrivate = isPrivate
        self.theme = theme
        self.tabManager = tabManager
        self.jumpBackInDataAdaptor = adaptor
        self.wallpaperManager = wallpaperManager
    }

    func switchTo(group: ASGroup<Tab>) {
        guard let delegate = browserBarViewDelegate else { return }

        if delegate.inOverlayMode {
            delegate.leaveOverlayMode(didCancel: false)
        }

        guard let firstTab = group.groupedItems.first else { return }

        onTapGroup?(firstTab)

        TelemetryWrapper.recordEvent(
            category: .action,
            method: .tap,
            object: .firefoxHomepage,
            value: .jumpBackInSectionGroupOpened,
            extras: TelemetryWrapper.getOriginExtras(isZeroSearch: isZeroSearch)
        )
    }

    func switchTo(tab: Tab) {
        guard let delegate = browserBarViewDelegate else { return }

        if delegate.inOverlayMode {
            delegate.leaveOverlayMode(didCancel: false)
        }

        tabManager.selectTab(tab, previous: nil)
        TelemetryWrapper.recordEvent(
            category: .action,
            method: .tap,
            object: .firefoxHomepage,
            value: .jumpBackInSectionTabOpened,
            extras: TelemetryWrapper.getOriginExtras(isZeroSearch: isZeroSearch)
        )
    }

    func sendImpressionTelemetry() {
        if !hasSentJumpBackInTileEvent, hasJumpBackIn {
            TelemetryWrapper.recordEvent(category: .action,
                                         method: .view,
                                         object: .jumpBackInTileImpressions,
                                         value: nil,
                                         extras: nil)
            hasSentJumpBackInTileEvent = true
        }

        if !hasSentSyncedTabTileEvent, hasSyncedTab {
            TelemetryWrapper.recordEvent(category: .action,
                                         method: .view,
                                         object: .syncedTabTileImpressions,
                                         value: nil,
                                         extras: nil)
            hasSentSyncedTabTileEvent = true
        }
    }

    private func updateSectionLayout(for traitCollection: UITraitCollection,
                                     isPortrait: Bool = UIWindow.isPortrait,
                                     device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) {
        let isPhoneInLandscape = device == .phone && !isPortrait
        let isPadInPortrait = device == .pad && isPortrait
        let isPadInLandscapeTwoThirdSplit = isPadInLandscapeSplit(split: 2/3, isPortrait: isPortrait, device: device)
        let isPadInLandscapeHalfSplit = isPadInLandscapeSplit(split: 1/2, isPortrait: isPortrait, device: device)

        if hasSyncedTab, traitCollection.horizontalSizeClass == .compact, !isPhoneInLandscape {
            if hasJumpBackIn {
                sectionLayout = .compactJumpBackInAndSyncedTab
            } else {
                sectionLayout = .compactSyncedTab
            }
        } else if traitCollection.horizontalSizeClass == .compact, !isPhoneInLandscape {
            sectionLayout = .compactJumpBackIn
        } else if isPadInPortrait || isPhoneInLandscape || isPadInLandscapeHalfSplit || isPadInLandscapeTwoThirdSplit {
            sectionLayout = hasSyncedTab ? .mediumWithSyncedTab : .medium
        } else {
            sectionLayout = hasSyncedTab ? .regularWithSyncedTab : .regular
        }
    }

    private var hasSyncedTab: Bool {
        return jumpBackInDataAdaptor.hasSyncedTabFeatureEnabled && mostRecentSyncedTab != nil
    }

    private var hasJumpBackIn: Bool {
        return jumpBackInList.itemsToDisplay > 0
    }

    private var isMultitasking: Bool {
        guard let window = UIWindow.keyWindow else { return false }

        return window.frame.width != window.screen.bounds.width && window.frame.width != window.screen.bounds.height
    }

    private func isPadInLandscapeSplit(split: CGFloat,
                                       isPortrait: Bool = UIWindow.isPortrait,
                                       device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> Bool {
        guard device == .pad,
              !isPortrait,
              isMultitasking,
              let window = UIWindow.keyWindow
        else { return false }

        let splitScreenWidth = window.screen.bounds.width * split
        return window.frame.width >= splitScreenWidth * 0.9 && window.frame.width <= splitScreenWidth * 1.1
    }
}

// MARK: - Private: Configure UI
private extension JumpBackInViewModel {

    func configureJumpBackInCellForGroups(group: ASGroup<Tab>, cell: JumpBackInCell, indexPath: IndexPath) {
        let firstGroupItem = group.groupedItems.first
        let site = Site(url: firstGroupItem?.lastKnownUrl?.absoluteString ?? "", title: firstGroupItem?.lastTitle ?? "")

        let descriptionText = String.localizedStringWithFormat(.FirefoxHomepage.JumpBackIn.GroupSiteCount, group.groupedItems.count)
        let faviconImage = UIImage(imageLiteralResourceName: ImageIdentifiers.stackedTabsIcon).withRenderingMode(.alwaysTemplate)
        let cellViewModel = JumpBackInCellViewModel(titleText: group.searchTerm.localizedCapitalized,
                                                    descriptionText: descriptionText,
                                                    favIconImage: faviconImage,
                                                    heroImage: jumpBackInDataAdaptor.getHeroImage(forSite: site))
        cell.configure(viewModel: cellViewModel, theme: theme)
    }

    func configureJumpBackInCellForTab(item: Tab, cell: JumpBackInCell, indexPath: IndexPath) {
        let itemURL = item.lastKnownUrl?.absoluteString ?? ""
        let site = Site(url: itemURL, title: item.displayTitle)
        let descriptionText = site.tileURL.shortDisplayString.capitalized

        let cellViewModel = JumpBackInCellViewModel(titleText: site.title,
                                                    descriptionText: descriptionText,
                                                    favIconImage: jumpBackInDataAdaptor.getFaviconImage(forSite: site),
                                                    heroImage: jumpBackInDataAdaptor.getHeroImage(forSite: site))
        cell.configure(viewModel: cellViewModel, theme: theme)
    }

    func configureSyncedTabCellForTab(item: JumpBackInSyncedTab, cell: SyncedTabCell, indexPath: IndexPath) {
        let itemURL = item.tab.URL.absoluteString
        let site = Site(url: itemURL, title: item.tab.title)
        let descriptionText = item.client.name
        let image = UIImage(named: ImageIdentifiers.syncedDevicesIcon)

        let cellViewModel = SyncedTabCellViewModel(
            profile: profile,
            titleText: site.title,
            descriptionText: descriptionText,
            url: item.tab.URL,
            syncedDeviceImage: image,
            heroImage: jumpBackInDataAdaptor.getHeroImage(forSite: site),
            fallbackFaviconImage: jumpBackInDataAdaptor.getFaviconImage(forSite: site)
        )

        cell.configure(
            viewModel: cellViewModel,
            theme: theme,
            onTapShowAllAction: syncedTabsShowAllAction,
            onOpenSyncedTabAction: openSyncedTabAction
        )
    }

    private func defaultSection(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let groupWidth = sectionLayout.widthDimension

        // Items
        let syncedTabItemSize = NSCollectionLayoutSize(
            widthDimension: groupWidth,
            heightDimension: .estimated(UX.syncedTabCellHeight))
        let syncedTabItem = NSCollectionLayoutItem(layoutSize: syncedTabItemSize)

        let jumpBackInItemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(UX.jumpBackInCellHeight))
        let jumpBackInItem = NSCollectionLayoutItem(layoutSize: jumpBackInItemSize)

        // Nested Group (Jump Back In)
        let nestedGroupSize = NSCollectionLayoutSize(widthDimension: groupWidth,
                                                     heightDimension: .estimated(UX.syncedTabCellHeight))
        let nestedGroup = NSCollectionLayoutGroup.vertical(layoutSize: nestedGroupSize,
                                                           subitems: [jumpBackInItem, jumpBackInItem])
        nestedGroup.interItemSpacing = JumpBackInCell.UX.interItemSpacing

        // Main Group
        let mainGroupHeight: CGFloat = UX.syncedTabCellHeight
        let mainGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                   heightDimension: .estimated(mainGroupHeight))

        let maxJumpBackInPerGroup = UX.maxJumpBackInItemsPerGroup
        let jumpBackInItems = jumpBackInList.itemsToDisplay
        let numberOfGroups = ceil(Double(jumpBackInItems) / Double(maxJumpBackInPerGroup))
        var subItems: [NSCollectionLayoutItem] = Array(repeating: nestedGroup, count: Int(numberOfGroups))

        if hasSyncedTab {
            subItems.insert(syncedTabItem, at: 0)
        }
        let mainGroup = NSCollectionLayoutGroup.horizontal(layoutSize: mainGroupSize,
                                                           subitems: subItems)
        mainGroup.interItemSpacing = JumpBackInCell.UX.interItemSpacing

        return NSCollectionLayoutSection(group: mainGroup)
    }

    // compact layout with synced tab
    private func sectionWithSyncedTabCompact(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        // Items
        let syncedTabCellHeight = UX.syncedTabCellPortraitCompactHeight
        let syncedTabItemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(syncedTabCellHeight))
        let syncedTabItem = NSCollectionLayoutItem(layoutSize: syncedTabItemSize)

        let jumpBackInItemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(UX.jumpBackInCellHeight))
        let jumpBackInItem = NSCollectionLayoutItem(layoutSize: jumpBackInItemSize)

        // Main Group
        let groupWidth = sectionLayout.widthDimension
        let groupHeight: CGFloat = syncedTabCellHeight + UX.jumpBackInCellHeight
            + JumpBackInCell.UX.interItemSpacing.spacing
        let groupSize = NSCollectionLayoutSize(widthDimension: groupWidth,
                                               heightDimension: .estimated(groupHeight))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize,
                                                     subitems: [jumpBackInItem, syncedTabItem])
        group.interItemSpacing = JumpBackInCell.UX.interItemSpacing

        return NSCollectionLayoutSection(group: group)
    }
}

// MARK: HomeViewModelProtocol
extension JumpBackInViewModel: HomepageViewModelProtocol {

    var sectionType: HomepageSectionType {
        return .jumpBackIn
    }

    var headerViewModel: LabelButtonHeaderViewModel {
        var textColor: UIColor?
        if let wallpaperVersion: WallpaperVersion = featureFlags.getCustomState(for: .wallpaperVersion),
           wallpaperVersion == .v1 {
            textColor = wallpaperManager.currentWallpaper.textColor
        }

        return LabelButtonHeaderViewModel(
            title: HomepageSectionType.jumpBackIn.title,
            titleA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.SectionTitles.jumpBackIn,
            isButtonHidden: false,
            buttonTitle: .RecentlySavedShowAllText,
            buttonAction: headerButtonAction,
            buttonA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.MoreButtons.jumpBackIn,
            textColor: textColor)
    }

    var isEnabled: Bool {
        guard featureFlags.isFeatureEnabled(.jumpBackIn, checking: .buildAndUser) else { return false }

        return !isPrivate
    }

    func numberOfItemsInSection() -> Int {
        return jumpBackInList.itemsToDisplay + (hasSyncedTab ? UX.maxDisplayedSyncedTabs : 0)
    }

    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        var section: NSCollectionLayoutSection
        switch sectionLayout {
        case .compactSyncedTab, .compactJumpBackInAndSyncedTab:
            section = sectionWithSyncedTabCompact(for: traitCollection)
        case .compactJumpBackIn, .regular, .regularWithSyncedTab, .medium, .mediumWithSyncedTab:
            section = defaultSection(for: traitCollection)
        }

        // Supplementary Item
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .estimated(34))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]

        let leadingInset = HomepageViewModel.UX.leadingInset(traitCollection: traitCollection)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                        leading: leadingInset,
                                                        bottom: HomepageViewModel.UX.spacingBetweenSections,
                                                        trailing: 0)
        section.interGroupSpacing = JumpBackInCell.UX.interGroupSpacing

        return section
    }

    var hasData: Bool {
        return hasJumpBackIn || hasSyncedTab
    }

    func refreshData(for traitCollection: UITraitCollection,
                     isPortrait: Bool = UIWindow.isPortrait,
                     device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) {
        getLatestData()
        updateSectionLayout(for: traitCollection,
                            isPortrait: isPortrait,
                            device: device)

        let maxItemToDisplay = sectionLayout.maxItemsToDisplay(
            displayGroup: .jumpBackIn,
            hasAccount: jumpBackInDataAdaptor.hasSyncedTabFeatureEnabled,
            device: device
        )
        jumpBackInDataAdaptor.refreshData(maxItemToDisplay: maxItemToDisplay)
        getLatestData()
    }

    private func getLatestData() {
        jumpBackInList = jumpBackInDataAdaptor.getJumpBackInData()
        mostRecentSyncedTab = jumpBackInDataAdaptor.getSyncedTabData()
    }

    func updatePrivacyConcernedSection(isPrivate: Bool) {
        self.isPrivate = isPrivate
    }

    func screenWasShown() {
        hasSentJumpBackInTileEvent = false
    }

    func setTheme(theme: Theme) {
        self.theme = theme
    }
}

// MARK: FxHomeSectionHandler
extension JumpBackInViewModel: HomepageSectionHandler {

    func configure(_ collectionView: UICollectionView,
                   at indexPath: IndexPath) -> UICollectionViewCell {
        if let jumpBackInItemRow = sectionLayout.indexOfJumpBackInItem(for: indexPath) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: JumpBackInCell.cellIdentifier,
                                                          for: indexPath)
            guard let jumpBackInCell = cell as? JumpBackInCell else { return UICollectionViewCell() }

            if jumpBackInItemRow == (jumpBackInList.itemsToDisplay - 1),
               let group = jumpBackInList.group {
                configureJumpBackInCellForGroups(group: group, cell: jumpBackInCell, indexPath: indexPath)
            } else if let item = jumpBackInList.tabs[safe: jumpBackInItemRow] {
                configureJumpBackInCellForTab(item: item, cell: jumpBackInCell, indexPath: indexPath)
            }
            return jumpBackInCell

        } else if hasSyncedTab {
            // SyncedTab cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SyncedTabCell.cellIdentifier,
                                                          for: indexPath)
            guard let syncedTabCell = cell as? SyncedTabCell,
                  let mostRecentSyncedTab = mostRecentSyncedTab,
                  let prepareContextualHint = prepareContextualHint
            else { return UICollectionViewCell() }
            configureSyncedTabCellForTab(item: mostRecentSyncedTab, cell: syncedTabCell, indexPath: indexPath)
            prepareContextualHint(syncedTabCell)
            return syncedTabCell
        }

        // something went wrong
        return UICollectionViewCell()
    }

    func configure(_ cell: UICollectionViewCell,
                   at indexPath: IndexPath) -> UICollectionViewCell {
        // Setup is done through configure(collectionView:indexPath:), shouldn't be called
        return UICollectionViewCell()
    }

    func didSelectItem(at indexPath: IndexPath,
                       homePanelDelegate: HomePanelDelegate?,
                       libraryPanelDelegate: LibraryPanelDelegate?) {
        if let jumpBackInItemRow = sectionLayout.indexOfJumpBackInItem(for: indexPath) {
            // JumpBackIn cell
            if jumpBackInItemRow == jumpBackInList.itemsToDisplay - 1,
               let group = jumpBackInList.group {
                switchTo(group: group)

            } else if let tab = jumpBackInList.tabs[safe: jumpBackInItemRow] {
                switchTo(tab: tab)
            }
        } else if hasSyncedTab {
            // SyncedTab cell
            // do nothing, will be handled in cell depending on area tapped
        }
    }
}

extension JumpBackInViewModel: JumpBackInDelegate {
    func didLoadNewData() {
        ensureMainThread {
            self.getLatestData()
            guard self.isEnabled else { return }
            self.delegate?.reloadView()
        }
    }
}
