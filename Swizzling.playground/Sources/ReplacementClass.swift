import Foundation

public class ReplacementClass {
    public init() {}
    
    public func replacedMethod1() {
        print("Invoked replacement method: replacedMethod1(): self = \(self)")
    }
    
    public func replacedMethod2(param1: Bool) -> Bool {
        print("replacedMethod2(): self = \(self)")
        
        let originalSelf: MyClass = ((self as Any) as! MyClass)
        // print(originalSelf.originalClassVar)
        
        return param1
    }

}
