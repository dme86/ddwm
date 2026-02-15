import Foundation
import AppKit

public protocol DdwmAny {}

extension DdwmAny {
    @discardableResult
    @inlinable
    public func apply(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @discardableResult
    @inlinable
    public func also(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @inlinable public func takeIf(_ predicate: (Self) -> Bool) -> Self? { predicate(self) ? self : nil }
    @inlinable public func then<R>(_ body: (Self) -> R) -> R { body(self) }
}

extension Int: DdwmAny {}
extension String: DdwmAny {}
extension Character: DdwmAny {}
extension Regex: DdwmAny {}
extension Array: DdwmAny {}
extension URL: DdwmAny {}
extension CGFloat: DdwmAny {}
extension AXUIElement: DdwmAny {}
extension CGPoint: DdwmAny {}
