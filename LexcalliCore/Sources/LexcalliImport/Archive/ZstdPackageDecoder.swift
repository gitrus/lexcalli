import Foundation
import libzstd

/// File-to-file decoding with a bounded decoder window and the same budget as the outer ZIP layer.
enum ZstdPackageDecoder {
    static func decode(
        _ source: URL, to destination: URL, limits: UnpackLimits, budget: inout UnpackBudget
    ) throws {
        try Task.checkCancellation()
        guard let stream = ZSTD_createDStream() else { throw PackageError.decompressionFailed("allocation") }
        defer { ZSTD_freeDStream(stream) }
        try check(ZSTD_initDStream(stream))
        try check(ZSTD_DCtx_setParameter(stream, ZSTD_d_windowLogMax, limits.maxWindowLog))
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        try withPackageOutput(destination) { output in
            var buffer = [UInt8](repeating: 0, count: 64 << 10)
            var total: Int64 = 0
            var hint = 1
            var sawInput = false
            while let bytes = try input.read(upToCount: 64 << 10), !bytes.isEmpty {
                try Task.checkCancellation()
                sawInput = true
                try bytes.withUnsafeBytes { rawInput in
                    var inBuffer = ZSTD_inBuffer(src: rawInput.baseAddress, size: rawInput.count, pos: 0)
                    repeat {
                        try Task.checkCancellation()
                        let previous = inBuffer.pos
                        let produced = try buffer.withUnsafeMutableBytes { rawOutput in
                            var outBuffer = ZSTD_outBuffer(dst: rawOutput.baseAddress, size: rawOutput.count, pos: 0)
                            hint = ZSTD_decompressStream(stream, &outBuffer, &inBuffer)
                            try check(hint)
                            guard Int64(outBuffer.pos) <= limits.maxEntryBytes - total else {
                                throw PackageError.limitExceeded
                            }
                            try budget.consume(outBuffer.pos)
                            if outBuffer.pos > 0 {
                                try output.write(contentsOf: Data(rawOutput.prefix(outBuffer.pos)))
                                total += Int64(outBuffer.pos)
                            }
                            return outBuffer.pos
                        }
                        guard inBuffer.pos > previous || produced > 0 || hint == 0 else {
                            throw PackageError.decompressionFailed("no progress")
                        }
                        if inBuffer.pos == inBuffer.size && produced < buffer.count { break }
                    } while inBuffer.pos < inBuffer.size || hint != 0
                }
            }
            guard sawInput, hint == 0 else { throw PackageError.decompressionFailed("truncated frame") }
        }
    }

    private static func check(_ code: Int) throws {
        if ZSTD_isError(code) != 0 {
            throw PackageError.decompressionFailed(String(cString: ZSTD_getErrorName(code)))
        }
    }
}
