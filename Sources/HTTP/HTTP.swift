import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

// MARK: - HTTP Server

public class Server {
  private var routes: [String: (Request) -> Response] = [:]
  private let port: UInt16

  public init(port: UInt16 = 8080) {
    self.port = port
  }

  public func handleFunc(_ path: String, handler: @escaping (Request) -> Response) {
    routes[path] = handler
  }

  public func listenAndServe() throws {
    let socket = try SocketServer(port: port)

    while true {
      if let clientSocket = try? socket.acceptClientConnection() {
        DispatchQueue.global().async {
          self.handleConnection(clientSocket)
        }
      }
    }
  }

  private func handleConnection(_ clientSocket: ClientSocket) {
    guard let request = Request(from: clientSocket) else {
      clientSocket.close()
      return
    }

    let response: Response
    if let handler = routes[request.path] {
      response = handler(request)
    } else {
      response = Response(statusCode: 404, body: "Not Found")
    }

    clientSocket.send(response: response)
    clientSocket.close()
  }
}

// MARK: - HTTP Request
public struct Request {
  public let method: String
  public let path: String
  public let headers: [String: String]
  public let body: Data

  fileprivate init?(from socket: ClientSocket) {
    guard let requestLine = socket.readLine() else {
      return nil
    }

    let methodPath = Array(requestLine.components(separatedBy: " ").prefix(2))

    guard methodPath.count == 2 else {
      return nil
    }

    self.method = methodPath[0]
    self.path = methodPath[1]

    var headers = [String: String]()
    var body = Data()

    while let line = socket.readLine(), !line.isEmpty {
      let headerParts = line.components(separatedBy: ": ")
      if headerParts.count == 2 {
        headers[headerParts[0]] = headerParts[1]
      }
    }

    if let contentLength = headers["Content-Length"], let length = Int(contentLength) {
      body = socket.readData(length: length)
    }

    self.headers = headers
    self.body = body
  }
}

// MARK: - HTTP Response

public struct Response {
  public let statusCode: Int
  public let headers: [String: String]
  public let body: Data

  public init(statusCode: Int, headers: [String: String] = [:], body: String) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = Data(body.utf8)
  }

  public func buildResponse() -> String {
    var response = "HTTP/1.1 \(statusCode) \(Response.statusDescription(for: statusCode))\r\n"
    headers.forEach { response += "\($0): \($1)\r\n" }
    response += "Content-Length: \(body.count)\r\n\r\n"
    return response
  }

  private static func statusDescription(for statusCode: Int) -> String {
    switch statusCode {
    case 200: return "OK"
    case 404: return "Not Found"
    default: return "Unknown"
    }
  }
}
import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

// MARK: - Socket Communication

private class SocketServer {
  private var socket: Int32

  init(port: UInt16) throws {
    self.socket = SwiftGlibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    
    var addr = sockaddr_in(
      sin_family: sa_family_t(AF_INET),
      sin_port: port.bigEndian,
      sin_addr: in_addr(s_addr: inet_addr("0.0.0.0")),
      sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )
    
    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(self.socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }

    if bindResult < 0 {
      throw NSError(domain: "Failed to bind socket", code: 1, userInfo: nil)
    }

    listen(self.socket, 10)
  }

  func acceptClientConnection() throws -> ClientSocket {
    let clientSocket = accept(self.socket, nil, nil)
    if clientSocket < 0 {
      throw NSError(domain: "Failed to accept client connection", code: 1, userInfo: nil)
    }
    return ClientSocket(socket: clientSocket)
  }
}

private class ClientSocket {
  private let socket: Int32

  init(socket: Int32) {
    self.socket = socket
  }

  func readLine() -> String? {
    var buffer = [UInt8](repeating: 0, count: 1024)
    var line = ""
    while true {
      let bytesRead = recv(self.socket, &buffer, 1, 0)
      if bytesRead > 0, let char = String(bytes: [buffer[0]], encoding: .utf8), char != "\r" {
        line.append(char)
        if char == "\n" {
          break
        }
      } else {
        break
      }
    }
    return line.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func readData(length: Int) -> Data {
    var buffer = [UInt8](repeating: 0, count: length)
    let bytesRead = recv(self.socket, &buffer, length, 0)
    return Data(buffer[0..<max(0, bytesRead)])
  }

  func send(response: Response) {
    let responseString = response.buildResponse()
    let responseBytes = [UInt8](responseString.utf8) + [UInt8](response.body)
    _ = responseBytes.withUnsafeBufferPointer {
      SwiftGlibc.send(self.socket, $0.baseAddress, $0.count, 0)
    }
  }

  func close() {
    SwiftGlibc.shutdown(self.socket, Int32(SHUT_RDWR))
    #if os(Linux)
    SwiftGlibc.close(self.socket)
    #else
    Darwin.close(self.socket)
    #endif
  }
}
