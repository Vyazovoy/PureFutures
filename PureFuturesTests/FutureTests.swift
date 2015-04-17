//
//  FutureTests.swift
//  PureFutures
//
//  Created by Victor Shamanov on 4/7/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import XCTest

import class PureFutures.Future
import struct PureFutures.Promise
import enum PureFutures.Result

class FutureTests: XCTestCase {
    
    var promise: Promise<Int, NSError>!
    let error = NSError(domain: "FutureTests", code: 0, userInfo: nil)

    override func setUp() {
        super.setUp()
        
        promise = Promise()
    }

    private func futureIsCompleteExpectation() -> XCTestExpectation {
        return expectationWithDescription("Future is completed")
    }
    
    // MARK:- onComplete
    
    func testOnCompleteImmediate() {
        
        promise.complete(Result(42))
        
        let expectation = futureIsCompleteExpectation()
        
        promise.future.onComplete { result in
            XCTAssertNotNil(result.value)
            XCTAssertEqual(result.value!, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testOnCompleteAfterSomeTime() {
        
        let expectation = futureIsCompleteExpectation()
        
        promise.future.onComplete { result in
            XCTAssertNotNil(result.value)
            XCTAssertEqual(result.value!, 42)
            expectation.fulfill()
        }
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            sleep(1)
            self.promise.complete(Result(42))
        }
        
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testOnCompleteOnMainThread() {
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            self.promise.complete(Result(42))
        }
        
        let expectation = futureIsCompleteExpectation()
        
        promise.future.onComplete(dispatch_get_main_queue()) { result in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(result.value)
            XCTAssertEqual(result.value!, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testOnCompleteOnBackgroundThread() {
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            self.promise.complete(Result(42))
        }
        
        let expectation = futureIsCompleteExpectation()
        
        promise.future.onComplete(dispatch_get_global_queue(0, 0)) { result in
            XCTAssertFalse(NSThread.isMainThread())
            XCTAssertNotNil(result.value)
            XCTAssertEqual(result.value!, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- onSuccess
    
    func testOnSuccess() {
        
        promise.success(42)
        
        let expectation = futureIsCompleteExpectation()
        
        let future = promise.future
        
        future.onSuccess { value in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }
        
        future.onError { _ in
            XCTFail("Future is failed")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- onError
    
    func testOnError() {
        
        promise.error(error)
        
        let expectation = futureIsCompleteExpectation()
        
        let future = promise.future
        
        future.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        future.onSuccess { _ in
            XCTFail("Future should not be succeed")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- forced
    
    func testForcedCompleted() {
        let future = Future<Int, Void>.succeed(42)
        
        if let value = future.forced(1)?.value {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("result is nil")
        }
    }
    
    func testForcedWithInterval() {
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            self.promise.success(42)
        }
        
        if let value = promise.future.forced(2)?.value {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("result is nil")
        }
    }
    
    func testForcedWithIntervalOnBackgroundThread() {
        
        dispatch_async(dispatch_get_main_queue()) {
            sleep(1)
            self.promise.success(42)
        }
        
        let expectation = futureIsCompleteExpectation()
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            if let value = self.promise.future.forced(2)?.value {
                XCTAssertEqual(value, 42)
            } else {
                XCTFail("result is nil")
            }
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3, handler: nil)
    }
    
    func testForcedInfinite() {
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            sleep(1)
            self.promise.success(42)
        }
        
        let result = promise.future.forced()
        
        XCTAssertNotNil(result.value)
        XCTAssertEqual(result.value!, 42)
    }
    
    // MARK:- transform
    
    func testTransformingSucceed() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let result = future.transform({
            $0 / 2
        }, e: { _ in
            XCTFail("This should not be called")
        })
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertEqual(value, 42 / 2)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testTransformingFailed() {
        
        let future = Future<Int, NSError>.failed(error)
        
        let result = future.transform({ _ in
            XCTFail("This should not be called")
        }, e: { error in
            return NSError(domain: "FutureTests", code: 1, userInfo: nil)
        })
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error.code, 1)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- map
    
    func testMappingSucceed() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let result = future.map { $0 / 2 }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertEqual(value, 42 / 2)
            expectation.fulfill()
        }
        
        result.onError { _ in
            XCTFail("This should not be called")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testMappingFailed() {
        
        let future = Future<Int, NSError>.failed(error)
        
        let result = future.map { _ in XCTFail("This should not be called") }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { _ in
            XCTFail("This should not be called")
            expectation.fulfill()
        }
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- filter
    
    func testFilterPass() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let result = future.filter { $0 % 2 == 0 }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            if let value = value {
                XCTAssertEqual(value, 42)
            } else {
                XCTFail("value is nil")
            }
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testFilterSkip() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let result = future.filter { $0 % 2 != 0 }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertNil(value)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testFilterWithError() {
        
        let future = Future<Int, NSError>.failed(error)
        
        let result = future.filter { _ in true }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- zip
    
    func testZip() {
        
        let first = Future<Int, NSError>.succeed(0)
        let second = Future<Int, NSError>.succeed(42)
        
        let result = first.zip(second)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { first, second in
            XCTAssertEqual(first, 0)
            XCTAssertEqual(second, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testZipWithFailed() {
        
        let succeed = Future<Int, NSError>.succeed(42)
        let failed = Future<Int, NSError>.failed(error)
        
        let result = succeed.zip(failed)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- reduce
    
    func testReduce() {
        
        let futures = Array(1...9).map { Future<Int, NSError>.succeed($0) }
        
        let result = Future.reduce(futures, initial: 0, combine: +)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertEqual(value, 45)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testReduceWithFailed() {
        
        var futures = Array(1...9).map { Future<Int, NSError>.succeed($0) }
        futures.append(Future(Result(error)))
        
        let result = Future.reduce(futures, initial: 0, combine: +)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- traverse
    
    func testTraverse() {
        
        let xs = Array(1...9)
        
        let result = Future<Int, NSError>.traverse(xs) { Future.succeed($0 + 1) }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertEqual(value, Array(2...10))
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testTraverseWithFailed() {
        
        let xs = Array(1...9)
        
        let result = Future<Int, NSError>.traverse(xs) { value -> Future<Int, NSError> in
            return value == 9 ? Future.failed(self.error) : Future.succeed(value + 1)
        }
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- sequence
    
    func testSequence() {
        
        let futures = Array(1...9).map { Future<Int, NSError>.succeed($0) }
        
        let result = Future.sequence(futures)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onSuccess { value in
            XCTAssertEqual(value, Array(1...9))
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testSequenceWithFailed() {
        
        let futures: [Future<Int, NSError>] = Array(1...9).map { value in
            return value == 9 ? Future.failed(self.error) : Future.succeed(value)
        }
        
        let result = Future.sequence(futures)
        
        let expectation = futureIsCompleteExpectation()
        
        result.onError { error in
            XCTAssertEqual(error, self.error)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- recover
    
    func testRecoverFailed() {
        
        let failedFuture = Future<Int, NSError>.failed(error)
        
        let recovered = failedFuture.recover { error in
            XCTAssertEqual(error, self.error)
            return 42
        }
        
        let expectation = futureIsCompleteExpectation()
        
        recovered.onSuccess { value in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testRecoverSucceed() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let recovered = future.recover { _ in 0 }
        
        let expectation = futureIsCompleteExpectation()
        
        recovered.onSuccess { value in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }
        
        recovered.onError { _ in
            XCTFail("This should not be called")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- recoverWith
    
    func testRecoverFailedWith() {
        
        let failedFuture = Future<Int, NSError>.failed(error)
        
        let recovered = failedFuture.recoverWith { error in
            XCTAssertEqual(error, self.error)
            return Future.succeed(42)
        }
        
        let expectation = futureIsCompleteExpectation()
        
        recovered.onSuccess { value in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testRecoverSucceedWith() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let recovered = future.recoverWith { _ in Future.succeed(0) }
        
        let expectation = futureIsCompleteExpectation()
        
        recovered.onSuccess { value in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }
        
        recovered.onError { _ in
            XCTFail("This should not be called")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    // MARK:- toDeferred
    
    func testToDeferredWithoutRecovering() {
        let future = Future<Int, NSError>.succeed(42)
        
        let deferred = future.toDeferred()
        
        let expectation = futureIsCompleteExpectation()
        
        deferred.onComplete { result in
            switch result {
            case .Success(let box):
                XCTAssertEqual(box.value, 42)
            case .Error(_):
                XCTFail("an error occured")
            }
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testToDeferred() {
        
        let future = Future<Int, NSError>.succeed(42)
        
        let deferred = future.toDeferred { _ in 0 }
        
        let expectation = futureIsCompleteExpectation()
        
        deferred.onComplete {
            XCTAssertEqual($0, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testToDeferredWithError() {
        let future = Future<Int, NSError>.failed(error)
        
        let deferred = future.toDeferred { _ in 42 }
        
        let expectation = futureIsCompleteExpectation()
        
        deferred.onComplete {
            XCTAssertEqual($0, 42)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }

}
