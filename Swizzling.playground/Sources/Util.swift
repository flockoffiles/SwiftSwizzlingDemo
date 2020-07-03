import Foundation

public struct Util {

    struct Box<F> {
        /// Must be a non-nominal function type
        var f: F
        
        mutating func ptr<T>() -> UnsafePointer<T> {
            return withUnsafePointer(to: &self) {
                $0.withMemoryRebound(to: T.self, capacity: 1) { $0 }
            }
        }
    }
    
    struct ThickFunction<ContextType> {
        /// Implementation pointer
        var implPtr: UnsafeRawPointer
        /// Pointer to a context
        var contextPtr: UnsafePointer<ContextType>?
    }
    
    /// Helper struct. Stores a reference counted element.
    struct RefCounted {
        var type: UnsafeRawPointer
        var refCountingA: UInt32
        var refCountingB: UInt32
    }
    
    /// Swift function context representation in memory (the one used for free functions and function thunks)
    struct ThickFunctionContext<T> {
        var ref: RefCounted
        var thickFunction: ThickFunction<T>
    }
    
    /// Swift method context representation in memory (the one used for non-generic and non-final methods)
    struct MethodContext {
        var ref: RefCounted
        var selfPtr: UnsafeRawPointer?
        var implPtr: UnsafeRawPointer?
    }
    
    /// Swift method context representation in memory
    // (The one used for generic non-final methods without constraints)
    struct GenMethodContext {
        var ref: RefCounted
        var ptr1: UnsafeRawPointer?
        var ptr2: UnsafeRawPointer?
        var ptr3: UnsafeRawPointer?
    }
    
    /// Swift method context representation in memory
    // (The one used for generic non-final methods with a single constraint)
    struct GenConstrainedMethodContext {
        var ref: RefCounted
        var ptr1: UnsafeRawPointer?
        var ptr2: UnsafeRawPointer?
        var ptr3: UnsafeRawPointer?
        var ptr4: UnsafeRawPointer?
    }
    
    public static func functionAddress<F>(_ f: F) -> UnsafeRawPointer? {
        var fBox = Box(f: f)
        let ptr: UnsafePointer<ThickFunction<ThickFunctionContext<Void>>> = fBox.ptr()
        return ptr.pointee.contextPtr?.pointee.thickFunction.implPtr
    }
    
    public static func methodAddress<F>(_ f: F) -> UnsafeRawPointer? {
        var fBox = Box(f: f)
        return withUnsafePointer(to: &fBox) {
            return $0.withMemoryRebound(to: ThickFunction<ThickFunctionContext<MethodContext>>.self, capacity: 1, {
                return $0.pointee.contextPtr?.pointee.thickFunction.contextPtr?.pointee.implPtr
            })
        }
    }
    
    public static func genericMethodAddress<F>(_ f: F) -> UnsafeRawPointer? {
        var fBox = Box(f: f)
        let ptr: UnsafePointer<ThickFunction<ThickFunctionContext<ThickFunctionContext<GenMethodContext>>>> = fBox.ptr()
        return ptr.pointee.contextPtr?.pointee.thickFunction.contextPtr?.pointee.thickFunction.contextPtr?.pointee.ptr3
    }
    
    public static func constrainedGenericMethodAddress<F>(_ f: F) -> UnsafeRawPointer? {
        var fBox = Box(f: f)
        let ptr: UnsafePointer<ThickFunction<ThickFunctionContext<ThickFunctionContext<GenConstrainedMethodContext>>>> = fBox.ptr()
        return ptr.pointee.contextPtr?.pointee.thickFunction.contextPtr?.pointee.thickFunction.contextPtr?.pointee.ptr4
    }
}
