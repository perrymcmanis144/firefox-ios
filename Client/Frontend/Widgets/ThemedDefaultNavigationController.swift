// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

class ThemedDefaultNavigationController: DismissableNavigationViewController, Themeable {

    var themeManager: ThemeManager
    var notificationCenter: NotificationProtocol
    var themeObserver: NSObjectProtocol?

    init(rootViewController: UIViewController,
         themeManager: ThemeManager = AppContainer.shared.resolve(),
         notificationCenter: NotificationProtocol = NotificationCenter.default) {

        self.themeManager = themeManager
        self.notificationCenter = notificationCenter
        super.init(rootViewController: rootViewController)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        listenForThemeChange()
        applyTheme()
    }

    private func setupNavigationBarAppearance() {
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.backgroundColor = themeManager.currentTheme.colors.layer1
        standardAppearance.shadowColor = nil
        standardAppearance.shadowImage = UIImage()

        navigationBar.standardAppearance = standardAppearance
        navigationBar.compactAppearance = standardAppearance
        navigationBar.scrollEdgeAppearance = standardAppearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = standardAppearance
        }
        navigationBar.tintColor = themeManager.currentTheme.colors.textPrimary
    }

    private func setupToolBarAppearance() {
        let standardAppearance = UIToolbarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.backgroundColor = themeManager.currentTheme.colors.layer1
        standardAppearance.shadowColor = nil
        standardAppearance.shadowImage = UIImage()

        toolbar.standardAppearance = standardAppearance
        toolbar.compactAppearance = standardAppearance
        if #available(iOS 15.0, *) {
            toolbar.scrollEdgeAppearance = standardAppearance
            toolbar.compactScrollEdgeAppearance = standardAppearance
        }
        toolbar.tintColor = themeManager.currentTheme.colors.textPrimary
    }

    // MARK: - Themable

    func applyTheme() {
        setupNavigationBarAppearance()
        setupToolBarAppearance()

        setNeedsStatusBarAppearanceUpdate()
    }
}
