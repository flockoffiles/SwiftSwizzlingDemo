import Foundation

// Create our sample class instance.
// We need this to get the implementation address of the method to be swizzled.
let myClass = MyClass.init()

// Create the replacement class instance.
// We need this to get the implementation address of the method to be swizzled.
let replacementClass = ReplacementClass()

// Obtain the implementation address of the method to be swizzled.
// Please note that the technique to obtain the implementation address depends on the kind of method, applied optimization, etc.
// There is no universal recipe, and sometimes it's not even possible.
// If there are many different parameters, Swift compiler may generate multiple reabstraction thunks which call each other
// before actually getting to the final implementation (which has normalized representation for parameters).
// Therefore, the way to obtain the method address will also depend on the compiler version.
// So: the methods of Util are not reliable! Use at your own risk.
guard let orgAddress = Util.methodAddress(myClass.method1) else {
    abort()
}

print("Address of the original method: \(orgAddress)")

guard let replacementAddress = Util.methodAddress(replacementClass.replacedMethod1) else {
    abort()
}

print("Address of the replacement method: \(replacementAddress)\n\n")

// This is how we can see if we got the right address.
// We just obtain the human readable method name and print it.
let orgMethodName = swiftDemangle(orgAddress)
print("Name of the original method: \(orgMethodName)")

// Do the same with the replacement method address.
let replacementMethodName = swiftDemangle(replacementAddress)
print("Name of the replacement method: \(replacementMethodName)\n\n")

// Call original method.
// At this point we expect the following to be printed: "Invoked original method: method1(): self = Swizzling_Sources.MyClass"
myClass.method1()


// Now get the vTable of MyClass and print its entries.
// Among the entries you should find one with the demangled name "Swizzling_Sources.MyClass.method1() -> ()"
let vTable1 = VirtualTable(MyClass.self)
print("\n\nVirtual table for MyClass before swizzling:\n\(vTable1!.entries)")

let result = swizzleMethod(for: MyClass.self, address: IMP(orgAddress), replacementAddress: IMP(replacementAddress))
print("\n\nPerformed swizzling: \(result)")

// Print the vTable again to verify that the relevant entry was replaced.
let vTable2 = VirtualTable(MyClass.self)
print("\n\nVirtual table for MyClass after swizzling:\n\(vTable2!.entries)\n")

// Call method1() and observe that the implementation of replacedMethod1() was called instead.
myClass.method1()

