//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import CoreData
@testable import StreamChat
import XCTest

class EntityDatabaseObserverMock<Item, DTO: NSManagedObject>: EntityDatabaseObserver<Item, DTO> {
    var synchronizeError: Error?
    var startObservingCalled: Bool = false
    
    override func startObserving() throws {
        if let error = synchronizeError {
            throw error
        } else {
            startObservingCalled = true
            try super.startObserving()
        }
    }
    
    var item_mock: Item?
    override var item: Item? {
        item_mock ?? super.item
    }
}
