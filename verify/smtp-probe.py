#!/usr/bin/env python3
"""Do dung ncat: gui mot chuoi lenh SMTP toi MTA va in nguyen van phan hoi.

ncat chi duoc cai o vai vm-atk, trong khi nhieu kich ban chay tren vm-client va
vm-mail1/2 (chi co python3 + openssl). Lenh doc tu stdin, moi dong = mot lenh
SMTP; 'DATA' dung o do (khong gui than thu) de khong vo tinh gay nghet bo dem.

  printf 'EHLO test\\nQUIT\\n' | python3 verify/smtp-probe.py 10.30.0.20 25
"""
import socket
import sys


def main():
    if len(sys.argv) != 3:
        print("cach dung: smtp-probe.py HOST PORT < lenh.txt", file=sys.stderr)
        return 2
    host, port = sys.argv[1], int(sys.argv[2])
    cmds = sys.stdin.read().splitlines()

    sock = socket.create_connection((host, port), 6)
    pipe = sock.makefile("rb")

    def readline():
        raw = pipe.readline()
        if not raw:
            print("(doi phuong dong ket noi som)")
            return None
        print(raw.decode(errors="replace").rstrip("\r\n"))
        return raw

    def read_multiline():
        """Phan hoi EHLO/HELO nhieu dong: ket thuc khi khong con dau '-'."""
        while True:
            raw = pipe.readline()
            if not raw:
                print("(doi phuong dong ket noi som)")
                return
            text = raw.decode(errors="replace").rstrip("\r\n")
            print(text)
            if len(text) < 4 or text[3] != "-":
                return

    readline()  # banner 220
    for cmd in cmds:
        sock.sendall((cmd + "\r\n").encode())
        verb = cmd.split(" ", 1)[0].upper()
        if verb in ("EHLO", "HELO"):
            read_multiline()
        elif verb == "DATA":
            readline()
            break
        else:
            if readline() is None:
                break
    if not any(c.split(" ", 1)[0].upper() == "QUIT" for c in cmds):
        sock.sendall(b"QUIT\r\n")
        try:
            readline()
        except OSError:
            pass
    sock.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
