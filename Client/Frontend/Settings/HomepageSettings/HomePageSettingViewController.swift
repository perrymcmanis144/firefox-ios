// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import Shared

class HomePageSettingViewController: SettingsTableViewController, FeatureFlaggable {

    // MARK: - Variables
    /* variables for checkmark settings */
    let prefs: Prefs
    var currentNewTabChoice: NewTabPage!
    var currentStartAtHomeSetting: StartAtHomeSetting!
    var hasHomePage = false
    var wallpaperManager: WallpaperManagerInterface

    var isJumpBackInSectionEnabled: Bool {
        return featureFlags.isFeatureEnabled(.jumpBackIn, checking: .buildOnly)
    }

    var isRecentlySavedSectionEnabled: Bool {
        return featureFlags.isFeatureEnabled(.recentlySaved, checking: .buildOnly)
    }

    var isWallpaperSectionEnabled: Bool {
        return wallpaperManager.canSettingsBeShown &&
            featureFlags.isFeatureEnabled(.wallpapers, checking: .buildOnly)
    }

    var isPocketSectionEnabled: Bool {
        return featureFlags.isFeatureEnabled(.pocket, checking: .buildOnly)
    }

    var isPocketSponsoredStoriesEnabled: Bool {
        return featureFlags.isFeatureEnabled(.sponsoredPocket, checking: .buildOnly)
    }

    var isHistoryHighlightsSectionEnabled: Bool {
        return featureFlags.isFeatureEnabled(.historyHighlights, checking: .buildOnly)
    }

    // MARK: - Initializers
    init(prefs: Prefs,
         wallpaperManager: WallpaperManagerInterface = WallpaperManager()) {
        self.prefs = prefs
        self.wallpaperManager = wallpaperManager
        super.init(style: .grouped)

        title = .SettingsHomePageSectionName
        navigationController?.navigationBar.accessibilityIdentifier = AccessibilityIdentifiers.Settings.Homepage.homePageNavigationBar
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.post(name: .HomePanelPrefsChanged, object: nil)
    }

    // MARK: - Methods
    override func generateSettings() -> [SettingSection] {
        let customizeFirefoxHomeSection = customizeFirefoxSettingSection()
        let customizeHomePageSection = customizeHomeSettingSection()

        guard let startAtHomeSection = setupStartAtHomeSection() else {
            return [customizeFirefoxHomeSection, customizeHomePageSection]
        }

        return [startAtHomeSection, customizeFirefoxHomeSection, customizeHomePageSection]
    }

    private func customizeHomeSettingSection() -> SettingSection {

        // The Home button and the New Tab page can be set independently
        self.currentNewTabChoice = NewTabAccessors.getHomePage(self.prefs)
        self.hasHomePage = HomeButtonHomePageAccessors.getHomePage(self.prefs) != nil

        let onFinished = {
            self.prefs.setString(self.currentNewTabChoice.rawValue, forKey: NewTabAccessors.HomePrefKey)
            self.tableView.reloadData()
        }

        let showTopSites = CheckmarkSetting(
            title: NSAttributedString(string: .SettingsNewTabTopSites),
            subtitle: nil,
            accessibilityIdentifier: "HomeAsFirefoxHome",
            isChecked: { return self.currentNewTabChoice == NewTabPage.topSites },
            onChecked: {
                self.currentNewTabChoice = NewTabPage.topSites
                onFinished()
        })
        let showWebPage = WebPageSetting(
            prefs: prefs,
            prefKey: PrefsKeys.HomeButtonHomePageURL,
            defaultValue: nil,
            placeholder: .CustomNewPageURL,
            accessibilityIdentifier: "HomeAsCustomURL",
            isChecked: { return !showTopSites.isChecked() },
            settingDidChange: { (string) in
                self.currentNewTabChoice = NewTabPage.homePage
                self.prefs.setString(self.currentNewTabChoice.rawValue, forKey: NewTabAccessors.HomePrefKey)
                self.tableView.reloadData()
        })
        showWebPage.textField.textAlignment = .natural

        return SettingSection(title: NSAttributedString(string: .SettingsHomePageURLSectionTitle),
                              footerTitle: NSAttributedString(string: .Settings.Homepage.Current.Description),
                              children: [showTopSites, showWebPage])
    }

    private func customizeFirefoxSettingSection() -> SettingSection {

        // Setup
        var sectionItems = [Setting]()

        let pocketSponsoredSetting = BoolSetting(with: .sponsoredPocket,
                                        titleText: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.SponsoredPocket))
        // This sets whether the cell is enabled or not, and not the setting itself.
        pocketSponsoredSetting.enabled = featureFlags.isFeatureEnabled(
            .pocket,
            checking: .buildAndUser)

        let pocketSetting = BoolSetting(
            with: .pocket,
            titleText: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.Pocket)) { [weak self] in
                // Disable sponsored option if pocket stories are disabled
                pocketSponsoredSetting.enabled = $0
                self?.tableView.reloadData()
            }

        let jumpBackInSetting = BoolSetting(with: .jumpBackIn,
                                            titleText: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.JumpBackIn))

        let recentlySavedSetting = BoolSetting(with: .recentlySaved,
                                               titleText: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.RecentlySaved))

        let historyHighlightsSetting = BoolSetting(with: .historyHighlights,
                                                   titleText: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.RecentlyVisited))
        let wallpaperSetting = WallpaperSettings(settings: self, wallpaperManager: wallpaperManager)

        // Section ordering
        sectionItems.append(TopSitesSettings(settings: self))

        if isJumpBackInSectionEnabled {
            sectionItems.append(jumpBackInSetting)
        }

        if isRecentlySavedSectionEnabled {
            sectionItems.append(recentlySavedSetting)
        }

        if isHistoryHighlightsSectionEnabled {
            sectionItems.append(historyHighlightsSetting)
        }

        if isPocketSectionEnabled {
            sectionItems.append(pocketSetting)

            // Only show the sponsored stories setting if the Pocket setting is showing
            if isPocketSponsoredStoriesEnabled {
                sectionItems.append(pocketSponsoredSetting)
            }
        }

        if isWallpaperSectionEnabled {
            sectionItems.append(wallpaperSetting)
        }

        return SettingSection(title: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.Title),
                              footerTitle: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.Description),
                              children: sectionItems)
    }

    private func setupStartAtHomeSection() -> SettingSection? {
        guard featureFlags.isFeatureEnabled(.startAtHome, checking: .buildOnly) else { return nil }
        guard let startAtHomeSetting: StartAtHomeSetting = featureFlags.getCustomState(for: .startAtHome) else { return nil }
        currentStartAtHomeSetting = startAtHomeSetting

        typealias a11y = AccessibilityIdentifiers.Settings.Homepage.StartAtHome

        let onOptionSelected: (Bool, StartAtHomeSetting) -> Void = { state, option in
            self.featureFlags.set(feature: .startAtHome, to: option)
            self.tableView.reloadData()

            let extras = [TelemetryWrapper.EventExtraKey.preference.rawValue: PrefsKeys.FeatureFlags.StartAtHome,
                          TelemetryWrapper.EventExtraKey.preferenceChanged.rawValue: option.rawValue]
            TelemetryWrapper.recordEvent(category: .action, method: .change, object: .setting, extras: extras)
        }

        let afterFourHoursOption = CheckmarkSetting(
            title: NSAttributedString(string: .Settings.Homepage.StartAtHome.AfterFourHours),
            subtitle: nil,
            accessibilityIdentifier: a11y.afterFourHours,
            isChecked: { return self.currentStartAtHomeSetting == .afterFourHours },
            onChecked: {
                self.currentStartAtHomeSetting = .afterFourHours
                onOptionSelected(true, .afterFourHours)
        })

        let alwaysOption = CheckmarkSetting(
            title: NSAttributedString(string: .Settings.Homepage.StartAtHome.Always),
            subtitle: nil,
            accessibilityIdentifier: a11y.always,
            isChecked: { return self.currentStartAtHomeSetting == .always },
            onChecked: {
                self.currentStartAtHomeSetting = .always
                onOptionSelected(true, .always)
        })

        let neverOption = CheckmarkSetting(
            title: NSAttributedString(string: .Settings.Homepage.StartAtHome.Never),
            subtitle: nil,
            accessibilityIdentifier: a11y.disabled,
            isChecked: { return self.currentStartAtHomeSetting == .disabled },
            onChecked: {
                self.currentStartAtHomeSetting = .disabled
                onOptionSelected(false, .disabled)
        })

        let section = SettingSection(title: NSAttributedString(string: .Settings.Homepage.StartAtHome.SectionTitle),
                                     footerTitle: NSAttributedString(string: .Settings.Homepage.StartAtHome.SectionDescription),
                                     children: [alwaysOption, neverOption, afterFourHoursOption])

        return section
    }
}

// MARK: - TopSitesSettings
extension HomePageSettingViewController {
    class TopSitesSettings: Setting, FeatureFlaggable {
        var profile: Profile

        override var accessoryType: UITableViewCell.AccessoryType { return .disclosureIndicator }
        override var accessibilityIdentifier: String? { return AccessibilityIdentifiers.Settings.Homepage.CustomizeFirefox.Shortcuts.settingsPage }
        override var style: UITableViewCell.CellStyle { return .value1 }

        override var status: NSAttributedString {
            let areShortcutsOn = featureFlags.isFeatureEnabled(.topSites, checking: .userOnly)
            let status: String = areShortcutsOn ? .Settings.Homepage.Shortcuts.ToggleOn : .Settings.Homepage.Shortcuts.ToggleOff
            return NSAttributedString(string: String(format: status))
        }

        init(settings: SettingsTableViewController) {
            self.profile = settings.profile
            super.init(title: NSAttributedString(string: .Settings.Homepage.Shortcuts.ShortcutsPageTitle))
        }

        override func onClick(_ navigationController: UINavigationController?) {
            let topSitesVC = TopSitesSettingsViewController()
            topSitesVC.profile = profile
            navigationController?.pushViewController(topSitesVC, animated: true)
        }
    }
}

// MARK: - WallpaperSettings
extension HomePageSettingViewController {
    class WallpaperSettings: Setting, FeatureFlaggable {

        var settings: SettingsTableViewController
        var tabManager: TabManager
        var wallpaperManager: WallpaperManagerInterface

        override var accessoryType: UITableViewCell.AccessoryType { return .disclosureIndicator }
        override var accessibilityIdentifier: String? { return AccessibilityIdentifiers.Settings.Homepage.CustomizeFirefox.wallpaper }
        override var style: UITableViewCell.CellStyle { return .value1 }

        init(settings: SettingsTableViewController,
             and tabManager: TabManager = BrowserViewController.foregroundBVC().tabManager,
             wallpaperManager: WallpaperManagerInterface = WallpaperManager()
        ) {
            self.settings = settings
            self.tabManager = tabManager
            self.wallpaperManager = wallpaperManager
            super.init(title: NSAttributedString(string: .Settings.Homepage.CustomizeFirefoxHome.Wallpaper))
        }

        override func onClick(_ navigationController: UINavigationController?) {
            if wallpaperManager.canSettingsBeShown {
                let viewModel = WallpaperSettingsViewModel(wallpaperManager: wallpaperManager,
                                                           tabManager: tabManager,
                                                           theme: settings.themeManager.currentTheme)
                let wallpaperVC = WallpaperSettingsViewController(viewModel: viewModel)
                navigationController?.pushViewController(wallpaperVC, animated: true)
            }
        }
    }
}
