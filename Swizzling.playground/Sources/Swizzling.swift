import Foundation
import MachO

/// Helper class to hold information retrieved from some class' virtual table.
public class VirtualTable {
    /// Single entry
    public struct VTableEntry {
        /// Mangled symbol name
        var mangledName: String
        /// Demangled name (more readable)
        var demangledName: String
        /// Function/method implementation address
        var address: IMP
    }
    
    public var entries: [VTableEntry]
    
    public init?(_ aClass: AnyClass) {
        let swiftClassPtr = unsafeBitCast(aClass, to: UnsafeMutablePointer<TargetClassMetadata>.self)
        
        let symStart: UnsafeMutablePointer<IMP?> = withUnsafeMutablePointer(to: &swiftClassPtr.pointee.iVarDestroyer) { $0 }
        let swiftClassStart = swiftClassPtr.withMemoryRebound(to: UInt8.self, capacity: 1) { $0 }
        let symEnd = (swiftClassStart
            - Int(swiftClassPtr.pointee.classAddressPoint)
            + Int(swiftClassPtr.pointee.classSize)).withMemoryRebound(to: Optional<IMP>.self, capacity: 1) { $0 }
        
        entries = [VTableEntry]()
        for i in 0..<(symEnd - symStart) {
            guard let fPtr = symStart[i] else {
                continue
            }
            let vPtr = unsafeBitCast(fPtr, to: UnsafeRawPointer.self)
            var info = Dl_info()
            if dladdr(vPtr, &info ) != 0 && info.dli_sname != nil {
                let mangledName = String(cString: info.dli_sname)
                let demangledName = swiftDemangle(mangledName)
                entries.append(VTableEntry(mangledName: mangledName, demangledName: demangledName, address: fPtr))
            }
        }
    }
}

/// Layout of a class instance.
/// Adopted from https://github.com/johnno1962/SwiftTrace/blob/master/SwiftTrace/SwiftTrace.swift
/// Needs to be kept in sync with
/// https://github.com/apple/swift/blob/master/include/swift/ABI/Metadata.h
struct TargetClassMetadata {
    
    let metaClass: uintptr_t = 0
    let superClass: uintptr_t = 0
    let cacheData1: uintptr_t = 0
    let cacheData2: uintptr_t = 0
    
    let data: uintptr_t = 0
    
    /// Swift-specific class flags.
    let flags: UInt32 = 0
    
    /// The address point of instances of this type.
    let instanceAddressPoint: UInt32 = 0
    
    /// The required size of instances of this type.
    /// 'InstanceAddressPoint' bytes go before the address point;
    /// 'InstanceSize - InstanceAddressPoint' bytes go after it.
    let instanceSize: UInt32 = 0
    
    /// The alignment mask of the address point of instances of this type.
    let instanceAlignMask: UInt16 = 0
    
    /// Reserved for runtime use.
    let reserved: UInt16 = 0
    
    /// The total size of the class object, including prefix and suffix
    /// extents.
    let classSize: UInt32 = 0
    
    /// The offset of the address point within the class object.
    let classAddressPoint: UInt32 = 0
    
    /// An out-of-line Swift-specific description of the type, or null
    /// if this is an artificial subclass.  We currently provide no
    /// supported mechanism for making a non-artificial subclass
    /// dynamically.
    let typeDescription: uintptr_t = 0
    
    /// A function for destroying instance variables, used to clean up
    /// after an early return from a constructor.
    var iVarDestroyer: IMP?
    
    // After this come the class members, laid out as follows:
    //   - class members for the superclass (recursively)
    //   - metadata reference for the parent, if applicable
    //   - generic parameters for this class
    //   - class variables (if we choose to support these)
    //   - "tabulated" virtual methods
}


/// Swizzle a method of the given class.
/// The method tries to find the address of the original method in the vTable and replace it with the implementation of the replacement method.
/// The assumption is that the methods have exactly the same signature and parameters (no checking is done for that) and that no optimization
/// has been applied.
///
/// - Parameters:
///   - aClass: The class whose method is to be swizzled (the class is assumed to be non-final).
///   - address: Implementation address of the original method.
///   - replacementAddress: Implementation address of the replacement method.
/// - Returns: true if swizzling succeeded, false otherwise.
public func swizzleMethod(for aClass: AnyClass, address: IMP, replacementAddress: IMP) -> Bool {
    let swiftClassPtr = unsafeBitCast(aClass, to: UnsafeMutablePointer<TargetClassMetadata>.self)
    
    let symStart: UnsafeMutablePointer<IMP?> = withUnsafeMutablePointer(to: &swiftClassPtr.pointee.iVarDestroyer) { $0 }
    let swiftClassStart = swiftClassPtr.withMemoryRebound(to: UInt8.self, capacity: 1) { $0 }
    let symEnd = (swiftClassStart
        - Int(swiftClassPtr.pointee.classAddressPoint)
        + Int(swiftClassPtr.pointee.classSize)).withMemoryRebound(to: Optional<IMP>.self, capacity: 1) { $0 }
    
    for i in 0..<(symEnd - symStart) {
        guard let fPtr = symStart[i] else {
            continue
        }
        if fPtr == address {
            symStart[i] = replacementAddress
            return true
        }
    }
    
    return false
}

/// We want to use the function swift_demangle from the standard library, so we assign it to a local Swift name.
@_silgen_name("swift_demangle")
func swiftDemangleImpl(_ mangledName: UnsafePointer<CChar>?,
                       mangledNameLength: UInt,
                       outputBuffer: UnsafeMutablePointer<UInt8>?,
                       outputBufferSize: UnsafeMutablePointer<UInt>?,
                       flags: UInt32) -> UnsafeMutablePointer<CChar>?

/// Helper method which calls through to the (private) swift_demangle function from the standard library.
/// Allows to get the non-mangled name of a Swift function given its mangled symbol name.
/// - Parameter mangledName: Mangled symbol name (as it appears in the mach-o binary)
/// - Returns: Demangled name (as it usually appears in Swift source files).
public func swiftDemangle(_ mangledName: String) -> String {
    return mangledName.utf8CString.withUnsafeBufferPointer { (mangledNameUTF8) in
        
        let demangledNamePtr = swiftDemangleImpl(mangledNameUTF8.baseAddress,
                                                 mangledNameLength: UInt(mangledNameUTF8.count - 1),
                                                 outputBuffer: nil,
                                                 outputBufferSize: nil,
                                                 flags: 0)
        
        if let demangledNamePtr = demangledNamePtr {
            let demangledName = String(cString: demangledNamePtr)
            free(demangledNamePtr)
            return demangledName
        }
        return mangledName
    }
}

/// Helper method to get a demangled Swift name from the function implementation address.
/// Works only for public functions (which have entries in the mach-o symbol table)
/// First it gets the mangled symbol name by using dladdr.
/// Then it uses swift_demangle to convert the symbol name to a nicely readable Swift name.
/// - Parameter addr: Function implementation address.
/// - Returns: The demangled Swift name of the function at the specified address or an empty string if no function was
///            found or if no symbol information is available (e.g. the binary was stripped or it's not a public symbol).
public func swiftDemangle(_ addr: UnsafeRawPointer) -> String {
    var info = Dl_info()
    if dladdr(addr, &info ) != 0 && info.dli_sname != nil {
        let mangledName = String(cString: info.dli_sname)
        return swiftDemangle(mangledName)
    }
    return ""
}

