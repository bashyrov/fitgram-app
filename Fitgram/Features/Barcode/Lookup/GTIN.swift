import Foundation

/// Retail product codes (EAN-8, UPC-E, UPC-A, EAN-13, GTIN-14). Camera reads
/// of packaging regularly produce partial or non-product codes; only values
/// that pass the GS1 check digit are worth a database lookup.
enum GTIN {
    /// Digits-only, check-digit-valid code. 8-digit values stay as read
    /// (EAN-8 or UPC-E); `lookupCandidates` adds the expanded UPC-A form.
    /// `nil` for anything that isn't a retail product code.
    static func normalize(_ raw: String) -> String? {
        let digits = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty, digits.allSatisfy(\.isASCIIDigit) else { return nil }
        switch digits.count {
        case 8:
            let validUPCE = expandUPCE(digits).map(isValid) ?? false
            return isValid(digits) || validUPCE ? digits : nil
        case 12, 13, 14:
            return isValid(digits) ? digits : nil
        default:
            return nil
        }
    }

    /// Codes to try against the product database, most specific first.
    /// UPC-A and its zero-padded EAN-13 form name the same product, but
    /// databases often store only one of them.
    static func lookupCandidates(for code: String) -> [String] {
        var result = [code]
        if code.count == 8 {
            if let upcA = expandUPCE(code), isValid(upcA) {
                result += [upcA, "0" + upcA]
            }
        } else if code.count == 12 {
            result.append("0" + code)
        } else if code.count == 13, code.hasPrefix("0") {
            result.append(String(code.dropFirst()))
        } else if code.count == 14, code.hasPrefix("0") {
            result.append(String(code.dropFirst()))
        }
        return result
    }

    /// GS1 mod-10: weights 3,1,3,… from the digit left of the check digit.
    static func isValid(_ digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard values.count == digits.count, let check = values.last else { return false }
        var sum = 0
        for (offset, value) in values.dropLast().reversed().enumerated() {
            sum += value * (offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

    /// UPC-E (number system + 6 digits + check) → 12-digit UPC-A.
    static func expandUPCE(_ code: String) -> String? {
        let digits = code.compactMap(\.wholeNumberValue)
        guard digits.count == 8, digits[0] == 0 || digits[0] == 1 else { return nil }
        let system = digits[0]
        let body = Array(digits[1...6])
        let check = digits[7]
        let manufacturer: [Int]
        let product: [Int]
        switch body[5] {
        case 0, 1, 2:
            manufacturer = [body[0], body[1], body[5], 0, 0]
            product = [0, 0, body[2], body[3], body[4]]
        case 3:
            manufacturer = [body[0], body[1], body[2], 0, 0]
            product = [0, 0, 0, body[3], body[4]]
        case 4:
            manufacturer = [body[0], body[1], body[2], body[3], 0]
            product = [0, 0, 0, 0, body[4]]
        default:
            manufacturer = [body[0], body[1], body[2], body[3], body[4]]
            product = [0, 0, 0, 0, body[5]]
        }
        return ([system] + manufacturer + product + [check]).map(String.init).joined()
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
