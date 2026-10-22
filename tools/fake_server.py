#!/usr/bin/env python3
# Tiny telnet+GMCP server for trying the package without the real game.
#
# Offers GMCP, then plays a fixture: a JSON list of entries, each
#   {"delay_ms": 100, "package": "Char.Vitals", "payload": {...}}
# sent as a GMCP frame, or
#   {"delay_ms": 100, "text": "A line of game output."}
# sent as a plain line. Every line the client types is echoed back as
# "You typed: ...", and every GMCP message the client sends is logged
# on this script's stdout, so you can see what a key or command sent.
#
# Usage:  tools/fake_server.py <port> <fixture.json>
# Then, in a Blightmud whose config loads the package for 127.0.0.1:
#   /connect 127.0.0.1 <port>

import asyncio
import json
import sys

IAC, SB, SE = 255, 250, 240
WILL, WONT, DO, DONT = 251, 252, 253, 254
GMCP = 201


def gmcp_frame(package, payload):
    body = package.encode("utf-8")
    if payload is not None:
        body += b" " + json.dumps(payload, ensure_ascii=False).encode("utf-8")
    body = body.replace(bytes([IAC]), bytes([IAC, IAC]))
    return bytes([IAC, SB, GMCP]) + body + bytes([IAC, SE])


async def read_client(reader, writer):
    buf = bytearray()
    line = bytearray()
    try:
        while True:
            chunk = await reader.read(4096)
            if not chunk:
                return
            buf += chunk
            i = 0
            while i < len(buf):
                b = buf[i]
                if b == IAC and i + 1 < len(buf):
                    cmd = buf[i + 1]
                    if cmd == SB:
                        end = buf.find(bytes([IAC, SE]), i)
                        if end < 0:
                            break
                        body = bytes(buf[i + 3:end]).decode("utf-8", "replace")
                        if buf[i + 2] == GMCP:
                            print(f"[fake_server] client GMCP: {body}", flush=True)
                        i = end + 2
                        continue
                    i += 3 if cmd in (WILL, WONT, DO, DONT) else 2
                    continue
                if b == 10:
                    text = line.decode("utf-8", "replace").rstrip("\r")
                    print(f"[fake_server] client text: {text}", flush=True)
                    writer.write(f"You typed: {text}\r\n".encode("utf-8"))
                    await writer.drain()
                    line.clear()
                elif b != 13:
                    line.append(b)
                i += 1
            del buf[:i]
    except (ConnectionResetError, asyncio.CancelledError):
        return


async def handle(reader, writer, fixture):
    print(f"[fake_server] client connected: {writer.get_extra_info('peername')}", flush=True)
    writer.write(bytes([IAC, WILL, GMCP]))
    await writer.drain()
    reading = asyncio.create_task(read_client(reader, writer))
    try:
        await asyncio.sleep(0.5)
        for ev in fixture:
            await asyncio.sleep(ev.get("delay_ms", 0) / 1000.0)
            if "text" in ev:
                writer.write((ev["text"] + "\r\n").encode("utf-8"))
            else:
                writer.write(gmcp_frame(ev["package"], ev.get("payload")))
            await writer.drain()
        await reading
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        reading.cancel()
        writer.close()


async def main(port, fixture_path):
    with open(fixture_path, encoding="utf-8") as fh:
        fixture = json.load(fh)
    server = await asyncio.start_server(lambda r, w: handle(r, w, fixture), "127.0.0.1", port)
    print(f"[fake_server] listening on 127.0.0.1:{port}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: fake_server.py <port> <fixture.json>")
    asyncio.run(main(int(sys.argv[1]), sys.argv[2]))
