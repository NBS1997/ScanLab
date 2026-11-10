import Foundation

/// A candidate edge merge waiting in the simplifier's queue.
///
/// The stamps record each vertex's version when the entry was made. Whenever a vertex
/// changes, its version goes up, so any older entry that mentions it no longer
/// matches and is skipped when it comes out of the queue. That is cheaper than
/// finding and removing old entries ("lazy deletion"). Indices are 32-bit to keep the
/// queue small on the phone.
struct EdgeEntry: Sendable {
    var cost: Double
    var low: Int32
    var high: Int32
    var lowStamp: Int32
    var highStamp: Int32

    /// Lowest cost first. Equal costs are ordered by vertex numbers, so the result
    /// is always the same for the same mesh.
    func comesBefore(_ other: EdgeEntry) -> Bool {
        if cost != other.cost { return cost < other.cost }
        if low != other.low { return low < other.low }
        return high < other.high
    }
}

/// A binary min-heap: the cheapest entry is always at the front, and adding or
/// taking one costs time proportional to the logarithm of the size, which keeps the
/// simplifier fast on large meshes.
struct EdgeHeap: Sendable {
    private var items: [EdgeEntry] = []

    var count: Int { items.count }

    var isEmpty: Bool { items.isEmpty }

    mutating func reserve(_ capacity: Int) {
        items.reserveCapacity(capacity)
    }

    mutating func push(_ entry: EdgeEntry) {
        items.append(entry)
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard items[child].comesBefore(items[parent]) else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> EdgeEntry? {
        guard let first = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            siftDown()
        }
        return first
    }

    private mutating func siftDown() {
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var smallest = parent
            if left < items.count && items[left].comesBefore(items[smallest]) { smallest = left }
            if right < items.count && items[right].comesBefore(items[smallest]) { smallest = right }
            if smallest == parent { return }
            items.swapAt(parent, smallest)
            parent = smallest
        }
    }
}
