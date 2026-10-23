"""Records every byte that reaches the terminal, with timestamps, until Ctrl-D (scripts/record-demo.sh)."""
import json
import os
import sys
import termios
import time
import tty

log_path = sys.argv[1]
fd = sys.stdin.fileno()
saved = termios.tcgetattr(fd)
sys.stdout.write("\033[2J\033[H\033[1mtypo demo\033[0m: recording, don't touch the keyboard\r\n\r\n")
sys.stdout.flush()
start = time.monotonic()
tty.setraw(fd)
try:
    with open(log_path, "w") as log:
        while True:
            data = os.read(fd, 64)
            if not data or b"\x04" in data:
                break
            log.write(json.dumps({"t": round(time.monotonic() - start, 4), "b": data.hex()}) + "\n")
            log.flush()
            for byte in data:
                if byte == 0x7F:
                    os.write(1, b"\b \b")
                elif byte == 0x0D:
                    os.write(1, b"\r\n")
                else:
                    os.write(1, bytes([byte]))
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, saved)
