// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

@testable import Client
import XCTest
import WebKit
import Storage
import Shared

class JumpBackInViewModelTests: XCTestCase {
    var mockProfile: MockProfile!
    var mockTabManager: MockTabManager!

    var mockBrowserBarViewDelegate: MockBrowserBarViewDelegate!
    var stubBrowserViewController: BrowserViewController!

    var adaptor: JumpBackInDataAdaptorMock!

    override func setUp() {
        super.setUp()

        adaptor = JumpBackInDataAdaptorMock()
        mockProfile = MockProfile()
        mockTabManager = MockTabManager()
        stubBrowserViewController = BrowserViewController(
            profile: mockProfile,
            tabManager: TabManager(profile: mockProfile, imageStore: nil)
        )
        mockBrowserBarViewDelegate = MockBrowserBarViewDelegate()

        FeatureFlagsManager.shared.initializeDeveloperFeatures(with: mockProfile)
    }

    override func tearDown() {
        super.tearDown()
        adaptor = nil
        stubBrowserViewController = nil
        mockBrowserBarViewDelegate = nil
        mockTabManager = nil
        mockProfile = nil
    }

    // MARK: - Switch to group

    func test_switchToGroup_noBrowserDelegate_doNothing() {
        let subject = createSubject(addDelegate: false)
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [], timestamp: 0)
        var completionDidRun = false
        subject.onTapGroup = { tab in
            completionDidRun = true
        }

        subject.switchTo(group: group)

        XCTAssertFalse(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 0)
        XCTAssertFalse(completionDidRun)
    }

    func test_switchToGroup_noGroupedItems_doNothing() {
        let subject = createSubject()
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [], timestamp: 0)
        mockBrowserBarViewDelegate.inOverlayMode = true
        var completionDidRun = false
        subject.onTapGroup = { tab in
            completionDidRun = true
        }

        subject.switchTo(group: group)

        XCTAssertTrue(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 1)
        XCTAssertFalse(completionDidRun)
    }

    func test_switchToGroup_inOverlayMode_leavesOverlayMode() {
        let subject = createSubject()
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [], timestamp: 0)
        mockBrowserBarViewDelegate.inOverlayMode = true
        var completionDidRun = false
        subject.onTapGroup = { tab in
            completionDidRun = true
        }

        subject.switchTo(group: group)

        XCTAssertTrue(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 1)
        XCTAssertFalse(completionDidRun)
    }

    func test_switchToGroup_callCompletionOnFirstGroupedItem() {
        let subject = createSubject()
        let expectedTab = createTab(profile: mockProfile)
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [expectedTab], timestamp: 0)
        mockBrowserBarViewDelegate.inOverlayMode = true
        var receivedTab: Tab?
        subject.onTapGroup = { tab in
            receivedTab = tab
        }

        subject.switchTo(group: group)

        XCTAssertTrue(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(expectedTab, receivedTab)
    }

    // MARK: - Switch to tab

    func test_switchToTab_noBrowserDelegate_doNothing() {
        let subject = createSubject()
        let expectedTab = createTab(profile: mockProfile)
        subject.browserBarViewDelegate = nil

        subject.switchTo(tab: expectedTab)

        XCTAssertFalse(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 0)
        XCTAssertTrue(mockTabManager.lastSelectedTabs.isEmpty)
    }

    func test_switchToTab_notInOverlayMode_switchTabs() {
        let subject = createSubject()
        let tab = createTab(profile: mockProfile)
        mockBrowserBarViewDelegate.inOverlayMode = false

        subject.switchTo(tab: tab)

        XCTAssertFalse(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 0)
        XCTAssertFalse(mockTabManager.lastSelectedTabs.isEmpty)
    }

    func test_switchToTab_inOverlayMode_leaveOverlayMode() {
        let subject = createSubject()
        let tab = createTab(profile: mockProfile)
        mockBrowserBarViewDelegate.inOverlayMode = true

        subject.switchTo(tab: tab)

        XCTAssertTrue(mockBrowserBarViewDelegate.inOverlayMode)
        XCTAssertEqual(mockBrowserBarViewDelegate.leaveOverlayModeCount, 1)
        XCTAssertFalse(mockTabManager.lastSelectedTabs.isEmpty)
    }

    func test_switchToTab_tabManagerSelectsTab() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile)
        mockBrowserBarViewDelegate.inOverlayMode = true

        subject.switchTo(tab: tab1)

        XCTAssertTrue(mockBrowserBarViewDelegate.inOverlayMode)
        guard !mockTabManager.lastSelectedTabs.isEmpty else {
            XCTFail("No tabs were selected in mock tab manager.")
            return
        }
        XCTAssertEqual(mockTabManager.lastSelectedTabs[0], tab1)
    }

    // MARK: - Jump back in layout

    func testMaxJumpBackInItemsToDisplay_compactJumpBackIn() {
        let subject = createSubject()

        // iPhone layout
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.refreshData(for: trait, isPortrait: true, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: false,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 2)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
    }

    func testMaxJumpBackInItemsToDisplay_compactSyncedTab() {
        let subject = createSubject()
        subject.featureFlags.set(feature: .jumpBackInSyncedTab, to: true)
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: true, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 0)
        XCTAssertEqual(subject.sectionLayout, .compactSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_compactJumpBackInAndSyncedTab() {
        let subject = createSubject()
        subject.featureFlags.set(feature: .jumpBackInSyncedTab, to: true)
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: true, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 1)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackInAndSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.mockHasSyncedTabFeatureEnabled = false

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact
        subject.refreshData(for: trait, isPortrait: false, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 4)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact
        subject.refreshData(for: trait, isPortrait: false, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 2)
        XCTAssertEqual(subject.sectionLayout, .mediumWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.mockHasSyncedTabFeatureEnabled = false

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: true, device: .pad)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 4)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: true, device: .pad)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 2)
        XCTAssertEqual(subject.sectionLayout, .mediumWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_regularIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.mockHasSyncedTabFeatureEnabled = false

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: false, device: .pad)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 6)
        XCTAssertEqual(subject.sectionLayout, .regular)
    }

    func testMaxJumpBackInItemsToDisplay_regularWithSyncedTabIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: false, device: .pad)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 4)
        XCTAssertEqual(subject.sectionLayout, .regularWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIphone_hasNoSyncedTabFallsIntoMediumLayout() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact
        subject.refreshData(for: trait, isPortrait: false, device: .phone)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .phone)
        XCTAssertEqual(jumpBackInItemsMax, 4)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_regularWithSyncedTabIpad_hasNoSyncedTabFallsIntoRegularLayout() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])

        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: trait, isPortrait: false, device: .pad)
        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .jumpBackIn,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 6)
        XCTAssertEqual(subject.sectionLayout, .regular)
    }

    func testUpdateLayoutSectionBeforeRefreshData() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1, tab2, tab3])

        // Start in portrait
        let portraitTrait = MockTraitCollection()
        portraitTrait.overridenHorizontalSizeClass = .compact
        portraitTrait.overridenVerticalSizeClass = .regular
        subject.refreshData(for: portraitTrait, isPortrait: true, device: .phone)

        XCTAssertEqual(adaptor.maxItemToDisplay, 2)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)

        // Mock rotation to landscape
        let landscapeTrait = MockTraitCollection()
        landscapeTrait.overridenHorizontalSizeClass = .regular
        landscapeTrait.overridenVerticalSizeClass = .compact
        subject.refreshData(for: landscapeTrait, isPortrait: false, device: .phone)

        XCTAssertEqual(adaptor.maxItemToDisplay, 4)
        XCTAssertEqual(subject.sectionLayout, .medium)

        // Go back to portrait
        subject.refreshData(for: portraitTrait, isPortrait: true, device: .phone)
        XCTAssertEqual(adaptor.maxItemToDisplay, 2)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
    }

    // MARK: - Sync tab layout

    func testMaxDisplayedItemSyncedTab_withAccount() {
        let subject = createSubject()

        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .syncedTab,
                                                                         hasAccount: true,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 1)
    }

    func testMaxDisplayedItemSyncedTab_withoutAccount() {
        let subject = createSubject()

        let jumpBackInItemsMax = subject.sectionLayout.maxItemsToDisplay(displayGroup: .syncedTab,
                                                                         hasAccount: false,
                                                                         device: .pad)
        XCTAssertEqual(jumpBackInItemsMax, 0)
    }

    // MARK: Refresh data

    func testRefreshData_noData() {
        let subject = createSubject()
        subject.refreshData(for: MockTraitCollection())

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testRefreshData_jumpBackInList() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        subject.refreshData(for: MockTraitCollection())

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 1)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testRefreshData_syncedTab() {
        let subject = createSubject()
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        subject.refreshData(for: MockTraitCollection())

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNotNil(subject.mostRecentSyncedTab)
    }

    // MARK: Did load new data

    func testDidLoadNewData_noNewData() {
        let subject = createSubject()
        subject.didLoadNewData()

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testDidLoadNewData_jumpBackInList() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.jumpBackInList = JumpBackInList(group: nil, tabs: [tab1])
        subject.didLoadNewData()

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 1)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testDidLoadNewData_syncedTab() {
        let subject = createSubject()
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        subject.didLoadNewData()

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNotNil(subject.mostRecentSyncedTab)
    }
}

// MARK: - Helpers
extension JumpBackInViewModelTests {

    func createSubject(addDelegate: Bool = true) -> JumpBackInViewModel {
        let subject = JumpBackInViewModel(
            isZeroSearch: false,
            profile: mockProfile,
            isPrivate: false,
            theme: LightTheme(),
            tabManager: mockTabManager,
            adaptor: adaptor,
            wallpaperManager: WallpaperManager()
        )
        if addDelegate {
            subject.browserBarViewDelegate = mockBrowserBarViewDelegate
        }

        trackForMemoryLeaks(subject)

        return subject
    }

    func createTab(profile: MockProfile,
                   configuration: WKWebViewConfiguration = WKWebViewConfiguration(),
                   urlString: String? = "www.website.com") -> Tab {
        let tab = Tab(profile: profile, configuration: configuration)

        if let urlString = urlString {
            tab.url = URL(string: urlString)!
        }
        return tab
    }

    var remoteClient: RemoteClient {
        return RemoteClient(guid: nil,
                            name: "Fake client",
                            modified: 1,
                            type: nil,
                            formfactor: nil,
                            os: nil,
                            version: nil,
                            fxaDeviceId: nil)
    }

    var remoteTab: RemoteTab {
        return RemoteTab(clientGUID: "1",
                         URL: URL(string: "www.mozilla.org")!,
                         title: "Mozilla 1",
                         history: [],
                         lastUsed: 1,
                         icon: nil)
    }
}

class JumpBackInDataAdaptorMock: JumpBackInDataAdaptor {

    var mockHasSyncedTabFeatureEnabled: Bool = true
    var hasSyncedTabFeatureEnabled: Bool {
        return mockHasSyncedTabFeatureEnabled
    }

    var jumpBackInList = JumpBackInList(group: nil, tabs: [Tab]())
    func getJumpBackInData() -> JumpBackInList {
        return jumpBackInList
    }

    var syncedTab: JumpBackInSyncedTab?
    func getSyncedTabData() -> JumpBackInSyncedTab? {
        return syncedTab
    }

    func getHeroImage(forSite site: Site) -> UIImage? {
        return nil
    }

    func getFaviconImage(forSite site: Site) -> UIImage? {
        return nil
    }

    var maxItemToDisplay: Int = 0
    func refreshData(maxItemToDisplay: Int) {
        self.maxItemToDisplay = maxItemToDisplay
    }
}

// MARK: - MockBrowserBarViewDelegate
class MockBrowserBarViewDelegate: BrowserBarViewDelegate {
    var inOverlayMode = false

    var leaveOverlayModeCount = 0

    func leaveOverlayMode(didCancel cancel: Bool) {
        leaveOverlayModeCount += 1
    }
}
