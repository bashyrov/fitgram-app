import Foundation
import OSLog

/// Direct hit to the public Open Food Facts v2 API. No auth required.
/// Caching is best-effort by URLSession's HTTP cache — the Worker-proxied
/// version (Milestone 1.6 extension) layers a 30-day cache on top so we
/// don't hammer their servers from millions of devices.
///
/// API: `https://world.openfoodfacts.org/api/v2/product/<barcode>.json`
/// Returns `status: 1` on hit, `status: 0` (or 404) otherwise.
struct OpenFoodFactsLookup: BarcodeLookupService {
    let session: URLSession
    let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org") ?? URL(filePath: "/")
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func lookup(barcode: String) async throws -> BarcodeProduct {
        let url = baseURL.appending(path: "api/v2/product/\(barcode).json")
        var request = URLRequest(url: url)
        request.setValue("Mealgram/0.1 (https://mealgram.xyz)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw BarcodeLookupError.network(urlError.localizedDescription)
        } catch {
            throw BarcodeLookupError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw BarcodeLookupError.notFound
        }

        let decoder = JSONDecoder()
        let envelope: OFFEnvelope
        do {
            envelope = try decoder.decode(OFFEnvelope.self, from: data)
        } catch {
            Logger.networking.error("OFF decode failed: \(String(describing: error))")
            throw BarcodeLookupError.network("Decode failed")
        }

        guard envelope.status == 1, let product = envelope.product else {
            throw BarcodeLookupError.notFound
        }
        return try Self.makeProduct(from: product, barcode: barcode)
    }

    // MARK: - Mapping

    static func makeProduct(from product: OFFProduct, barcode: String) throws -> BarcodeProduct {
        let nutriments = product.nutriments

        guard let calories = nutriments.kcal100g else {
            throw BarcodeLookupError.missingNutrition
        }

        let name = product.localizedName ?? product.productName ?? product.genericName ?? barcode
        let brand = product.brands?
            .split(separator: ",")
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        let imageURL = product.imageURL.flatMap(URL.init(string:))

        return BarcodeProduct(
            barcode: barcode,
            name: name,
            brand: brand,
            imageURL: imageURL,
            nutrition: .init(
                caloriesKcalPer100g: calories,
                proteinPer100g: nutriments.protein100g ?? 0,
                carbsPer100g: nutriments.carbs100g ?? 0,
                fatPer100g: nutriments.fat100g ?? 0,
                fiberPer100g: nutriments.fiber100g
            ),
            servingGrams: product.servingQuantity
        )
    }
}

// MARK: - Wire format

/// Top-level envelope returned by OFF's v2 product endpoint.
struct OFFEnvelope: Decodable, Sendable {
    let status: Int
    let product: OFFProduct?
}

struct OFFProduct: Decodable, Sendable {
    let productName: String?
    let productNamePL: String?
    let productNameEN: String?
    let genericName: String?
    let brands: String?
    let imageURL: String?
    let servingQuantity: Double?
    let nutriments: OFFNutriments

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNamePL = "product_name_pl"
        case productNameEN = "product_name_en"
        case genericName = "generic_name"
        case brands
        case imageURL = "image_url"
        case servingQuantity = "serving_quantity"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productNamePL = try container.decodeIfPresent(String.self, forKey: .productNamePL)
        productNameEN = try container.decodeIfPresent(String.self, forKey: .productNameEN)
        genericName = try container.decodeIfPresent(String.self, forKey: .genericName)
        brands = try container.decodeIfPresent(String.self, forKey: .brands)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        servingQuantity = try Self.decodeOptionalDouble(container, key: .servingQuantity)
        nutriments = try container.decode(OFFNutriments.self, forKey: .nutriments)
    }

    /// Prefer Polish, fall back to English, then the generic field. OFF
    /// sometimes returns this as a number rather than string when the
    /// product was bulk-imported, so we accept both.
    var localizedName: String? {
        if let pl = productNamePL, !pl.isEmpty { return pl }
        if let en = productNameEN, !en.isEmpty { return en }
        return nil
    }

    fileprivate static func decodeOptionalDouble(
        _ container: KeyedDecodingContainer<OFFProduct.CodingKeys>,
        key: OFFProduct.CodingKeys
    ) throws -> Double? {
        if let direct = try? container.decodeIfPresent(Double.self, forKey: key) { return direct }
        if let asString = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(asString.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

/// OFF puts ~100 nutrient fields here. We only consume the ones the app
/// renders today. Numeric fields are double-encoded in places (string vs
/// number) so we accept both via the helper.
struct OFFNutriments: Decodable, Sendable {
    let kcal100g: Double?
    let protein100g: Double?
    let carbs100g: Double?
    let fat100g: Double?
    let fiber100g: Double?

    enum CodingKeys: String, CodingKey {
        case kcal100g = "energy-kcal_100g"
        case protein100g = "proteins_100g"
        case carbs100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kcal100g = try Self.decode(container, .kcal100g)
        protein100g = try Self.decode(container, .protein100g)
        carbs100g = try Self.decode(container, .carbs100g)
        fat100g = try Self.decode(container, .fat100g)
        fiber100g = try Self.decode(container, .fiber100g)
    }

    private static func decode(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> Double? {
        if let direct = try? container.decodeIfPresent(Double.self, forKey: key) { return direct }
        if let asString = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(asString.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}
