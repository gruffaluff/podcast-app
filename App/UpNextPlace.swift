import Foundation

/// "1st", "2nd", "3rd", "11th" … for places in Up next and rankings.
enum UpNextPlace {
    static func ordinal(_ n: Int) -> String {
        let tens = n % 100
        let suffix = (11...13).contains(tens) ? "th" : (n % 10 == 1 ? "st" : n % 10 == 2 ? "nd" : n % 10 == 3 ? "rd" : "th")
        return "\(n)\(suffix)"
    }
}
