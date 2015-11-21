//
//  Future.swift
//  PureFutures
//
//  Created by Victor Shamanov on 2/11/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import typealias Foundation.NSTimeInterval

// MARK:- future creation function

/**

    Creates a new `Future<T, E>` whose value will be
    result of execution `f` on background thread

    - parameter f: function, which result will become value of returned Future

    - returns: a new Future<T, E>
    
*/
public func future<T, E>(f: () -> Result<T, E>) -> Future<T, E> {
    return future(ExecutionContext.DefaultPureOperationContext, f: f)
}

/**

    Creates a new `Future<T, E>` whose value will be
    result of execution `f` on `ec` execution context

    - parameter ec: execution context of given function
    - parameter f: function, which result will become value of returned Future

    - returns: a new Future<T, E>
    
*/
public func future<T, E>(ec: ExecutionContextType, f: () -> Result<T, E>) -> Future<T, E> {
    let p = Promise<T, E>()
    
    ec.execute {
        p.complete(f())
    }
    
    return p.future
}

// MARK:- Future

/**

    Represents a value that will be available in the future

    This value is usually result of some computation or network request.

    May completes with either `Success` and `Error` cases

    This is convenient way to use `Deferred<Result<T, E>>`

    See also: `Deferred`

*/

public final class Future<T, E>: FutureType {
    
    // MARK:- Type declarations
    
    public typealias Success = T
    public typealias Error = E
    
    public typealias ResultType = Result<T, E>
    
    public typealias CompleteCallback = ResultType -> Void
    public typealias SuccessCallback = T -> Void
    public typealias ErrorCallback = E -> Void
    
    // MARK:- Private properties
    
    private let deferred: Deferred<ResultType>
    
    // MARK:- Public properties

    /// Value of Future
    public private(set) var value: ResultType? {
        set {
            deferred.setValue(newValue!)
        }
        get {
            return deferred.value
        }
    }

    /// Shows if Future is completed
    public var isCompleted: Bool {
        return deferred.isCompleted
    }
    
    // MARK:- Initialization
    
    internal init() {
        deferred = Deferred()
    }
    
    internal init(deferred: Deferred<ResultType>) {
        self.deferred = deferred
    }
    
    public init<F: FutureType where F.Element == Result<T, E>>(future: F) {
        deferred = Deferred(deferred: future)
    }
    
    // MARK:- Class methods

    /**
    
        Returns a new immediately completed `Future<T, E>` with given `value`

        - parameter value: value which Future will have

        - returns: a new Future

    */
    public class func succeed(value: T) -> Future {
        return .completed(.Success(value))
    }


    /**

        Returns a new immediately completed `Future<T, E>` with given `error`

        - parameter error: error which Future will have

        - returns: a new Future
        
    */
    public class func failed(error: E) -> Future {
        return .completed(.Error(error))
    }
    
    /// Creates a new Future with given Result<T, E>
    public static func completed(x: ResultType) -> Future {
        return Future(deferred: .completed(x))
    }

    // MARK:- FutureType methods

    /**

        Register a callback which will be called when Future is completed

        - parameter ec: execution context of callback
        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onComplete(ec: ExecutionContextType, _ c: CompleteCallback) -> Future {
        deferred.onComplete(ec, c)
        return self
    }


    /**

        Register a callback which will be called when Future is completed with value

        - parameter ec: execution context of callback
        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onSuccess(ec: ExecutionContextType, _ c: SuccessCallback) -> Future {
        return onComplete(ec) {
            switch $0 {
            case .Success(let value):
                c(value)
            default:
                break
            }
        }
    }
    
    /**

        Register a callback which will be called when Future is completed with error

        - parameter ec: execution context of callback
        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onError(ec: ExecutionContextType, _ c: ErrorCallback) -> Future {
        return onComplete(ec) {
            switch $0 {
            case .Error(let error):
                c(error)
            default:
                break
            }
        }
    }
    
    // MARK:- Convenience methods
    
    /**

        Register a callback which will be called on a main thread when Future is completed

        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onComplete(c: CompleteCallback) -> Future {
        return onComplete(ExecutionContext.DefaultSideEffectsContext, c)
    }
    
    /**

        Register a callback which will be called on a main thread when Future is completed with value

        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onSuccess(c: SuccessCallback) -> Future {
        return onSuccess(ExecutionContext.DefaultSideEffectsContext, c)
    }
    
    /**

        Register a callback which will be called on a main thread when Future is completed with error

        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onError(c: ErrorCallback) -> Future {
        return onError(ExecutionContext.DefaultSideEffectsContext, c)
    }
    
    
    // MARK:- Internal methods
    
    internal func setValue(value: ResultType) {
        self.value = value
    }
    
}

public extension Future {
    
    // MARK:- andThen
    
    /**

        Applies the side-effecting function that will be executed on main thread
        to the result of this future, and returns a new future with the result of this future

        - parameter ec: execution context of `f` function
        - parameter f: side-effecting function that will be applied to success result of future

        - returns: a new Future

    */
    func andThen(f: T -> Void) -> Future {
        #if os(iOS)
        return PureFutures.andThen(f)(self)
        #else
        return PureFuturesOSX.andThen(f)(self)
        #endif
    }
    
    /**

        Applies the side-effecting function to the success result of this future,
        and returns a new future with the result of this future

        - parameter ec: execution context of `f` function
        - parameter f: side-effecting function that will be applied to success result of future

        - returns: a new Future

    */
    func andThen(ec: ExecutionContextType, f: T -> Void) -> Future {
        #if os(iOS)
        return PureFutures.andThen(f, ec)(self)
        #else
        return PureFuturesOSX.andThen(f, ec)(self)
        #endif
    }
    
    // MARK:- forced
    
    /**

        Stops the current thread, until value of future becomes available

        - returns: value of future

    */
    func forced() -> ResultType {
        #if os(iOS)
        return PureFutures.forced(self)
        #else
        return PureFuturesOSX.forced(self)
        #endif
    }
    
    /**

        Stops the currend thread, and wait for `inverval` seconds until value of future becoms available

        - parameter inverval: number of seconds to wait

        - returns: Value of future or nil if it hasn't become available yet

    */
    func forced(interval: NSTimeInterval) -> ResultType? {
        #if os(iOS)
        return PureFutures.forced(interval)(self)
        #else
        return PureFuturesOSX.forced(interval)(self)
        #endif
    }
    
    // MARK:- map
    
    /**

        Creates a new future by applying a function `f` that will be executed on global queue
        to the success result of this future.
    
        Do not put any UI-related code into `f` function

        - parameter f: Function that will be applied to success result of future

        - returns: a new Future

    */
    func map<U>(f: T -> U) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.map(f)(self)
        #else
        return PureFuturesOSX.map(f)(self)
        #endif
    }
    
    /**

        Creates a new future by applying a function `f` to the success result of this future.

        - parameter ec: Execution context of `f`
        - parameter f: Function that will be applied to success result of future

        - returns: a new Future

    */
    func map<U>(ec: ExecutionContextType, _ f: T -> U) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.map(f, ec)(self)
        #else
        return PureFuturesOSX.map(f, ec)(self)
        #endif
    }
    
    // MARK:- transform
    
    /**

        Creates a new future by applying the 's' function to the successful result of this future, 
        or the 'e' function to the failed result.
    
        `s` and `e` will be executed on global queue
    
        Do not put any UI-related code into `s` and `e` functions

        - parameter ec: Execution context of `s` and `e` functions
        - parameter s: Function that will be applied to success result of the future
        - parameter e: Function that will be applied to failed result of the future

        - returns: a new Future
    */
    func transform<T1, E1>(s: T -> T1, _ e: E -> E1) -> Future<T1, E1> {
        #if os(iOS)
        return PureFutures.transform(s, e)(self)
        #else
        return PureFuturesOSX.transform(s, e)(self)
        #endif
    }
    
    /**

        Creates a new future by applying the 's' function to the successful result of this future, 
        or the 'e' function to the failed result.

        - parameter ec: Execution context of `s` and `e` functions
        - parameter s: Function that will be applied to success result of the future
        - parameter e: Function that will be applied to failed result of the future

        - returns: a new Future
    */
    func transform<T1, E1>(ec: ExecutionContextType, _ s: T -> T1, _ e: E -> E1) -> Future<T1, E1> {
        #if os(iOS)
        return PureFutures.transform(s, e, ec)(self)
        #else
        return PureFuturesOSX.transform(s, e, ec)(self)
        #endif
    }
    
    // MARK:- flatMap
    
    /**

        Creates a new future by applying a function which will be executed on global queue
        to the success result of this future, and returns the result of the function as the new future.

        - parameter f: Funcion that will be applied to success result of the future

        - returns: a new Future

    */
    func flatMap<U>(f: T -> Future<U, E>) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.flatMap(f)(self)
        #else
        return PureFuturesOSX.flatMap(f)(self)
        #endif
    }
    
    /**

        Creates a new future by applying a function to the success result of this future, 
        and returns the result of the function as the new future.

        - parameter ec: Execution context of `f`
        - parameter f: Funcion that will be applied to success result of the future

        - returns: a new Future

    */
    func flatMap<U>(ec: ExecutionContextType, _ f: T -> Future<U, E>) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.flatMap(f, ec)(self)
        #else
        return PureFuturesOSX.flatMap(f, ec)(self)
        #endif
    }
    
    // MARK:- flatten
    
    /**

        Removes one level of nesting of Future

        - parameter fx: Future

        - returns: flattened Future

    */
    class func flatten(fx: Future<Future<T, E>, E>) -> Future {
        #if os(iOS)
        return PureFutures.flatten(fx)
        #else
        return PureFuturesOSX.flatten(fx)
        #endif
    }
    
    // MARK:- filter
    
    /**

        Creates a new Future by filtering the value of the current Future with a predicate `p`
        which will be executed on global queue
    
        Do not put any UI-related code into `p` function

        - parameter p: Predicate function

        - returns: A new Future with value or nil

    */
    func filter(p: T -> Bool) -> Future<T?, E> {
        #if os(iOS)
        return PureFutures.filter(p)(self)
        #else
        return PureFuturesOSX.filter(p)(self)
        #endif
    }
    
    /**

        Creates a new Future by filtering the value of the current Future with a predicate `p`

        - parameter ec: Execution context of `p`
        - parameter p: Predicate function

        - returns: A new Future with value or nil

    */
    func filter(ec: ExecutionContextType, _ p: T -> Bool) -> Future<T?, E> {
        #if os(iOS)
        return PureFutures.filter(p, ec)(self)
        #else
        return PureFuturesOSX.filter(p, ec)(self)
        #endif
    }
    
    // MARK:- zip
    
    /**

        Zips two future together and returns a new Future which success result contains a tuple of two elements

        - parameter fx: Another future

        - returns: Future with resuls of two futures

    */
    func zip<U>(fx: Future<U, E>) -> Future<(T, U), E> {
        #if os(iOS)
        return PureFutures.zip(self)(fx)
        #else
        return PureFuturesOSX.zip(self)(fx)
        #endif
    }
    
    // MARK:- recover
    
    /**
        Creates a new future that will handle error value that this future might contain

        Returned future will never fail.
    
        `r` will be executed on global queue
    
        Do not put any UI-related code into `r` function
        
        See: `toDeferred`

        - parameter ec: Execution context of `r` function
        - parameter r: Recover function

        - returns: a new Future that will never fail

    */
    func recover(r: E -> T) -> Future {
        #if os(iOS)
        return PureFutures.recover(r)(self)
        #else
        return PureFuturesOSX.recover(r)(self)
        #endif
    }
    
    /**
        Creates a new future that will handle error value that this future might contain

        Returned future will never fail.
        
        See: `toDeferred`

        - parameter ec: Execution context of `r` function
        - parameter r: Recover function

        - returns: a new Future that will never fail

    */
    func recover(ec: ExecutionContextType, _ r: E -> T) -> Future {
        #if os(iOS)
        return PureFutures.recover(r, ec)(self)
        #else
        return PureFuturesOSX.recover(r, ec)(self)
        #endif
    }
    
    // MARK:- recoverWith
    
    /**

        Creates a new future that will handle fail results that this future might contain by assigning it a value of another future.

        `r` will be executed on global queue
    
        Do not put any UI-related code into `r` function
    
        - parameter ec: Execition context of `r` function
        - parameter r: Recover function

        - returns: a new Future

    */
    func recoverWith(r: E -> Future) -> Future {
        #if os(iOS)
        return PureFutures.recoverWith(r)(self)
        #else
        return PureFuturesOSX.recoverWith(r)(self)
        #endif
    }
    
    /**

        Creates a new future that will handle fail results that this future might contain by assigning it a value of another future.

        - parameter ec: Execition context of `r` function
        - parameter r: Recover function

        - returns: a new Future

    */
    func recoverWith(ec: ExecutionContextType, _ r: E -> Future) -> Future {
        #if os(iOS)
        return PureFutures.recoverWith(r, ec)(self)
        #else
        return PureFuturesOSX.recoverWith(r, ec)(self)
        #endif
    }
    
    // MARK:- toDeferred
    
    /**

        Transforms Future into Deferred

        - returns: Deferred

    */
    func toDeferred() -> Deferred<Result<T, E>> {
        return deferred
    }
    
    /**

        Transforms Future<T, E> into Deferred<T> and handles error case with `r` function
        which will be executed on global queue
    
        Do not put any UI-related code into `r` function

        - parameter ec: Execution context of `r` function
        - parameter r: Recover function

        - returns: Deferred with success value of `fx` or result of `r`

    */
    func toDeferred(r: E -> T) -> Deferred<T> {
        #if os(iOS)
        return PureFutures.toDeferred(r)(self)
        #else
        return PureFuturesOSX.toDeferred(r)(self)
        #endif
    }
    
    /**

        Transforms Future<T, E> into Deferred<T> and handles error case with `r` function

        - parameter ec: Execution context of `r` function
        - parameter r: Recover function

        - returns: Deferred with success value of `fx` or result of `r`

    */
    func toDeferred(ec: ExecutionContextType, _ r: E -> T) -> Deferred<T> {
        #if os(iOS)
        return PureFutures.toDeferred(r, ec)(self)
        #else
        return PureFuturesOSX.toDeferred(r, ec)(self)
        #endif
    }
    
    // MARK:- reduce
    
    /**

        Reduces the elements of sequence of futures using the specified reducing function `combine`
        which will be executed on global queue

        Do not put any UI-related code into `combine` function

        - parameter ec: Execution context of `combine`
        - parameter fxs: Sequence of Futures
        - parameter initial: Initial value that will be passed as first argument in `combine` function
        - parameter combine: reducing function

        - returns: Future which will contain result of reducing sequence of futures

    */
    class func reduce<U>(fxs: [Future], _ initial: U, _ combine: (U, T) -> U) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.reduce(combine, initial)(fxs)
        #else
        return PureFuturesOSX.reduce(initial, combine)(fxs)
        #endif
    }
    
    /**

        Reduces the elements of sequence of futures using the specified reducing function `combine`

        - parameter ec: Execution context of `combine`
        - parameter fxs: Sequence of Futures
        - parameter initial: Initial value that will be passed as first argument in `combine` function
        - parameter combine: reducing function

        - returns: Future which will contain result of reducing sequence of futures

    */
    class func reduce<U>(ec: ExecutionContextType, _ fxs: [Future], _ initial: U, _ combine: (U, T) -> U) -> Future<U, E> {
        #if os(iOS)
        return PureFutures.reduce(combine, initial, ec)(fxs)
        #else
        return PureFuturesOSX.reduce(initial, combine, ec)(fxs)
        #endif
    }
    
    // MARK:- traverse
    
    /**

        Transforms an array of values into Future of array of this values using the provided function `f`
        which will be executed on global queue
    
        Do not put any UI-related code into `f` function

        - parameter ec: Execution context of `f`
        - parameter xs: Sequence of values
        - parameter f: Function for transformation values into Future

        - returns: a new Future

    */
    class func traverse<U>(xs: [T], _ f: T -> Future<U, E>) -> Future<[U], E> {
        #if os(iOS)
        return PureFutures.traverse(f)(xs)
        #else
        return PureFuturesOSX.traverse(f)(xs)
        #endif
    }
    
    /**

        Transforms an array of values into Future of array of this values using the provided function `f`

        - parameter ec: Execution context of `f`
        - parameter xs: Sequence of values
        - parameter f: Function for transformation values into Future

        - returns: a new Future

    */
    class func traverse<U>(ec: ExecutionContextType, _ xs: [T], _ f: T -> Future<U, E>) -> Future<[U], E> {
        #if os(iOS)
        return PureFutures.traverse(f, ec)(xs)
        #else
        return PureFuturesOSX.traverse(f, ec)(xs)
        #endif
    }
    
    // MARK:- sequence
    
    /**

        Transforms a sequnce of Futures into Future of array of values

        - parameter fxs: Sequence of Futures

        - returns: Future with array of values

    */
    class func sequence(fxs: [Future]) -> Future<[T], E> {
        #if os(iOS)
        return PureFutures.sequence(fxs)
        #else
        return PureFuturesOSX.sequence(fxs)
        #endif
    }
    
}
