import http.server
import json
import time


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if self.path != "/v1/models":
            self.send_error(404)
            return
        body = json.dumps(
            {
                "object": "list",
                "data": [
                    {"id": "fake-translator", "object": "model"},
                    {"id": "fake-slow-translator", "object": "model"},
                ],
            }
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length).decode("utf-8"))
        source = request.get("messages", [{}])[-1].get("content", "")
        if "[secret-required]" in source and self.headers.get("Authorization") != "Bearer host-secret":
            body = b"Authentication failed."
            self.send_response(401)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if "[auth-error]" in source:
            body = b"Authentication failed."
            self.send_response(401)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        delay = 0.20 if request.get("model") == "fake-slow-translator" else 0.02
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        try:
            for fragment in ["你好", "，", "LinguaMesh", "！"]:
                time.sleep(delay)
                event = json.dumps(
                    {"choices": [{"delta": {"content": fragment}}]},
                    ensure_ascii=False,
                )
                self.wfile.write(f"data: {event}\n\n".encode("utf-8"))
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        self.close_connection = True

    def log_message(self, format_value, *arguments):
        return


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
server.daemon_threads = True
print(f"PORT={server.server_address[1]}", flush=True)
server.serve_forever()
