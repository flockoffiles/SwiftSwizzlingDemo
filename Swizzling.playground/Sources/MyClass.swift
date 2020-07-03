import Foundation

public class MyClass {
    public init() {
    }
    
    public var someProperty = "Instance variable"
    
    public func method1() {
        print("Invoked original method: method1(): self = \(self)")
    }
    
    public final func method2(param1: Bool) -> Bool {
        print("method2(): self = \(self)")
        return param1
    }
}












public final class MyFinalClass {
    public init() {
    }
    
    public func method1() {
        print("Invoked original method: method1(): self = \(self)")
    }
}
