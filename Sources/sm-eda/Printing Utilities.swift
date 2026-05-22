//
//  Printing Utilities.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

func printItems(
    title: String = "",
    _ table: [(key: String, value: String)],
    numbered: Bool,
    minKeyWidth: Int = 25
) {
    print(title + ":")
    var maxKey: Int = max(minKeyWidth, 0)
    for (key, _) in table {
        maxKey = max(key.count, maxKey)
    }
    if numbered {
        let digits = "\(table.count)".count
        for (index, (key, value)) in table.enumerated() {
            let prefix = (index + 1).description.padding(to: digits, left: true)
            let key = (key + ":").padding(to: maxKey - digits)
            print("   \(prefix). \(key) \(value)")
        }
    } else {
        for (key, value) in table {
            let key = (key + ":").padding(to: maxKey + 2)
            print("   \(key) \(value)")
        }
    }
}

func timeFromTicks(_ time: Int?, nilName: String = "--") -> String {
    if let time = time {
        let realTime = (Float(time) / Float(kSMFrameRate))
        return "\(time.description) (\(realTime)s)"
    } else {
        return nilName
    }
}
