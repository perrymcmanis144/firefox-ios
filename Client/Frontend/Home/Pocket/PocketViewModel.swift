// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Storage
import Shared

class PocketViewModel {

    struct UX {
        static let numberOfItemsInColumn = 3
        static let fractionalWidthiPhonePortrait: CGFloat = 0.90
        static let fractionalWidthiPhoneLanscape: CGFloat = 0.46
    }

    // MARK: - Properties

    var isZeroSearch: Bool
    var theme: Theme
    private var hasSentPocketSectionEvent = false

    var onTapTileAction: ((URL) -> Void)?
    var onLongPressTileAction: ((Site, UIView?) -> Void)?
    var onScroll: (([NSCollectionLayoutVisibleItem]) -> Void)?
    weak var delegate: HomepageDataModelDelegate?

    private var dataAdaptor: PocketDataAdaptor
    private var pocketStoriesViewModels = [PocketStandardCellViewModel]()
    private var wallpaperManager: WallpaperManager

    init(pocketDataAdaptor: PocketDataAdaptor,
         isZeroSearch: Bool = false,
         theme: Theme,
         wallpaperManager: WallpaperManager) {
        self.dataAdaptor = pocketDataAdaptor
        self.isZeroSearch = isZeroSearch
        self.theme = theme
        self.wallpaperManager = wallpaperManager
    }

    // The dimension of a cell
    // Fractions for iPhone to only show a slight portion of the next column
    func getWidthDimension(device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom,
                           isLandscape: Bool = UIWindow.isLandscape) -> NSCollectionLayoutDimension {
        if device == .pad {
            return .absolute(PocketStandardCell.UX.cellWidth) // iPad
        } else if isLandscape {
            return .fractionalWidth(UX.fractionalWidthiPhoneLanscape)
        } else {
            return .fractionalWidth(UX.fractionalWidthiPhonePortrait)
        }
    }

    private func isStoryCell(index: Int) -> Bool {
        return index < pocketStoriesViewModels.count
    }

    private func getSitesDetail(for index: Int) -> Site {
        if isStoryCell(index: index) {
            return Site(url: pocketStoriesViewModels[index].url?.absoluteString ?? "",
                        title: pocketStoriesViewModels[index].title)
        } else {
            return Site(url: PocketProvider.MoreStoriesURL.absoluteString,
                        title: .FirefoxHomepage.Pocket.DiscoverMore)
        }
    }

    // MARK: - Telemetry

    private func recordSectionHasShown() {
        if !hasSentPocketSectionEvent {
            TelemetryWrapper.recordEvent(category: .action,
                                         method: .view,
                                         object: .pocketSectionImpression,
                                         value: nil,
                                         extras: nil)
            hasSentPocketSectionEvent = true
        }
    }

    private func recordTapOnStory(index: Int) {
        // Pocket site extra
        let key = TelemetryWrapper.EventExtraKey.pocketTilePosition.rawValue
        let siteExtra = [key: "\(index)"]

        // Origin extra
        let originExtra = TelemetryWrapper.getOriginExtras(isZeroSearch: isZeroSearch)
        let extras = originExtra.merge(with: siteExtra)

        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .pocketStory, value: nil, extras: extras)
    }

    // MARK: - Private

    private func updateData() {
        let stories = dataAdaptor.getPocketData()
        pocketStoriesViewModels = []
        // Add the story in the view models list
        for story in stories {
            bind(pocketStoryViewModel: .init(story: story))
        }
    }

    private func bind(pocketStoryViewModel: PocketStandardCellViewModel) {
        pocketStoryViewModel.onTap = { [weak self] indexPath in
            self?.recordTapOnStory(index: indexPath.row)
            let siteUrl = self?.pocketStoriesViewModels[indexPath.row].url
            siteUrl.map { self?.onTapTileAction?($0) }
        }

        pocketStoriesViewModels.append(pocketStoryViewModel)
    }

    private func showDiscoverMore() {
        onTapTileAction?(PocketProvider.MoreStoriesURL)
    }
}

// MARK: HomeViewModelProtocol
extension PocketViewModel: HomepageViewModelProtocol, FeatureFlaggable {

    var sectionType: HomepageSectionType {
        return .pocket
    }

    var headerViewModel: LabelButtonHeaderViewModel {
        var textColor: UIColor?
        if let wallpaperVersion: WallpaperVersion = featureFlags.getCustomState(for: .wallpaperVersion),
           wallpaperVersion == .v1 {
            textColor = wallpaperManager.currentWallpaper.textColor
        }

        return LabelButtonHeaderViewModel(
            title: HomepageSectionType.pocket.title,
            titleA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.SectionTitles.pocket,
            isButtonHidden: true,
            textColor: textColor)
    }

    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(PocketStandardCell.UX.cellHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: getWidthDimension(),
            heightDimension: .estimated(PocketStandardCell.UX.cellHeight)
        )

        let subItems = Array(repeating: item, count: UX.numberOfItemsInColumn)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: subItems)
        group.interItemSpacing = PocketStandardCell.UX.interItemSpacing
        group.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: 0,
            trailing: PocketStandardCell.UX.interGroupSpacing)

        let section = NSCollectionLayoutSection(group: group)
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .estimated(34))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]
        section.visibleItemsInvalidationHandler = { (visibleItems, point, env) -> Void in
            self.onScroll?(visibleItems)
        }

        let leadingInset = HomepageViewModel.UX.leadingInset(traitCollection: traitCollection)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                        leading: leadingInset,
                                                        bottom: HomepageViewModel.UX.spacingBetweenSections,
                                                        trailing: 0)
        section.orthogonalScrollingBehavior = .continuous
        return section
    }

    func numberOfItemsInSection() -> Int {
        // Including discover more cell
        return !pocketStoriesViewModels.isEmpty ? pocketStoriesViewModels.count + 1 : 0
    }

    var isEnabled: Bool {
        // For Pocket, the user preference check returns a user preference if it exists in
        // UserDefaults, and, if it does not, it will return a default preference based on
        // a (nimbus pocket section enabled && Pocket.isLocaleSupported) check
        return featureFlags.isFeatureEnabled(.pocket, checking: .buildAndUser)
    }

    var hasData: Bool {
        return !pocketStoriesViewModels.isEmpty
    }

    func refreshData(for traitCollection: UITraitCollection,
                     isPortrait: Bool = UIWindow.isPortrait,
                     device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) {}

    func screenWasShown() {
        hasSentPocketSectionEvent = false
    }

    func setTheme(theme: Theme) {
        self.theme = theme
    }
}

// MARK: FxHomeSectionHandler
extension PocketViewModel: HomepageSectionHandler {

    func configure(_ collectionView: UICollectionView,
                   at indexPath: IndexPath) -> UICollectionViewCell {

        recordSectionHasShown()

        if isStoryCell(index: indexPath.row) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PocketStandardCell.cellIdentifier,
                                                          for: indexPath) as! PocketStandardCell
            let viewModel = pocketStoriesViewModels[indexPath.row]
            viewModel.tag = indexPath.row
            cell.configure(viewModel: viewModel, theme: theme)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PocketDiscoverCell.cellIdentifier,
                                                          for: indexPath) as! PocketDiscoverCell
            cell.configure(text: .FirefoxHomepage.Pocket.DiscoverMore, theme: theme)
            return cell
        }
    }

    func configure(_ cell: UICollectionViewCell,
                   at indexPath: IndexPath) -> UICollectionViewCell {
        // Setup is done through configure(collectionView:indexPath:), shouldn't be called
        return UICollectionViewCell()
    }

    func didSelectItem(at indexPath: IndexPath,
                       homePanelDelegate: HomePanelDelegate?,
                       libraryPanelDelegate: LibraryPanelDelegate?) {

        if isStoryCell(index: indexPath.row) {
            pocketStoriesViewModels[indexPath.row].onTap(indexPath)

        } else {
            showDiscoverMore()
        }
    }

    func handleLongPress(with collectionView: UICollectionView, indexPath: IndexPath) {
        guard let onLongPressTileAction = onLongPressTileAction else { return }

        let site = getSitesDetail(for: indexPath.row)
        let sourceView = collectionView.cellForItem(at: indexPath)
        onLongPressTileAction(site, sourceView)
    }
}

extension PocketViewModel: PocketDelegate {
    func didLoadNewData() {
        ensureMainThread {
            self.updateData()
            guard self.isEnabled else { return }
            self.delegate?.reloadView()
        }
    }
}
