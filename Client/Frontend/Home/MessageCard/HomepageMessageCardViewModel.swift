// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

protocol MessageSurfaceProtocol {
    func getMessage(for surface: MessageSurfaceId) -> GleanPlumbMessage?
    func handleMessageDisplayed()
    func handleMessagePressed()
    func handleMessageDismiss()
}

class HomepageMessageCardViewModel: MessageSurfaceProtocol {

    private let dataAdaptor: MessageCardDataAdaptor
    private let messagingManager: GleanPlumbMessageManagerProtocol

    weak var delegate: HomepageDataModelDelegate?
    var message: GleanPlumbMessage?
    var dismissClosure: (() -> Void)?
    var theme: Theme

    init(dataAdaptor: MessageCardDataAdaptor,
         theme: Theme,
         messagingManager: GleanPlumbMessageManagerProtocol = GleanPlumbMessageManager.shared
    ) {
        self.dataAdaptor = dataAdaptor
        self.theme = theme
        self.messagingManager = messagingManager
    }

    func getMessage(for surface: MessageSurfaceId) -> GleanPlumbMessage? {
        return message
    }

    var shouldDisplayMessageCard: Bool {
        guard let message = message else { return false }

        return !message.isExpired
    }

    func handleMessageDisplayed() {
        message.map(messagingManager.onMessageDisplayed)
    }

    func handleMessagePressed() {
        message.map(messagingManager.onMessagePressed)
        dismissClosure?()
    }

    func handleMessageDismiss() {
        message.map(messagingManager.onMessageDismissed)
        dismissClosure?()
    }
}

// MARK: - HomepageViewModelProtocol
extension HomepageMessageCardViewModel: HomepageViewModelProtocol {
    var sectionType: HomepageSectionType {
        return .messageCard
    }

    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                              heightDimension: .estimated(180))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .estimated(180))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)

        let section = NSCollectionLayoutSection(group: group)

        let horizontalInset = HomepageViewModel.UX.leadingInset(traitCollection: traitCollection)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                        leading: horizontalInset,
                                                        bottom: 16,
                                                        trailing: horizontalInset)

        return section
    }

    func numberOfItemsInSection() -> Int {
        return 1
    }

    var headerViewModel: LabelButtonHeaderViewModel {
        return .emptyHeader
    }

    var isEnabled: Bool {
        return true
    }

    var hasData: Bool {
        return shouldDisplayMessageCard
    }

    func refreshData(for traitCollection: UITraitCollection,
                     isPortrait: Bool = UIWindow.isPortrait,
                     device: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) {}

    func setTheme(theme: Theme) {
        self.theme = theme
    }
}

// MARK: - HomepageSectionHandler
extension HomepageMessageCardViewModel: HomepageSectionHandler {

    func configure(_ cell: UICollectionViewCell, at indexPath: IndexPath) -> UICollectionViewCell {
        guard let messageCell = cell as? HomepageMessageCardCell else {
            return UICollectionViewCell()
        }

        messageCell.configure(viewModel: self, theme: theme)
        return messageCell
    }
}

// MARK: - MessageCardDelegate
extension HomepageMessageCardViewModel: MessageCardDelegate {
    func didLoadNewData() {
        ensureMainThread {
            self.message = self.dataAdaptor.getMessageCardData()
            guard self.isEnabled else { return }
            self.delegate?.reloadView()
            self.handleMessageDisplayed()
        }
    }
}
