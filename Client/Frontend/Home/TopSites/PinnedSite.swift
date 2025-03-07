// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Storage

open class PinnedSite: Site {
    let isPinnedSite = true

    init(site: Site) {
        super.init(url: site.url, title: site.title, bookmarked: site.bookmarked)
        self.icon = site.icon
        self.metadata = site.metadata
    }
}
