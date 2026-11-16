#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Phan tich header thu dien tu: mo rong cac dong ke tiep (folded headers),
trich Authentication-Results / Received-SPF / DKIM-Signature va ket luan tung
co che. Dung duoc tren may Ubuntu (trong verify/v05) hoac mo file .eml luu tu
Maildir ve may Windows de phan tich lai.

  python3 verify/parse-headers.py /home/ketoan/Maildir/new/1759....:2,S
  python3 verify/parse-headers.py --all /home/ketoan/Maildir/new
"""
import os
import re
import sys

INTEREST = ['X-Lab-Mark', 'Return-Path', 'Received-SPF', 'Authentication-Results',
            'DKIM-Signature', 'From', 'To', 'Subject', 'Message-ID', 'Date',
            'Content-Type']


def read_message(path):
    with open(path, 'rb') as f:
        data = f.read()
    head, sep, body = data.partition(b'\r\n\r\n')
    if not sep:
        head, sep, body = data.partition(b'\n\n')
    lines = [l.decode('utf-8', 'replace') for l in head.splitlines()]
    unfolded = []
    for l in lines:
        if l[:1] in (' ', '\t') and unfolded:
            unfolded[-1] += ' ' + l.strip()
        else:
            unfolded.append(l.rstrip())
    return unfolded, body.decode('utf-8', 'replace')


def verdict(path, show_body=False):
    hdr, body = read_message(path)
    name = os.path.basename(path)
    print('=' * 78)
    print('FILE: %s' % path)
    print('-' * 78)
    for h in hdr:
        key = h.split(':', 1)[0].strip()
        if key in INTEREST:
            print('  %s' % h[:400])
    joined = '\n'.join(hdr).lower()

    res = {}
    for mech in ('spf', 'dkim', 'dmarc'):
        m = re.search(r'%s=(\w+)' % mech, joined)
        res[mech] = m.group(1) if m else 'khong co trong header'
    if res['spf'] == 'khong co trong header':
        # policyd-spf ghi ket qua vao header 'Received-SPF: Pass (mailfrom) …',
        # khong dung tag spf= trong Authentication-Results -> phai doc tu do.
        m = re.search(r'received-spf:\s*(\w+)', joined)
        if m:
            res['spf'] = m.group(1).lower()
    d_dom = re.search(r'd=([^;\s]+)', joined)
    d_sel = re.search(r's=([^;\s]+)', joined)
    print('-' * 78)
    print('  KET LUU CO CHE:')
    for mech in ('spf', 'dkim', 'dmarc'):
        flag = {'pass': 'OK  ', 'fail': 'FAIL', 'none': 'none', 'neutral': 'neu '}.get(res[mech], '?   ')
        print('    %-6s = %-8s [%s]' % (mech.upper(), res[mech], flag))
    if d_dom:
        print('    DKIM d= %s   s= %s' % (d_dom.group(1), d_sel.group(1) if d_sel else '?'))
    print('  Nhan xet:')
    if res['dmarc'] == 'pass' and res['dkim'] == 'pass' and res['spf'] == 'pass':
        print('    Thu duoc xac thuc day du o ca 3 lop -> duoc phat va (thuong) vao Inbox.')
    elif res['dmarc'] == 'pass' and (res['spf'] != 'pass' or res['dkim'] != 'pass'):
        print('    DMARC pass chi can MOT trong hai lop pass -> kiem tra lop con lai bi gi.')
    elif res['dmarc'] == 'fail':
        print('    DMARC fail -> chinh sach p=reject buoc MTA tu choi (hoac quarantine).')
    else:
        print('    Khong co Authentication-Results: ben nhan CHUA bat kiem tra dinh danh.')
    if show_body:
        print('-' * 78)
        print(body[:600])
    return res


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    show_body = False
    if '--body' in args:
        args.remove('--body'); show_body = True
    if args[0] == '--all':
        d = args[1]
        files = sorted(os.path.join(d, f) for f in os.listdir(d))
        for fp in files[-5:]:
            verdict(fp, show_body)
        print('\n(tong so thu trong thu muc: %d)' % len(files))
    else:
        for fp in args:
            verdict(fp, show_body)


if __name__ == '__main__':
    main()
