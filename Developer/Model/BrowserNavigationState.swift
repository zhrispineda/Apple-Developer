//
//  BrowserNavigationState.swift
//  Developer
//

import Foundation

struct BrowserNavigationState<Location: Hashable> {
    private(set) var current: Location
    private(set) var backStack: [Location] = []
    private(set) var forwardStack: [Location] = []
    var maxCount = 100

    init(current: Location) {
        self.current = current
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func navigate(to location: Location) {
        guard location != current else { return }
        backStack.append(current)
        if backStack.count > maxCount { backStack.removeFirst() }
        forwardStack = []
        current = location
    }

    mutating func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        current = previous
    }

    mutating func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(current)
        current = next
    }

    mutating func goBack(to location: Location) {
        forwardStack.append(current)
        if backStack.last == location { backStack.removeLast() }
        current = location
    }
}
