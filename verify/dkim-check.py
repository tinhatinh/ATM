#!/usr/bin/env python3
"""Kiem chung chu ky DKIM cua mot thuu luu trong Maildir, KHONG can toi milter.

Bo tro cho lab khi OpenDKIM 2.11 (lien ket libunbound) khong lay duoc khoa DNS
trong mang isolate: chung toi van churn nguyen chu ky RSA-SHA256 da ky bang
chinh khoa cong khai trong ban ghi mail._domainkey.<d>.

Cach kiem tra, dung theo RFC 6376 muc 3.5:
  1. tach header/body, doc tag trong DKIM-Signature (d, s, h, c, bh, b);
  2. tinh lai bh = base64(SHA-256(canonical hoa don body));
  3. dung lai chuoi ky = cac header theo thutu_xuat_hien + phan DKIM-Signature
     voi gia tri 'b=' trong rong;
  4. lay khoa tu 'dig TXT s._domainkey.d' (khong dung den libunbound),
     goi 'openssl dgst -verify' de xac minh chu ky.

  python3 verify/dkim-check.py <duong-dan-file-thu> [dns-server]
"""
import base64
import hashlib
import os
import re
import subprocess
import sys
import tempfile

TAG_RE = re.compile(r"([A-Za-z]+)=([^;]*)")


def split_message(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    head, _, body = raw.partition(b"\n\n")
    if not _:
        head, _, body = raw.partition(b"\r\n\r\n")
    return head, body


def unfold(head):
    """Tra ve danh sach (ten, giatri) da noi dong tiep dien (RFC 5322 3.2.2)."""
    lines, fields = head.replace(b"\r\n", b"\n").decode("utf-8", "replace").split("\n"), []
    cur = None
    for line in lines:
        if not line:
            continue
        if line[0] in (" ", "\t") and cur is not None:
            cur = (cur[0], cur[1] + " " + line.strip())
        else:
            if cur:
                fields.append(cur)
            name, _, value = line.partition(":")
            cur = (name, value.strip())
    if cur:
        fields.append(cur)
    return fields


def canon_header_relaxed(name, value):
    value = re.sub(r"[ \t]+", " ", value.strip())
    return f"{name.lower()}:{value}\r\n"


def canon_body_simple(body):
    """RFC 6376 3.4.3: giu nguyen, chi bo cac DONG RONG o cuoi; dong cuoi van
    giu CRLF cua no (Postfix luu Maildir bang LF nen phai doi lai CRLF)."""
    body = re.sub(rb"\r\n", b"\n", body)
    body = re.sub(rb"\n+\Z", b"", body)
    return body.replace(b"\n", b"\r\n") + b"\r\n"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    dns = sys.argv[2] if len(sys.argv) > 2 else "10.30.0.10"

    head, body = split_message(path)
    fields = unfold(head)
    sig_fields = [v for n, v in fields if n.lower() == "dkim-signature"]
    if not sig_fields:
        print("KHONG co header DKIM-Signature trong buou thu.")
        return 1
    tags = dict((k.lower(), v.strip()) for k, v in TAG_RE.findall(sig_fields[0]))
    for key in ("d", "s", "h", "bh", "b"):
        if key not in tags:
            print(f"Thieu tag {key}= trong DKIM-Signature.")
            return 1

    domain, selector = tags["d"], tags["s"]
    alg = tags.get("a", "rsa-sha256")
    print(f"[1] Buou thu      : {path}")
    print(f"    d={domain}  s={selector}  a={alg}  c={tags.get('c', 'simple/simple')}")

    # --- (2) body hash -------------------------------------------------------
    body_hash = base64.b64encode(hashlib.sha256(canon_body_simple(body)).digest()).decode()
    print(f"[2] bh tinh lai   : {body_hash}")
    print(f"    bh trong header: {tags['bh']}")
    print("    => {" + ("KHOP" if body_hash == tags["bh"] else "KHONG KHOP") + "}")

    # --- (3) chuoi ky --------------------------------------------------------
    # RFC 6376 3.5: lay dung so lan xuat hien cua moi ten trong danh sach h=,
    # theo thu tu xuat hien trong message, roi noi tiep phan DKIM-Signature
    # (canonical hoa kieu relaxed) cat den dung truoc gia tri cua tag b=.
    quota = {}
    for n in tags["h"].split(":"):
        n = n.strip().lower()
        if n:
            quota[n] = quota.get(n, 0) + 1
    parts, used = [], []
    for name, value in fields:
        low = name.lower()
        if low == "dkim-signature" or quota.get(low, 0) <= 0:
            continue
        quota[low] -= 1
        used.append(low)
        parts.append(canon_header_relaxed(name, value))
    sig_raw = canon_header_relaxed(
        "dkim-signature", next(v for n, v in fields if n.lower() == "dkim-signature"))
    head_to_sign = "".join(parts) + sig_raw[:sig_raw.rindex(" b=") + 1] + "b="
    print(f"[3] Header da ky  : {', '.join(used)}")

    # --- (4) lay khoa tu DNS (trinh duyet cua he thong, khong phai libunbound)
    name = f"{selector}._domainkey.{domain}"
    out = subprocess.run(["dig", f"@{dns}", name, "TXT", "+short"],
                         capture_output=True, text=True, check=False).stdout
    p = "".join(re.findall(r'"([^"]*)"', out))
    m = re.search(r"p=(\S+)", p)
    if not m:
        print(f"[4] dig @{dns} TXT {name} -> khong lay duoc khoa:\n{out.strip() or '(rong)'}")
        return 1
    der = base64.b64decode(m.group(1))
    pem = "-----BEGIN PUBLIC KEY-----\n" + base64.encodebytes(der).decode() + "-----END PUBLIC KEY-----\n"
    print(f"[4] Khoa pub {name}: {len(m.group(1))} ky tu base64 (SPKI {len(der)} byte)")

    with tempfile.TemporaryDirectory() as td:
        kf, mf, sf = f"{td}/k.pem", f"{td}/m.txt", f"{td}/s.bin"
        with open(kf, "w") as fh:
            fh.write(pem)
        with open(mf, "wb") as fh:
            fh.write(head_to_sign.encode())
        with open(sf, "wb") as fh:
            fh.write(base64.b64decode(tags["b"].replace(" ", "")))
        r = subprocess.run(["openssl", "dgst", "-sha256", "-verify", kf,
                            "-signature", sf, mf], capture_output=True, text=True)
    print("[5] openssl verify:", (r.stdout + r.stderr).strip())
    ok = "Verified OK" in r.stdout
    print("\nKET LUAN:", "Chu ky DKIM HOP LE voi khoa da cong bo trong DNS."
          if ok else "Chu ky KHONG hop le (kiem lai canonical hoa hoac ban ghi DNS).")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
