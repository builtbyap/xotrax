import Foundation

struct Hole: Identifiable, Codable, Hashable {
    var number: Int
    var par: Int
    var yards: Double
    var fairwayWidth: Double = 35   // yards
    var greenRadius: Double = 14    // yards
    /// Lateral bend of the fairway at its midpoint (yards, + = dogleg right). Visual only.
    var dogleg: Double = 0
    var id: Int { number }
}

struct Course: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var location: String
    var holes: [Hole]
    var par: Int { holes.reduce(0) { $0 + $1.par } }
    var yards: Int { Int(holes.reduce(0) { $0 + $1.yards }) }

    /// Fictional built-in courses. Add your own here or load from JSON later.
    static let builtIn: [Course] = [
        Course(name: "Pine Hollow", location: "Parkland · 9 holes", holes: [
            Hole(number: 1, par: 4, yards: 385, dogleg: 12),
            Hole(number: 2, par: 3, yards: 165),
            Hole(number: 3, par: 5, yards: 520, fairwayWidth: 40, dogleg: -20),
            Hole(number: 4, par: 4, yards: 410, fairwayWidth: 30),
            Hole(number: 5, par: 4, yards: 350, dogleg: 15),
            Hole(number: 6, par: 3, yards: 190, greenRadius: 12),
            Hole(number: 7, par: 5, yards: 545, dogleg: 18),
            Hole(number: 8, par: 4, yards: 430, fairwayWidth: 32, dogleg: -10),
            Hole(number: 9, par: 4, yards: 400),
        ]),
        Course(name: "Coastal Links", location: "Links · 9 holes", holes: [
            Hole(number: 1, par: 4, yards: 420, fairwayWidth: 45, dogleg: -8),
            Hole(number: 2, par: 5, yards: 560, fairwayWidth: 45),
            Hole(number: 3, par: 3, yards: 145, greenRadius: 11),
            Hole(number: 4, par: 4, yards: 455, fairwayWidth: 40, dogleg: 14),
            Hole(number: 5, par: 4, yards: 330, fairwayWidth: 38),
            Hole(number: 6, par: 3, yards: 210),
            Hole(number: 7, par: 4, yards: 440, fairwayWidth: 42, dogleg: -15),
            Hole(number: 8, par: 5, yards: 505, fairwayWidth: 44, dogleg: 10),
            Hole(number: 9, par: 4, yards: 470, fairwayWidth: 40),
        ]),
        Course(name: "Short Course", location: "Par 3 · 9 holes", holes: [
            Hole(number: 1, par: 3, yards: 95),
            Hole(number: 2, par: 3, yards: 120),
            Hole(number: 3, par: 3, yards: 140),
            Hole(number: 4, par: 3, yards: 110),
            Hole(number: 5, par: 3, yards: 155),
            Hole(number: 6, par: 3, yards: 85),
            Hole(number: 7, par: 3, yards: 130),
            Hole(number: 8, par: 3, yards: 165),
            Hole(number: 9, par: 3, yards: 105),
        ]),
    ]
}
