//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// Button for opening attachments.
open class ChatAttachmentButton: _Button, AppearanceProvider {
    override open func setUpAppearance() {
        super.setUpAppearance()

        let clipIcon = appearance
            .images
            .openAttachments
            .tinted(with: appearance.colorPalette.inactiveTint)
        setImage(clipIcon, for: .normal)
    }
}