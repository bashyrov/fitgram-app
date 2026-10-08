import SwiftUI

/// "Stats" tab + supporting tiles. Renders only the metrics present
/// in the snapshot — empties out to a placeholder when nothing is shared.
extension FriendProfileView {
    struct StatTile: Identifiable {
        let id: String
        let symbol: String
        let value: String
        let unit: String
        let label: String
        let tint: Color
    }

    @ViewBuilder
    func statsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        // Streak / badges / level already sit in the identity tiles above the tabs.
        let tiles = statTiles(snapshot).filter { !["streak", "badges", "level"].contains($0.id) }
        if tiles.isEmpty && (snapshot.weeklyStats?.topFoods ?? []).isEmpty {
            placeholder(
                symbol: "chart.bar.fill",
                title: L("Brak statystyk"),
                subtitle: L("Ta osoba nie udostępnia jeszcze swoich liczb.")
            )
        } else {
            VStack(spacing: 10) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    ForEach(tiles, id: \.id) { tile in
                        statTile(tile)
                    }
                }
                if let foods = snapshot.weeklyStats?.topFoods, !foods.isEmpty {
                    topFoodsCard(foods)
                }
            }
        }
    }

    func statTiles(_ snapshot: FriendProfileSnapshot) -> [StatTile] {
        var tiles: [StatTile] = []
        tiles.append(contentsOf: identityStatTiles(snapshot))
        tiles.append(contentsOf: weeklyStatTiles(snapshot.weeklyStats))
        if let weight = snapshot.weightKg {
            tiles.append(
                StatTile(
                    id: "weight",
                    symbol: "scalemass.fill",
                    value: String(format: "%.1f", weight),
                    unit: L("kg"),
                    label: L("Aktualna waga"),
                    tint: Tokens.Palette.success
                ))
        }
        return tiles
    }

    private func identityStatTiles(_ snapshot: FriendProfileSnapshot) -> [StatTile] {
        var tiles: [StatTile] = []
        if let streak = snapshot.currentStreak {
            tiles.append(
                StatTile(
                    id: "streak",
                    symbol: "flame.fill",
                    value: "\(streak)",
                    unit: L("dni"),
                    label: L("Aktualna seria"),
                    tint: Tokens.Palette.warning
                ))
        }
        if let achievements = snapshot.achievements {
            tiles.append(
                StatTile(
                    id: "badges",
                    symbol: "rosette",
                    value: "\(achievements.count)",
                    unit: "",
                    label: L("Achievements"),
                    tint: Tokens.Palette.accent
                ))
        }
        if let level = snapshot.level {
            tiles.append(
                StatTile(
                    id: "level",
                    symbol: "star.fill",
                    value: "\(level.number)",
                    unit: level.label,
                    label: L("Poziom"),
                    tint: Tokens.Palette.primary
                ))
        }
        return tiles
    }

    private func weeklyStatTiles(_ weekly: WeeklyStats?) -> [StatTile] {
        guard let weekly else { return [] }
        return [
            StatTile(
                id: "avgKcal",
                symbol: "bolt.heart.fill",
                value: formattedThousands(weekly.averageDailyKcal),
                unit: L("kcal"),
                label: L("Średnia dzienna"),
                tint: Tokens.Palette.error
            ),
            StatTile(
                id: "scans",
                symbol: "camera.viewfinder",
                value: "\(weekly.totalScans)",
                unit: "",
                label: L("Skany w tygodniu"),
                tint: Tokens.Palette.success
            ),
            StatTile(
                id: "daysHit",
                symbol: "target",
                value: "\(weekly.daysHitGoal)",
                unit: "/ 7",
                label: L("Dni z celem"),
                tint: Tokens.Palette.primary
            ),
        ]
    }

    func formattedThousands(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func statTile(_ tile: StatTile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: tile.label)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(tile.value)
                    .font(Tokens.Font.monoNumber(26))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !tile.unit.isEmpty {
                    Text(tile.unit)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineLimit(1)
                }
            }
        }
        .monoTile()
        .accessibilityElement(children: .combine)
    }

    func topFoodsCard(_ foods: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Top produkty"))
            VStack(spacing: 0) {
                ForEach(Array(foods.enumerated()), id: \.offset) { idx, food in
                    if idx > 0 {
                        MonoRowDivider(inset: 36)
                    }
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(Tokens.Font.monoNumber(16))
                            .foregroundStyle(Tokens.Mono.muted)
                            .frame(width: 24, alignment: .leading)
                        Text(food)
                            .font(Tokens.Font.manrope(15, weight: 700))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .monoCard(padding: 16)
    }
}
