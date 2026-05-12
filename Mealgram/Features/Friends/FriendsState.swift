import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class FriendsState {
    private(set) var friends: [PublicProfile] = []
    private(set) var incoming: [FriendRequest] = []
    private(set) var outgoing: [FriendRequest] = []
    private(set) var feed: [FeedEvent] = []
    private(set) var searchResults: [PublicProfile] = []
    var searchQuery: String = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: any FriendService
    let userRemoteID: String

    init(service: any FriendService, userRemoteID: String) {
        self.service = service
        self.userRemoteID = userRemoteID
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let friends = service.friends(of: userRemoteID)
            async let incoming = service.pendingIncoming(for: userRemoteID)
            async let outgoing = service.pendingOutgoing(for: userRemoteID)
            async let feed = service.recentFeed(for: userRemoteID, limit: 30)
            self.friends = try await friends
            self.incoming = try await incoming
            self.outgoing = try await outgoing
            self.feed = try await feed
            self.errorMessage = nil
        } catch {
            Logger.persistence.error("Friends refresh failed: \(String(describing: error))")
            errorMessage = String(describing: error)
        }
    }

    func runSearch() async {
        do {
            searchResults = try await service.search(query: searchQuery, excluding: userRemoteID)
        } catch {
            searchResults = []
        }
    }

    func sendRequest(to profile: PublicProfile) async {
        do {
            _ = try await service.sendRequest(from: userRemoteID, to: profile.id)
            await refresh()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func accept(_ request: FriendRequest) async {
        try? await service.accept(request: request, as: userRemoteID)
        await refresh()
    }

    func reject(_ request: FriendRequest) async {
        try? await service.reject(request: request, as: userRemoteID)
        await refresh()
    }

    func unfriend(_ profile: PublicProfile) async {
        try? await service.unfriend(profile.id, as: userRemoteID)
        await refresh()
    }

    func toggleReaction(on event: FeedEvent, kind: ReactionKind) async {
        let next: ReactionKind? = event.myReaction == kind ? nil : kind
        do {
            let updated = try await service.react(to: event, as: userRemoteID, kind: next)
            if let index = feed.firstIndex(where: { $0.id == updated.id }) {
                feed[index] = updated
            }
        } catch {
            // Soft fail.
        }
    }
}
