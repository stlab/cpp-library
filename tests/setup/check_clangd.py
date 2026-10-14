# SPDX-License-Identifier: BSL-1.0
"""Fresh-header LSP regression; Python is needed only by this optional test."""

import json
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


def check(clangd, build, header):
    header = Path(header).resolve()
    uri = header.as_uri()
    messages = queue.Queue()
    diagnostics = []
    stderr = []
    process = subprocess.Popen(
        [clangd, f"--compile-commands-dir={build}", "--background-index=0",
         "--clang-tidy=0", "--log=verbose"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )

    def read_messages():
        try:
            while True:
                headers = {}
                while True:
                    line = process.stdout.readline()
                    if not line:
                        raise EOFError("clangd closed stdout")
                    if line == b"\r\n":
                        break
                    name, value = line.decode("ascii").split(":", 1)
                    headers[name.lower()] = value.strip()
                size = int(headers["content-length"])
                body = bytearray()
                while len(body) < size:
                    part = process.stdout.read(size - len(body))
                    if not part:
                        raise EOFError("clangd truncated a message")
                    body.extend(part)
                messages.put(json.loads(body))
        except (EOFError, ValueError, OSError) as error:
            messages.put(error)

    def read_stderr():
        for line in iter(process.stderr.readline, b""):
            stderr.append(line.decode("utf-8", errors="replace"))

    output_thread = threading.Thread(target=read_messages, daemon=True)
    log_thread = threading.Thread(target=read_stderr, daemon=True)
    output_thread.start()
    log_thread.start()
    request_id = 0

    def send(method, params, identifier=None):
        message = {"jsonrpc": "2.0", "method": method, "params": params}
        if identifier is not None:
            message["id"] = identifier
        body = json.dumps(message).encode("utf-8")
        process.stdin.write(f"Content-Length: {len(body)}\r\n\r\n".encode("ascii") + body)
        process.stdin.flush()

    def request(method, params):
        nonlocal request_id
        request_id += 1
        send(method, params, request_id)
        deadline = time.monotonic() + 45
        while True:
            message = messages.get(timeout=max(0, deadline - time.monotonic()))
            if isinstance(message, Exception):
                raise message
            if message.get("method") == "textDocument/publishDiagnostics":
                diagnostics.extend(message["params"]["diagnostics"])
            if message.get("id") == request_id:
                if "error" in message:
                    raise AssertionError(message["error"])
                return message.get("result")

    def definition(line, character, expected_uri, expected_line, start, end):
        result = request("textDocument/definition", {
            "textDocument": {"uri": uri},
            "position": {"line": line, "character": character},
        })
        if isinstance(result, dict):
            result = [result]
        expected = [{
            "uri": expected_uri,
            "range": {
                "start": {"line": expected_line, "character": start},
                "end": {"line": expected_line, "character": end},
            },
        }]
        if result != expected:
            raise AssertionError(f"Definition at {line}:{character}: {result!r} != {expected!r}")

    try:
        request("initialize", {
            "processId": None, "rootUri": header.parent.as_uri(), "capabilities": {},
        })
        send("initialized", {})
        send("textDocument/didOpen", {
            "textDocument": {
                "uri": uri, "languageId": "cpp", "version": 1,
                "text": header.read_text(encoding="utf-8"),
            },
        })
        definition(12, 33, uri, 8, 6, 16)
        definition(13, 21, uri, 10, 8, 14)
        config_uri = (Path(build) / "generated" / "fixture" / "config.hpp").resolve().as_uri()
        definition(10, 33, config_uri, 0, 8, 25)
        # Requests are serialized after the initial parse, so its diagnostics are ready.
        request("textDocument/documentSymbol", {"textDocument": {"uri": uri}})
        errors = [item for item in diagnostics if item.get("severity") == 1]
        if errors:
            raise AssertionError(f"Header diagnostics: {errors}")
        request("shutdown", None)
        send("exit", None)
        process.wait(timeout=15)
        if process.returncode:
            raise AssertionError(f"clangd exited {process.returncode}")
        print("PASS fresh clangd: exact class, member and generated-config definition ranges")
    except (AssertionError, EOFError, OSError, ValueError, queue.Empty,
            subprocess.TimeoutExpired):
        sys.stderr.write("".join(stderr))
        raise
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        output_thread.join(timeout=5)
        log_thread.join(timeout=5)
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()


if __name__ == "__main__":
    check(*sys.argv[1:])
