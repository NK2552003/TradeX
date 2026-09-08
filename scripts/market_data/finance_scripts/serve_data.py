"""
Tiny local server to serve the ./data JSON files to a frontend,
with CORS enabled so a Flutter web app / browser frontend can fetch them.

Usage:
    python serve_data.py
    # then open http://localhost:8000/quotes.json
    #           http://localhost:8000/fundamentals.json
    #           http://localhost:8000/news.json
    #           http://localhost:8000/history/AAPL.json
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

DATA_DIR = "data"
PORT = 8000


class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


if __name__ == "__main__":
    os.chdir(DATA_DIR)
    server = HTTPServer(("0.0.0.0", PORT), CORSRequestHandler)
    print(f"Serving {DATA_DIR}/ at http://localhost:{PORT}  (CORS enabled)")
    print("Press Ctrl+C to stop.")
    server.serve_forever()
