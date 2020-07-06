//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

@testable import StreamChatClient_v3
import XCTest

class ChannelModelDTO_Tests: XCTestCase {
    var database: DatabaseContainer!
    
    override func setUp() {
        super.setUp()
        database = try! DatabaseContainer(kind: .inMemory)
    }
    
    func test_channelPayload_isStoredAndLoadedFromDB() {
        let channelId: ChannelId = .unique
        
        let payload = dummyPayload(with: channelId)
        
        // Asynchronously save the payload to the db
        database.write { session in
            try! session.saveChannel(payload: payload)
        }
        
        // Load the channel from the db and check the fields are correct
        var loadedChannel: ChannelModel<DefaultDataTypes>? {
            database.viewContext.loadChannel(cid: channelId)
        }
        
        AssertAsync {
            // Channel details
            Assert.willBeEqual(channelId, loadedChannel?.cid)
            
            Assert.willBeEqual(payload.channel.extraData, loadedChannel?.extraData)
            Assert.willBeEqual(payload.channel.typeRawValue, loadedChannel?.type.rawValue)
            Assert.willBeEqual(payload.channel.lastMessageDate, loadedChannel?.lastMessageDate)
            Assert.willBeEqual(payload.channel.created, loadedChannel?.created)
            Assert.willBeEqual(payload.channel.updated, loadedChannel?.updated)
            Assert.willBeEqual(payload.channel.deleted, loadedChannel?.deleted)
            
            // Config
            Assert.willBeEqual(payload.channel.config.reactionsEnabled, loadedChannel?.config.reactionsEnabled)
            Assert.willBeEqual(payload.channel.config.typingEventsEnabled, loadedChannel?.config.typingEventsEnabled)
            Assert.willBeEqual(payload.channel.config.readEventsEnabled, loadedChannel?.config.readEventsEnabled)
            Assert.willBeEqual(payload.channel.config.connectEventsEnabled, loadedChannel?.config.connectEventsEnabled)
            Assert.willBeEqual(payload.channel.config.uploadsEnabled, loadedChannel?.config.uploadsEnabled)
            Assert.willBeEqual(payload.channel.config.repliesEnabled, loadedChannel?.config.repliesEnabled)
            Assert.willBeEqual(payload.channel.config.searchEnabled, loadedChannel?.config.searchEnabled)
            Assert.willBeEqual(payload.channel.config.mutesEnabled, loadedChannel?.config.mutesEnabled)
            Assert.willBeEqual(payload.channel.config.urlEnrichmentEnabled, loadedChannel?.config.urlEnrichmentEnabled)
            Assert.willBeEqual(payload.channel.config.messageRetention, loadedChannel?.config.messageRetention)
            Assert.willBeEqual(payload.channel.config.maxMessageLength, loadedChannel?.config.maxMessageLength)
            Assert.willBeEqual(payload.channel.config.commands, loadedChannel?.config.commands)
            Assert.willBeEqual(payload.channel.config.created, loadedChannel?.config.created)
            Assert.willBeEqual(payload.channel.config.updated, loadedChannel?.config.updated)
            
            // Creator
            Assert.willBeEqual(payload.channel.createdBy!.id, loadedChannel?.createdBy?.id)
            Assert.willBeEqual(payload.channel.createdBy!.created, loadedChannel?.createdBy?.userCreatedDate)
            Assert.willBeEqual(payload.channel.createdBy!.updated, loadedChannel?.createdBy?.userUpdatedDate)
            Assert.willBeEqual(payload.channel.createdBy!.lastActiveDate, loadedChannel?.createdBy?.lastActiveDate)
            Assert.willBeEqual(payload.channel.createdBy!.isOnline, loadedChannel?.createdBy?.isOnline)
            Assert.willBeEqual(payload.channel.createdBy!.isBanned, loadedChannel?.createdBy?.isBanned)
            Assert.willBeEqual(payload.channel.createdBy!.roleRawValue, loadedChannel?.createdBy?.userRole.rawValue)
            Assert.willBeEqual(payload.channel.createdBy!.extraData, loadedChannel?.createdBy?.extraData)
            Assert.willBeEqual(payload.channel.createdBy!.teams, loadedChannel?.createdBy?.teams)
            
            // Members
            Assert.willBeEqual(payload.members[0].roleRawValue, loadedChannel?.members.first?.channelRole.rawValue)
            Assert.willBeEqual(payload.members[0].created, loadedChannel?.members.first?.memberCreatedDate)
            Assert.willBeEqual(payload.members[0].updated, loadedChannel?.members.first?.memberUpdatedDate)
            
            Assert.willBeEqual(payload.members[0].user.id, loadedChannel?.members.first?.id)
            Assert.willBeEqual(payload.members[0].user.created, loadedChannel?.members.first?.userCreatedDate)
            Assert.willBeEqual(payload.members[0].user.updated, loadedChannel?.members.first?.userUpdatedDate)
            Assert.willBeEqual(payload.members[0].user.lastActiveDate, loadedChannel?.members.first?.lastActiveDate)
            Assert.willBeEqual(payload.members[0].user.isOnline, loadedChannel?.members.first?.isOnline)
            Assert.willBeEqual(payload.members[0].user.isBanned, loadedChannel?.members.first?.isBanned)
            Assert.willBeEqual(payload.members[0].user.roleRawValue, loadedChannel?.members.first?.userRole.rawValue)
            Assert.willBeEqual(payload.members[0].user.extraData, loadedChannel?.members.first?.extraData)
            Assert.willBeEqual(payload.members[0].user.teams, loadedChannel?.members.first?.teams)
            //      Assert.willBeEqual(payload.members[0].user.isInvisible, loadedChannel?.members.first?.isInvisible)
            //      Assert.willBeEqual(payload.members[0].user.devices, loadedChannel?.members.first?.devices)
            //      Assert.willBeEqual(payload.members[0].user.mutedUsers, loadedChannel?.members.first?.mutedUsers)
            //      Assert.willBeEqual(payload.members[0].user.unreadChannelsCount, loadedChannel?.members.first?.unreadChannelsCount)
            //      Assert.willBeEqual(payload.members[0].user.unreadMessagesCount, loadedChannel?.members.first?.unreadMessagesCount)
        }
    }
    
    func test_channelWithChannelListQuery_isSavedAndLoaded() {
        let query = ChannelListQuery(filter: .equal("name", to: "Luke Skywalker") & .less("age", than: 50))
        
        // Create two channels
        let channel1Id: ChannelId = .unique
        let payload1 = dummyPayload(with: channel1Id)
        
        let channel2Id: ChannelId = .unique
        let payload2 = dummyPayload(with: channel2Id)
        
        // Save the channels to DB, but only channel 1 is associated with the query
        database.write { session in
            try! session.saveChannel(payload: payload1, query: query)
            try! session.saveChannel(payload: payload2)
        }
        
        let fetchRequest = ChannelDTO.channelListFetchRequest(query: query)
        var loadedChannels: [ChannelDTO] {
            try! database.viewContext.fetch(fetchRequest)
        }
        
        AssertAsync {
            Assert.willBeEqual(loadedChannels.count, 1)
            Assert.willBeEqual(loadedChannels.first?.cid, channel1Id.rawValue)
        }
    }
    
    func test_channelListQuery_withSorting() {
        // Create two channels queries with different sortings.
        let filter = Filter.equal("some", to: String.unique)
        let queryWithDefaultSorting = ChannelListQuery(filter: filter)
        let queryWithCIDSorting = ChannelListQuery(filter: filter, sort: [.init(key: .cid, isAscending: true)])
        
        // Create dummy channels payloads with ids: a, b, c, d.
        let payload1 = dummyPayload(with: try! .init(cid: "a:a"))
        let payload2 = dummyPayload(with: try! .init(cid: "a:b"))
        let payload3 = dummyPayload(with: try! .init(cid: "a:c"))
        let payload4 = dummyPayload(with: try! .init(cid: "a:d"))
        
        // Get `lastMessageDate` and `created` dates from generated dummy channels and sort the for the default sorting.
        let createdAndLastMessageDates = [payload1, payload2, payload3, payload4]
            .map { $0.channel.lastMessageDate ?? $0.channel.created }
            .sorted(by: { $0 > $1 })
        
        // Save the channels to DB. It doesn't matter which query we use because the filter for both of them is the same.
        database.write { session in
            try! session.saveChannel(payload: payload1, query: queryWithDefaultSorting)
            try! session.saveChannel(payload: payload2, query: queryWithDefaultSorting)
            try! session.saveChannel(payload: payload3, query: queryWithDefaultSorting)
            try! session.saveChannel(payload: payload4, query: queryWithDefaultSorting)
        }
        
        // A fetch request with a default sorting.
        let fetchRequestWithDefaultSorting = ChannelDTO.channelListFetchRequest(query: queryWithDefaultSorting)
        // A fetch request with a sorting by `cid`.
        let fetchRequestWithCIDSorting = ChannelDTO.channelListFetchRequest(query: queryWithCIDSorting)
        
        var channelsWithDefaultSorting: [ChannelDTO] { try! database.viewContext.fetch(fetchRequestWithDefaultSorting) }
        var channelsWithCIDSorting: [ChannelDTO] { try! database.viewContext.fetch(fetchRequestWithCIDSorting) }
        
        AssertAsync {
            // Check the default sorting.
            Assert.willBeEqual(channelsWithDefaultSorting.count, 4)
            Assert.willBeEqual(channelsWithDefaultSorting.map { $0.lastMessageDate ?? $0.createdDate }, createdAndLastMessageDates)
            
            // Check the sorting by `cid`.
            Assert.willBeEqual(channelsWithCIDSorting.count, 4)
            Assert.willBeEqual(channelsWithCIDSorting.map { $0.cid }, ["a:a", "a:b", "a:c", "a:d"])
        }
    }
    
    /// `ChannelListSortingKey` test for sort descriptor and encoded value.
    func test_channelListSortingKey() {
        var channelListSortingKey = ChannelListSortingKey.default
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "updated_at")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true),
                       NSSortDescriptor(key: "defaultSortingDate", ascending: true))
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: false),
                       NSSortDescriptor(key: "defaultSortingDate", ascending: false))
        XCTAssertEqual(ChannelListSortingKey.defaultSortDescriptor, NSSortDescriptor(key: "defaultSortingDate", ascending: false))
        
        channelListSortingKey = .cid
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "cid")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true), NSSortDescriptor(key: "cid", ascending: true))
        
        channelListSortingKey = .type
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "type")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true),
                       NSSortDescriptor(key: "typeRawValue", ascending: true))
        
        channelListSortingKey = .createdDate
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "created_at")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true),
                       NSSortDescriptor(key: "createdDate", ascending: true))
        
        channelListSortingKey = .deletedDate
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "deleted_at")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true),
                       NSSortDescriptor(key: "deletedDate", ascending: true))
        
        channelListSortingKey = .lastMessageDate
        XCTAssertEqual(encodedChannelListSortingKey(channelListSortingKey), "last_message_at")
        XCTAssertEqual(channelListSortingKey.sortDescriptor(isAscending: true),
                       NSSortDescriptor(key: "lastMessageDate", ascending: true))
    }
    
    private func encodedChannelListSortingKey(_ sortingKey: ChannelListSortingKey) -> String {
        let encodedData = try! JSONEncoder.stream.encode(sortingKey)
        return String(data: encodedData, encoding: .utf8)!
            .trimmingCharacters(in: .init(charactersIn: "\""))
    }
    
    func test_channelPayload_withNoExtraData_isStoredAndLoadedFromDB() {
        let channelId: ChannelId = .unique
        
        let payload = dummyPayloadWithNoExtraData(with: channelId)
        
        // Asynchronously save the payload to the db
        database.write { session in
            try! session.saveChannel(payload: payload)
        }
        
        // Load the channel from the db and check the fields are correct
        var loadedChannel: ChannelModel<DefaultDataTypes>? {
            database.viewContext.loadChannel(cid: channelId)
        }
        
        AssertAsync {
            // Channel details
            Assert.willBeEqual(channelId, loadedChannel?.cid)
            
            Assert.willBeEqual(payload.channel.typeRawValue, loadedChannel?.type.rawValue)
            Assert.willBeEqual(payload.channel.lastMessageDate, loadedChannel?.lastMessageDate)
            Assert.willBeEqual(payload.channel.created, loadedChannel?.created)
            Assert.willBeEqual(payload.channel.updated, loadedChannel?.updated)
            Assert.willBeEqual(payload.channel.deleted, loadedChannel?.deleted)
            
            // Config
            Assert.willBeEqual(payload.channel.config.reactionsEnabled, loadedChannel?.config.reactionsEnabled)
            Assert.willBeEqual(payload.channel.config.typingEventsEnabled, loadedChannel?.config.typingEventsEnabled)
            Assert.willBeEqual(payload.channel.config.readEventsEnabled, loadedChannel?.config.readEventsEnabled)
            Assert.willBeEqual(payload.channel.config.connectEventsEnabled, loadedChannel?.config.connectEventsEnabled)
            Assert.willBeEqual(payload.channel.config.uploadsEnabled, loadedChannel?.config.uploadsEnabled)
            Assert.willBeEqual(payload.channel.config.repliesEnabled, loadedChannel?.config.repliesEnabled)
            Assert.willBeEqual(payload.channel.config.searchEnabled, loadedChannel?.config.searchEnabled)
            Assert.willBeEqual(payload.channel.config.mutesEnabled, loadedChannel?.config.mutesEnabled)
            Assert.willBeEqual(payload.channel.config.urlEnrichmentEnabled, loadedChannel?.config.urlEnrichmentEnabled)
            Assert.willBeEqual(payload.channel.config.messageRetention, loadedChannel?.config.messageRetention)
            Assert.willBeEqual(payload.channel.config.maxMessageLength, loadedChannel?.config.maxMessageLength)
            Assert.willBeEqual(payload.channel.config.commands, loadedChannel?.config.commands)
            Assert.willBeEqual(payload.channel.config.created, loadedChannel?.config.created)
            Assert.willBeEqual(payload.channel.config.updated, loadedChannel?.config.updated)
            
            // Creator
            Assert.willBeEqual(payload.channel.createdBy!.id, loadedChannel?.createdBy?.id)
            Assert.willBeEqual(payload.channel.createdBy!.created, loadedChannel?.createdBy?.userCreatedDate)
            Assert.willBeEqual(payload.channel.createdBy!.updated, loadedChannel?.createdBy?.userUpdatedDate)
            Assert.willBeEqual(payload.channel.createdBy!.lastActiveDate, loadedChannel?.createdBy?.lastActiveDate)
            Assert.willBeEqual(payload.channel.createdBy!.isOnline, loadedChannel?.createdBy?.isOnline)
            Assert.willBeEqual(payload.channel.createdBy!.isBanned, loadedChannel?.createdBy?.isBanned)
            Assert.willBeEqual(payload.channel.createdBy!.roleRawValue, loadedChannel?.createdBy?.userRole.rawValue)
            Assert.willBeEqual(payload.channel.createdBy!.teams, loadedChannel?.createdBy?.teams)
            
            // Members
            Assert.willBeEqual(payload.members[0].roleRawValue, loadedChannel?.members.first?.channelRole.rawValue)
            Assert.willBeEqual(payload.members[0].created, loadedChannel?.members.first?.memberCreatedDate)
            Assert.willBeEqual(payload.members[0].updated, loadedChannel?.members.first?.memberUpdatedDate)
            
            Assert.willBeEqual(payload.members[0].user.id, loadedChannel?.members.first?.id)
            Assert.willBeEqual(payload.members[0].user.created, loadedChannel?.members.first?.userCreatedDate)
            Assert.willBeEqual(payload.members[0].user.updated, loadedChannel?.members.first?.userUpdatedDate)
            Assert.willBeEqual(payload.members[0].user.lastActiveDate, loadedChannel?.members.first?.lastActiveDate)
            Assert.willBeEqual(payload.members[0].user.isOnline, loadedChannel?.members.first?.isOnline)
            Assert.willBeEqual(payload.members[0].user.isBanned, loadedChannel?.members.first?.isBanned)
            Assert.willBeEqual(payload.members[0].user.roleRawValue, loadedChannel?.members.first?.userRole.rawValue)
            Assert.willBeEqual(payload.members[0].user.teams, loadedChannel?.members.first?.teams)
            //      Assert.willBeEqual(payload.members[0].user.isInvisible, loadedChannel?.members.first?.isInvisible)
            //      Assert.willBeEqual(payload.members[0].user.devices, loadedChannel?.members.first?.devices)
            //      Assert.willBeEqual(payload.members[0].user.mutedUsers, loadedChannel?.members.first?.mutedUsers)
            //      Assert.willBeEqual(payload.members[0].user.unreadChannelsCount, loadedChannel?.members.first?.unreadChannelsCount)
            //      Assert.willBeEqual(payload.members[0].user.unreadMessagesCount, loadedChannel?.members.first?.unreadMessagesCount)
        }
    }
}

extension XCTestCase {
    func dummyPayload(with channelId: ChannelId) -> ChannelPayload<DefaultDataTypes> {
        let lukeExtraData = NameAndImageExtraData(name: "Luke", imageURL: URL(string: UUID().uuidString))
        
        let creator: UserPayload<NameAndImageExtraData> =
            .init(id: .unique,
                  created: .unique,
                  updated: .unique,
                  lastActiveDate: .unique,
                  isOnline: true,
                  isInvisible: true,
                  isBanned: true,
                  roleRawValue: "user",
                  extraData: lukeExtraData,
                  devices: [],
                  mutedUsers: [],
                  unreadChannelsCount: nil,
                  unreadMessagesCount: nil,
                  teams: [])
        
        let member: MemberPayload<NameAndImageExtraData> =
            .init(roleRawValue: "moderator",
                  created: .unique,
                  updated: .unique,
                  user: .init(id: .unique,
                              created: .unique,
                              updated: .unique,
                              lastActiveDate: .unique,
                              isOnline: true,
                              isInvisible: true,
                              isBanned: true,
                              roleRawValue: "admin",
                              extraData: lukeExtraData,
                              devices: [],
                              mutedUsers: [],
                              unreadChannelsCount: nil,
                              unreadMessagesCount: nil,
                              teams: []))
        
        let channelCreatedDate = Date.unique
        let lastMessageDate: Date? = Bool.random() ? channelCreatedDate.addingTimeInterval(.random(in: 100_000 ... 900_000)) : nil
        
        let payload: ChannelPayload<DefaultDataTypes> =
            .init(channel: .init(cid: channelId,
                                 extraData: .init(name: "Luke's channel", imageURL: URL(string: UUID().uuidString)),
                                 typeRawValue: channelId.type.rawValue,
                                 lastMessageDate: lastMessageDate,
                                 created: channelCreatedDate,
                                 deleted: .unique,
                                 updated: .unique,
                                 createdBy: creator,
                                 config: .init(reactionsEnabled: true,
                                               typingEventsEnabled: true,
                                               readEventsEnabled: true,
                                               connectEventsEnabled: true,
                                               uploadsEnabled: true,
                                               repliesEnabled: true,
                                               searchEnabled: true,
                                               mutesEnabled: true,
                                               urlEnrichmentEnabled: true,
                                               messageRetention: "1000",
                                               maxMessageLength: 100,
                                               commands: [
                                                   .init(name: "test",
                                                         description: "test commant",
                                                         set: "test",
                                                         args: "test")
                                               ],
                                               created: .unique,
                                               updated: .unique),
                                 isFrozen: true,
                                 memberCount: 100,
                                 team: "",
                                 members: nil),
                  watcherCount: 10,
                  members: [member])
        
        return payload
    }
    
    enum NoExtraDataTypes: ExtraDataTypes {
        typealias Channel = NoExtraData
        typealias Message = NoExtraData
        typealias User = NoExtraData
    }
    
    func dummyPayloadWithNoExtraData(with channelId: ChannelId) -> ChannelPayload<NoExtraDataTypes> {
        let creator: UserPayload<NoExtraData> =
            .init(id: .unique,
                  created: .unique,
                  updated: .unique,
                  lastActiveDate: .unique,
                  isOnline: true,
                  isInvisible: true,
                  isBanned: true,
                  roleRawValue: "user",
                  extraData: .init(),
                  devices: [],
                  mutedUsers: [],
                  unreadChannelsCount: nil,
                  unreadMessagesCount: nil,
                  teams: [])
        
        let member: MemberPayload<NoExtraData> =
            .init(roleRawValue: "moderator",
                  created: .unique,
                  updated: .unique,
                  user: .init(id: .unique,
                              created: .unique,
                              updated: .unique,
                              lastActiveDate: .unique,
                              isOnline: true,
                              isInvisible: true,
                              isBanned: true,
                              roleRawValue: "admin",
                              extraData: .init(),
                              devices: [],
                              mutedUsers: [],
                              unreadChannelsCount: nil,
                              unreadMessagesCount: nil,
                              teams: []))
        
        let payload: ChannelPayload<NoExtraDataTypes> =
            .init(channel: .init(cid: channelId,
                                 extraData: .init(),
                                 typeRawValue: channelId.type.rawValue,
                                 lastMessageDate: .unique,
                                 created: .unique,
                                 deleted: .unique,
                                 updated: .unique,
                                 createdBy: creator,
                                 config: .init(reactionsEnabled: true,
                                               typingEventsEnabled: true,
                                               readEventsEnabled: true,
                                               connectEventsEnabled: true,
                                               uploadsEnabled: true,
                                               repliesEnabled: true,
                                               searchEnabled: true,
                                               mutesEnabled: true,
                                               urlEnrichmentEnabled: true,
                                               messageRetention: "1000",
                                               maxMessageLength: 100,
                                               commands: [
                                                   .init(name: "test",
                                                         description: "test commant",
                                                         set: "test",
                                                         args: "test")
                                               ],
                                               created: .unique,
                                               updated: .unique),
                                 isFrozen: true,
                                 memberCount: 100,
                                 team: "",
                                 members: nil),
                  watcherCount: 10,
                  members: [member])
        
        return payload
    }
}