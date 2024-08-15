# http-swift
A simple Swift HTTP server

## Usage

```swift
import HTTP

// Initialize the server to listen on port 8080
let server = HTTP.Server(port: 8080)

// Handle the root path "/"
server.handleFunc("/") { request in
    return HTTP.Response(statusCode: 200, body: "Welcome to HTTP.Server!")
}

// Handle a "/hello" route
server.handleFunc("/hello") { request in
    return HTTP.Response(statusCode: 200, body: "Hello, World!")
}

// Handle an "/echo" route that returns the request body
server.handleFunc("/echo") { request in
    let bodyString = String(data: request.body, encoding: .utf8) ?? "No body content"
    return HTTP.Response(statusCode: 200, body: "You said: \(bodyString)")
}

// Start the server
do {
    print("Starting server on port 8080...")
    try server.listenAndServe()
} catch {
    print("Error starting server: \(error)")
}
```