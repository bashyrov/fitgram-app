import XCTest

@testable import Fitgram

/// Decodes rows exactly as PostgREST returns them (snake_case), with the
/// same decoder SupabaseRESTClient uses.
final class SupabaseFriendRowsTests: XCTestCase {
    func testPublicProfileRowDecodesPostgRESTKeys() throws {
        let json = """
            [{"user_id":"7d0c4a8e-1111-4c7e-9a40-0f3a1b2c3d4e","username":"kasia.nowak",\
            "display_name":"Kasia Nowak","photo_url":null,"bio":"Biegam rano",\
            "created_at":"2026-10-08T22:10:11.123456+00:00"}]
            """
        let rows = try JSONDecoder.fitgram.decode([PublicProfileRow].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.userID, "7d0c4a8e-1111-4c7e-9a40-0f3a1b2c3d4e")
        XCTAssertEqual(rows.first?.toPublicProfile.displayName, "Kasia Nowak")
    }

    func testActivityAndReactionRowsDecodePostgRESTKeys() throws {
        let event = """
            [{"id":"0b1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d","user_id":"7d0c4a8e-1111-4c7e-9a40-0f3a1b2c3d4e",\
            "event_type":"streak.milestone","event_data":{"title":"Seria 21 dni","summary":"21 dni z rzędu"},\
            "created_at":"2026-10-08T20:00:00+00:00"}]
            """
        let events = try JSONDecoder.fitgram.decode([ActivityEventRow].self, from: Data(event.utf8))
        XCTAssertEqual(events.first?.userID, "7d0c4a8e-1111-4c7e-9a40-0f3a1b2c3d4e")
        XCTAssertEqual(events.first?.eventData.summary, "21 dni z rzędu")

        let reaction = """
            [{"from_user":"a","event_id":"0b1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d","reaction_type":"heart"}]
            """
        let reactions = try JSONDecoder.fitgram.decode([ReactionRow].self, from: Data(reaction.utf8))
        XCTAssertNotNil(reactions.first?.eventID)
    }
}
