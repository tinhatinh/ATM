#!/usr/bin/env python3
"""Self-test cho attacks/strip_starttls.py - chi dung 127.0.0.1, khong ra ngoai.
Khoi dong: (1) fake MTA loi 12525 co quang ba STARTTLS, (2) proxy 12526 -> 12525,
(3) client EHLO + DATA co chu so tai khoan 9999999999.
Kiem tra: client KHONG thay STARTTLS; MTA that nhan duoc 1029384756.
"""
import socket, subprocess, sys, threading, time, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
PROXY = os.path.join(HERE, 'strip_starttls.py')
UP_PORT, PX_PORT = 12525, 12526
received = []


def fake_mta():
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('127.0.0.1', UP_PORT)); s.listen(4)
    while True:
        c, _ = s.accept()
        c.sendall(b'220 fake-mta.congtyB.test ESMTP Postfix\r\n')
        while True:
            d = c.recv(4096)
            if not d:
                break
            up = d.upper()
            if b'DATA' in up:
                c.sendall(b'354 End data with <CR><LF>.<CR><LF>\r\n')
                body = b''
                while b'\r\n.\r\n' not in body:
                    body += c.recv(4096)
                received.append(body)
                c.sendall(b'250 2.0.0 Ok: queued ABC123\r\n')
            elif b'QUIT' in up:
                c.sendall(b'221 2.0.0 Bye\r\n'); c.close(); break
            elif b'EHLO' in up:
                c.sendall(b'250-fake-mta\r\n250-PIPELINING\r\n250-SIZE 10485760\r\n250-STARTTLS\r\n250 HELP\r\n')
            else:
                c.sendall(b'250 2.1.0 Ok\r\n')


def client():
    c = socket.create_connection(('127.0.0.1', PX_PORT), timeout=5)
    banner = c.recv(200)
    c.sendall(b'EHLO lab-client\r\n'); time.sleep(0.4)
    ehlo = c.recv(2000)
    c.sendall(b'MAIL FROM:<giamdoc@congtyA.test>\r\n'); time.sleep(0.2); c.recv(500)
    c.sendall(b'RCPT TO:<ketoan@congtyB.test>\r\n'); time.sleep(0.2); c.recv(500)
    c.sendall(b'DATA\r\n'); time.sleep(0.2); c.recv(500)
    c.sendall(b'From: Ke toan <ketoan@congtyB.test>\r\nSubject: Hop dong\r\n\r\n'
              b'Chuyen khoan vao tai khoan 9999999999 AlphaBank.\r\n.\r\n')
    time.sleep(0.6)
    after = c.recv(500)
    c.sendall(b'QUIT\r\n'); time.sleep(0.2); c.recv(200); c.close()
    return banner, ehlo, after


if __name__ == '__main__':
    threading.Thread(target=fake_mta, daemon=True).start()
    time.sleep(0.5)
    log = os.path.join(HERE, 'proxy-selftest.log')
    p = subprocess.Popen([sys.executable, PROXY, '--listen', str(PX_PORT),
                          '--upstream', '127.0.0.1:%d' % UP_PORT,
                          '--tamper', '9999999999', '1029384756', '--log', log])
    time.sleep(1.5)
    try:
        banner, ehlo, after = client()
        time.sleep(0.5)
        got = b''.join(received)
        print('=' * 60)
        print('CLIENT nhan EHLO :'); print(ehlo.decode(errors='replace'))
        print('CLIENT nhan sau DATA :', after.decode(errors='replace').strip())
        print('MTA that nhan duoc   :'); print(got.decode(errors='replace'))
        print('=' * 60)
        checks = [
            ('proxy noi dung', b'220' in banner),
            ('EHLO toi client KHONG con STARTTLS', b'STARTTLS' not in ehlo.upper()),
            ('MTA that van nhan duoc than thu', len(got) > 0),
            ('So tai khoan bi sua thanh 1029384756', b'1029384756' in got and b'9999999999' not in got),
            ('Header + envelope duoc chuyen tiep', b'ketoan@congtyB.test' in got),
        ]
        ok = True
        for name, res in checks:
            print(('  PASS  ' if res else '  FAIL  ') + name); ok = ok and res
        print('\nKET LUAN:', 'proxy hoat dong dung thiet ke' if ok else 'CO VANS - xem log', log)
    finally:
        p.terminate()
