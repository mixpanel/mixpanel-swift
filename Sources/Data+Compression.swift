//
//  Data+Compression.swift
//  MixpanelSessionReplay
//
//  Copyright © 2024 Mixpanel. All rights reserved.
//

import Foundation
import zlib

public enum GzipError: Swift.Error {
  case stream
  case data
  case memory
  case buffer
  case version
  case unknown(code: Int)

  init(code: Int32) {
    switch code {
    case Z_STREAM_ERROR:
      self = .stream
    case Z_DATA_ERROR:
      self = .data
    case Z_MEM_ERROR:
      self = .memory
    case Z_BUF_ERROR:
      self = .buffer
    case Z_VERSION_ERROR:
      self = .version
    default:
      self = .unknown(code: Int(code))
    }
  }
}

extension Data {
  /// Compresses the data using gzip compression.
  /// Adapted from: https://github.com/1024jp/GzipSwift/blob/main/Sources/Gzip/Data%2BGzip.swift
  /// - Parameter level: Compression level.
  /// - Returns: The compressed data.
  /// - Throws: `GzipError` if compression fails.
  public func gzipCompressed(level: Int32 = Z_DEFAULT_COMPRESSION) throws -> Data {
    guard !self.isEmpty else {
      MixpanelLogger.warn(message: "Empty Data object cannot be compressed.")
      return Data()
    }

    let originalSize = self.count

    var stream = z_stream()
    stream.next_in = UnsafeMutablePointer<Bytef>(
      mutating: (self as NSData).bytes.bindMemory(to: Bytef.self, capacity: self.count))
    stream.avail_in = uint(self.count)

    let windowBits = MAX_WBITS + GzipSettings.gzipHeaderOffset  // Use gzip header instead of zlib header
    let memLevel = MAX_MEM_LEVEL
    let strategy = Z_DEFAULT_STRATEGY

    var status = deflateInit2_(
      &stream, level, Z_DEFLATED, windowBits, memLevel, strategy, ZLIB_VERSION,
      Int32(MemoryLayout<z_stream>.size))
    guard status == Z_OK else {
      throw GzipError(code: status)
    }

    var compressedData = Data(count: self.count / 2)
    repeat {
      if Int(stream.total_out) >= compressedData.count {
        compressedData.count += self.count / 2
      }
      let bufferPointer = compressedData.withUnsafeMutableBytes {
        $0.baseAddress?.assumingMemoryBound(to: Bytef.self)
      }
      guard let bufferPointer = bufferPointer else {
        throw GzipError(code: Z_BUF_ERROR)
      }
      stream.next_out = bufferPointer.advanced(by: Int(stream.total_out))
      stream.avail_out = uint(compressedData.count) - uint(stream.total_out)

      status = deflate(&stream, Z_FINISH)
    } while stream.avail_out == 0 && status == Z_OK

    guard status == Z_STREAM_END else {
      throw GzipError(code: status)
    }

    deflateEnd(&stream)
    compressedData.count = Int(stream.total_out)

    let compressedSize = compressedData.count
    let compressionRatio = Double(compressedSize) / Double(originalSize)
    let compressionPercentage = (1 - compressionRatio) * 100

    let roundedCompressionRatio = floor(compressionRatio * 1000) / 1000
    let roundedCompressionPercentage = floor(compressionPercentage * 1000) / 1000

    MixpanelLogger.info(
      message:
        "Payload gzipped: original size = \(originalSize) bytes, compressed size = \(compressedSize) bytes, compression ratio = \(roundedCompressionRatio), compression percentage = \(roundedCompressionPercentage)%"
    )

    return compressedData
  }
}
