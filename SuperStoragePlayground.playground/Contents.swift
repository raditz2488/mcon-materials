import UIKit

func chunkCount(for size: Int) {
    let doubleDivision = Double(size) / 20
    print("Double quotient: \(doubleDivision)")
    print("Double to int quotient: \(Int(doubleDivision))")
    let chunkCount = max(Int(Double(size) / 20), 1)
    print("chunkCount for size \(size):", chunkCount)
    print("---------------------------")
}

chunkCount(for: 10)
chunkCount(for: 19)
chunkCount(for: 20)
chunkCount(for: 21)
chunkCount(for: 30)
chunkCount(for: 40)
