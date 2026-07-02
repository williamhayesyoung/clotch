import Foundation
import ClotchCore

/// Unix-domain-socket server. Accepts newline-delimited JSON commands and
/// dispatches them on the main queue.
final class ControlServer {
    private var fd: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    private let handler: (Command) -> Void

    init(handler: @escaping (Command) -> Void) {
        self.handler = handler
    }

    func start() throws {
        let path = clotchSocketPath()
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        unlink(path)

        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EBADF) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            path.withCString { cstr in
                _ = strlcpy(buf.baseAddress!.assumingMemoryBound(to: CChar.self), cstr, buf.count)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, len)
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw POSIXError(.EADDRINUSE)
        }
        // Owner-only: the socket accepts unauthenticated commands.
        chmod(path, 0o600)
        guard listen(fd, 8) == 0 else {
            close(fd)
            throw POSIXError(.ECONNREFUSED)
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.acceptClient() }
        source.resume()
        acceptSource = source
    }

    func stop() {
        acceptSource?.cancel()
        for (cfd, src) in clientSources {
            src.cancel()
            close(cfd)
        }
        clientSources.removeAll()
        if fd >= 0 { close(fd) }
        unlink(clotchSocketPath())
    }

    private func acceptClient() {
        let cfd = accept(fd, nil, nil)
        guard cfd >= 0 else { return }
        clientBuffers[cfd] = Data()
        let src = DispatchSource.makeReadSource(fileDescriptor: cfd, queue: .main)
        src.setEventHandler { [weak self] in self?.readClient(cfd) }
        src.setCancelHandler { close(cfd) }
        src.resume()
        clientSources[cfd] = src
    }

    private func readClient(_ cfd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(cfd, &buf, buf.count)
        if n <= 0 {
            closeClient(cfd)
            return
        }
        clientBuffers[cfd, default: Data()].append(contentsOf: buf[0..<n])
        while let range = clientBuffers[cfd]?.firstRange(of: Data([0x0A])) {
            let line = clientBuffers[cfd]!.subdata(in: clientBuffers[cfd]!.startIndex..<range.lowerBound)
            clientBuffers[cfd]!.removeSubrange(clientBuffers[cfd]!.startIndex..<range.upperBound)
            if let cmd = try? Command.decode(line) {
                handler(cmd)
            }
        }
    }

    private func closeClient(_ cfd: Int32) {
        clientSources[cfd]?.cancel() // cancel handler closes the fd
        clientSources[cfd] = nil
        clientBuffers[cfd] = nil
    }
}
