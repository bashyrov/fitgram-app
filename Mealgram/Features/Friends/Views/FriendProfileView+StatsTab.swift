import SwiftUI

/// "Stats" tab + supporting tiles. Renders only the metrics present
/// in the snapshot — empties out to a placeholder when nothing is shared.
extension FriendProfileView {
    struct StatTile: Identifiable {
        let id: String
        let symbol: String
        let value: String
        let unit: String
        let label: LocalizedStringKey
        let tint: Color
    }

    @ViewBuilder
    func statsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        let tiles = statTiles(snapshot)
        if tiles.isEmpty {
            placeholder(
                symbol: "chart.bar.fill",
                title: "Brak statystyk",
                subtitle: "Ta osoba nie udostępnia jeszcze swoich liczb."
            )
        } else {
            VStack(spacing: Tokens.Space.md) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                    ],
                    spacing: Tokens.Space.md
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
                    unit: "kg",
                    label: "Aktualna waga",
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
                    label: "Aktualna seria",
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
                    label: "Achievements",
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
                    label: "Poziom",
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
                unit: "kcal",
                label: "Średnia dzienna",
                tint: Tokens.Palette.error
            ),
            StatTile(
                id: "scans",
                symbol: "camera.viewfinder",
                value: "\(weekly.totalScans)",
                unit: "",
                label: "Skany w tygodniu",
                tint: Tokens.Palette.success
            ),
            StatTile(
                id: "daysHit",
                symbol: "target",
                value: "\(weekly.daysHitGoal)",
                unit: "/ 7",
                label: "Dni z celem",
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
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tile.tint, tile.tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: tile.tint.opacity(0.35), radius: 6, y: 2)
                Image(systemName: tile.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(tile.value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !tile.unit.isEmpty {
                    Text(tile.unit)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Text(tile.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tile.tint.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: tile.tint.opacity(0.10), radius: 14, y: 8)
    }

    func topFoodsCard(_ foods: [String]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
                Text("Top produkty")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
            }
            ForEach(Array(foods.enumerated()), id: \.offset) { idx, food in
                HStack(spacing: Tokens.Space.sm) {
                    Text("\(idx + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Tokens.Palette.primary))
                    Text(food)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                }
                if idx < foods.count - 1 {
                    Rectangle()
                        .fill(Tokens.Palette.separator.opacity(0.7))
                        .frame(height: 0.5)
                        .padding(.leading, 34)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.07), radius: 16, y: 9)
    }
}
