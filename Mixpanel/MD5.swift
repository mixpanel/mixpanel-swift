//
//  MD5.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 06/08/14.
//  Copyright (c) 2014 Marcin Krzyzanowski. All rights reserved.
//
//  Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications,
//  and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
//    If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.

import Foundation

final class MD5 {
    static let blockSize: Int = 64
    static let digestSize: Int = 16 // 128 / 8
    fileprivate static let hashInitialValue: Array<UInt32> = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]

    fileprivate var accumulated = Array<UInt8>()
    fileprivate var accumulatedLength: Int = 0
    fileprivate var accumulatedHash: Array<UInt32> = MD5.hashInitialValue

    /** specifies the per-round shift amounts */
    private let s: Array<UInt32> = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
                                    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                                    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
                                    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21]

    /** binary integer part of the sines of integers (Radians) */
    private let k: Array<UInt32> = [0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
                                    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
                                    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
                                    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
                                    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
                                    0xd62f105d, 0x2441453, 0xd8a1e681, 0xe7d3fbc8,
                                    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
                                    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
                                    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
                                    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
                                    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x4881d05,
                                    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
                                    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
                                    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
                                    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
                                    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391]

    func calculate(for bytes: Array<UInt8>) -> Array<UInt8> {
        do {
            return try self.update(withBytes: bytes, isLast: true)
        } catch {
            fatalError()
        }
    }


    fileprivate func process<C: Collection>(block chunk: C,
                             currentHash: inout Array<UInt32>) where C.Iterator.Element == UInt8, C.Index == Int {

        // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15
        var M = chunk.toUInt32Array()
        assert(M.count == 16, "Invalid array")

        // Initialize hash value for this chunk:
        var A: UInt32 = currentHash[0]
        var B: UInt32 = currentHash[1]
        var C: UInt32 = currentHash[2]
        var D: UInt32 = currentHash[3]

        var dTemp: UInt32 = 0

        // Main loop
        for j in 0..<k.count {
            var g = 0
            var F: UInt32 = 0

            switch j {
            case 0...15:
                F = (B & C) | ((~B) & D)
                g = j
                break
            case 16...31:
                F = (D & B) | (~D & C)
                g = (5 * j + 1) % 16
                break
            case 32...47:
                F = B ^ C ^ D
                g = (3 * j + 5) % 16
                break
            case 48...63:
                F = C ^ (B | (~D))
                g = (7 * j) % 16
                break
            default:
                break
            }
            dTemp = D
            D = C
            C = B
            B = B &+ rotateLeft(A &+ F &+ k[j] &+ M[g], by: s[j])
            A = dTemp
        }

        currentHash[0] = currentHash[0] &+ A
        currentHash[1] = currentHash[1] &+ B
        currentHash[2] = currentHash[2] &+ C
        currentHash[3] = currentHash[3] &+ D
    }
}

extension MD5: Updatable {
    func update<T: Sequence>(withBytes bytes: T, isLast: Bool = false) throws -> Array<UInt8> where T.Iterator.Element == UInt8 {
        let prevAccumulatedLength = self.accumulated.count
        self.accumulated += bytes
        self.accumulatedLength += self.accumulated.count - prevAccumulatedLength //avoid Array(bytes).count

        if isLast {
            // Step 1. Append padding
            self.accumulated = bitPadding(to: self.accumulated, blockSize: MD5.blockSize, allowance: 64 / 8)

            // Step 2. Append Length a 64-bit representation of lengthInBits
            let lengthInBits = self.accumulatedLength * 8
            let lengthBytes = arrayOfBytes(value: lengthInBits, length: 64 / 8) // A 64-bit representation of b
            self.accumulated += lengthBytes.reversed()
        }

        for chunk in BytesSequence(chunkSize: MD5.blockSize, data: self.accumulated) {
            if isLast || self.accumulated.count >= MD5.blockSize {
                self.process(block: chunk, currentHash: &self.accumulatedHash)
                self.accumulated.removeFirst(chunk.count)
            }
        }

        // output current hash
        var result = Array<UInt8>()
        result.reserveCapacity(self.accumulatedHash.count / 4)

        for hElement in self.accumulatedHash {
            let hLE = hElement.littleEndian
            let toAppend: [UInt8] = [UInt8(hLE & 0xff), UInt8((hLE >> 8) & 0xff), UInt8((hLE >> 16) & 0xff), UInt8((hLE >> 24) & 0xff)]
            result += toAppend
        }

        // reset hash value for instance
        if isLast {
            self.accumulatedHash = MD5.hashInitialValue
        }

        return result
    }
}

protocol Updatable {
    /// Update given bytes in chunks.
    ///
    /// - parameter bytes: Bytes to process
    /// - parameter isLast: (Optional) Given chunk is the last one. No more updates after this call.
    /// - returns: Processed data or empty array.
    mutating func update<T: Sequence>(withBytes bytes: T, isLast: Bool) throws -> Array<UInt8> where T.Iterator.Element == UInt8

    /// Update given bytes in chunks.
    ///
    /// - parameter bytes: Bytes to process
    /// - parameter isLast: (Optional) Given chunk is the last one. No more updates after this call.
    /// - parameter output: Resulting data
    /// - returns: Processed data or empty array.
    mutating func update<T: Sequence>(withBytes bytes: T,
                         isLast: Bool,
                         output: (Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8

    /// Finish updates. This may apply padding.
    /// - parameter bytes: Bytes to process
    /// - returns: Processed data.
    mutating func finish<T: Sequence>(withBytes bytes: T) throws -> Array<UInt8> where T.Iterator.Element == UInt8

    /// Finish updates. This may apply padding.
    /// - parameter bytes: Bytes to process
    /// - parameter output: Resulting data
    /// - returns: Processed data.
    mutating func finish<T: Sequence>(withBytes bytes: T, output: (Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8
}

extension Updatable {
    mutating func update<T: Sequence>(withBytes bytes: T,
                                isLast: Bool = false,
                                output: (Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8 {
        let processed = try self.update(withBytes: bytes, isLast: isLast)
        if !processed.isEmpty {
            output(processed)
        }
    }

    mutating func finish<T: Sequence>(withBytes bytes: T) throws -> Array<UInt8> where T.Iterator.Element == UInt8 {
        return try self.update(withBytes: bytes, isLast: true)
    }

    mutating func finish() throws  -> Array<UInt8> {
        return try self.update(withBytes: [], isLast: true)
    }

    mutating func finish<T: Sequence>(withBytes bytes: T, output: (Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8 {
        let processed = try self.update(withBytes: bytes, isLast: true)
        if !processed.isEmpty {
            output(processed)
        }
    }

    mutating func finish(output: (Array<UInt8>) -> Void) throws {
        try self.finish(withBytes: [], output: output)
    }
}

extension Collection where Self.Iterator.Element == UInt8, Self.Index == Int {
    func toUInt32Array() -> Array<UInt32> {
        var result = Array<UInt32>()
        result.reserveCapacity(16)
        for idx in stride(from: self.startIndex, to: self.endIndex, by: MemoryLayout<UInt32>.size) {
            var val: UInt32 = 0
            val |= self.count > 3 ? UInt32(self[idx.advanced(by: 3)]) << 24 : 0
            val |= self.count > 2 ? UInt32(self[idx.advanced(by: 2)]) << 16 : 0
            val |= self.count > 1 ? UInt32(self[idx.advanced(by: 1)]) << 8  : 0
            val |= !self.isEmpty ? UInt32(self[idx]) : 0
            result.append(val)
        }

        return result
    }

    func toUInt64Array() -> Array<UInt64> {
        var result = Array<UInt64>()
        result.reserveCapacity(32)
        for idx in stride(from: self.startIndex, to: self.endIndex, by: MemoryLayout<UInt64>.size) {
            var val: UInt64 = 0
            val |= self.count > 7 ? UInt64(self[idx.advanced(by: 7)]) << 56 : 0
            val |= self.count > 6 ? UInt64(self[idx.advanced(by: 6)]) << 48 : 0
            val |= self.count > 5 ? UInt64(self[idx.advanced(by: 5)]) << 40 : 0
            val |= self.count > 4 ? UInt64(self[idx.advanced(by: 4)]) << 32 : 0
            val |= self.count > 3 ? UInt64(self[idx.advanced(by: 3)]) << 24 : 0
            val |= self.count > 2 ? UInt64(self[idx.advanced(by: 2)]) << 16 : 0
            val |= self.count > 1 ? UInt64(self[idx.advanced(by: 1)]) << 8 : 0
            val |= !self.isEmpty ? UInt64(self[idx.advanced(by: 0)]) << 0 : 0
            result.append(val)
        }

        return result
    }

    func toInteger<T: Integer>() -> T where T: ByteConvertible, T: BitshiftOperationsType {
        if self.isEmpty {
            return 0
        }

        var bytes = self.reversed() //FIXME: check it this is equivalent of Array(...)
        if bytes.count < MemoryLayout<T>.size {
            let paddingCount = MemoryLayout<T>.size - bytes.count
            if paddingCount > 0 {
                bytes += Array<UInt8>(repeating: 0, count: paddingCount)
            }
        }

        if MemoryLayout<T>.size == 1 {
            return T(truncatingBitPattern: UInt64(bytes[0]))
        }

        var result: T = 0
        for byte in bytes.reversed() {
            result = result << 8 | T(byte)
        }
        return result
    }
}

func bitPadding(to data: Array<UInt8>, blockSize: Int, allowance: Int = 0) -> Array<UInt8> {
    var tmp = data

    // Step 1. Append Padding Bits
    tmp.append(0x80) // append one bit (UInt8 with one bit) to message

    // append "0" bit until message length in bits ≡ 448 (mod 512)
    var msgLength = tmp.count
    var counter = 0

    while msgLength % blockSize != (blockSize - allowance) {
        counter += 1
        msgLength += 1
    }

    tmp += Array<UInt8>(repeating: 0, count: counter)
    return tmp
}

func rotateLeft(_ value: UInt32, by: UInt32) -> UInt32 {
    return ((value << by) & 0xFFFFFFFF) | (value >> (32 - by))
}

func arrayOfBytes<T>(value: T, length: Int? = nil) -> Array<UInt8> {
    let totalBytes = length ?? MemoryLayout<T>.size

    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    valuePointer.pointee = value

    let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
    var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
    for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }

    valuePointer.deinitialize()
    valuePointer.deallocate(capacity: 1)

    return bytes
}

protocol ByteConvertible {
    init(_ value: UInt8)
    init(truncatingBitPattern: UInt64)
}

protocol BitshiftOperationsType {
    static func << (lhs: Self, rhs: Self) -> Self
    static func >> (lhs: Self, rhs: Self) -> Self
    static func <<= (lhs: inout Self, rhs: Self)
    static func >>= (lhs: inout Self, rhs: Self)
}

struct BytesSequence<D: RandomAccessCollection>: Sequence where D.Iterator.Element == UInt8,
                                                                D.IndexDistance == Int,
                                                                D.SubSequence.IndexDistance == Int,
                                                                D.Index == Int {
    let chunkSize: D.IndexDistance
    let data: D

    func makeIterator() -> AnyIterator<D.SubSequence> {
        var offset = data.startIndex
        return AnyIterator {
            let end = Swift.min(self.chunkSize, self.data.count - offset)
            let result = self.data[offset..<offset + end]
            offset = offset.advanced(by: result.count)
            if !result.isEmpty {
                return result
            }
            return nil
        }
    }
}

extension Data {
    func md5() -> Data {
        let result = Digest.md5(self.bytes)
        return Data(bytes: result)
    }
}

extension Data {

    var bytes: Array<UInt8> {
        return Array(self)
    }

    func toHexString() -> String {
        return self.bytes.toHexString()
    }
}

struct Digest {
    static func md5(_ bytes: Array<UInt8>) -> Array<UInt8> {
        return MD5().calculate(for: bytes)
    }
}

protocol CSArrayType: RangeReplaceableCollection {
    func cs_arrayValue() -> [Iterator.Element]
}

extension Array: CSArrayType {
    func cs_arrayValue() -> [Iterator.Element] {
        return self
    }
}

extension CSArrayType where Iterator.Element == UInt8 {
    func toHexString() -> String {
        return self.lazy.reduce("") {
            var s = String($1, radix: 16)
            if s.characters.count == 1 {
                s = "0" + s
            }
            return $0 + s
        }
    }
}
