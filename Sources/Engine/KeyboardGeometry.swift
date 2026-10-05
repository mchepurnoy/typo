/// Where the letter keys sit on a Mac keyboard (ANSI), to tell a slip of the finger onto a
/// neighbouring key from any other change of letter.
public enum KeyboardGeometry {
    /// Rows of virtual keycodes, top to bottom, and how far each row is shifted right, in keys.
    private static let rows: [(codes: [UInt16], offset: Double)] = [
        ([12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30], 0),  // q w e r t y u i o p [ ]
        ([0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39], 0.25),  // a s d f g h j k l ; '
        ([6, 7, 8, 9, 11, 45, 46, 43, 47, 44], 0.75),  // z x c v b n m , . /
    ]

    private static let positions: [UInt16: (x: Double, y: Double)] = {
        var positions: [UInt16: (x: Double, y: Double)] = [:]
        for (y, row) in rows.enumerated() {
            for (x, code) in row.codes.enumerated() { positions[code] = (Double(x) + row.offset, Double(y)) }
        }
        return positions
    }()

    /// Whether two keys touch: next to each other in a row, or diagonally in the next row.
    public static func areNeighbours(_ a: UInt16, _ b: UInt16) -> Bool {
        guard a != b, let p = positions[a], let q = positions[b] else { return false }
        return abs(p.y - q.y) <= 1 && abs(p.x - q.x) <= (p.y == q.y ? 1 : 0.75)
    }

    /// The keys touching `code`.
    public static func neighbours(of code: UInt16) -> [UInt16] {
        positions.keys.filter { areNeighbours(code, $0) }.sorted()
    }
}
