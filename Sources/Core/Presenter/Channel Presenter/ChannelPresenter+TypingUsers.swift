//
//  ChannelPresenter+TypingUsers.swift
//  StreamChatCore
//
//  Created by Alexey Bukhtin on 18/09/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation
import RxSwift

extension ChannelPresenter {
    /// Creates a text for users typing.
    ///
    /// - Returns: a text of users typing, e.g. "<UserName> is typing...", "User1 and 5 others are typing..."
    public func typingUsersText() -> String? {
        guard !typingUsers.isEmpty else {
            return nil
        }
        
        if typingUsers.count == 1, let typingUser = typingUsers.first {
            return "\(typingUser.user.name) est en train d'écrire..."
        } else if typingUsers.count == 2 {
            return "\(typingUsers[0].user.name) et \(typingUsers[1].user.name) sont en train d'écrire..."
        } else if let typingUser = typingUsers.first {
            return "\(typingUser.user.name) et \(String(typingUsers.count - 1)) autres sont en train d'écrire..."
        }
        
        return nil
    }
}

/// A typing user.
public struct TypingUser: Hashable {
    /// A time interval for a users typing timeout.
    public static let timeout: TimeInterval = 30
    
    /// A typiong user.
    public let user: User
    /// A date when the user started typing.
    public let started = Date()
    
    public static func == (lhs: TypingUser, rhs: TypingUser) -> Bool {
        return lhs.user == rhs.user
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }
}
