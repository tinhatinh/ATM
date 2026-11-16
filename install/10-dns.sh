#!/usr/bin/env bash
# Dang ky 4 zone len vm-dns (10.30.0.10) va kiem tra bang dig.
#   sudo bash install/10-dns.sh
set -euo pipefail

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
if ! hostname -I | tr ' ' '\n' | grep -qx '^10.30.0.10$'; then
  echo "DUNG LAI: may nay chua co IP 10.30.0.10 (chay install/00-base.sh truoc)."
  exit 1
fi

for f in named.conf.options named.conf.local; do
  [ -f "/etc/bind/$f.orig" ] || cp -a "/etc/bind/$f" "/etc/bind/$f.orig"
done

install -m 644 -o root -g root "$PROJECT/configs/dns/named.conf.options" /etc/bind/named.conf.options
install -m 644 -o root -g root "$PROJECT/configs/dns/named.conf.local"   /etc/bind/named.conf.local

mkdir -p /var/lib/bind/lab
install -m 644 -o bind -g bind "$PROJECT/configs/dns/zones/db.congtyA.test"   /var/lib/bind/db.congtyA.test
install -m 644 -o bind -g bind "$PROJECT/configs/dns/zones/db.congtyB.test"   /var/lib/bind/db.congtyB.test
install -m 644 -o bind -g bind "$PROJECT/configs/dns/zones/db.darkside.test"  /var/lib/bind/db.darkside.test
install -m 644 -o bind -g bind "$PROJECT/configs/dns/zones/db.10.30.0"        /var/lib/bind/db.10.30.0

for d in congtyA congtyB darkside; do
  dst="/var/lib/bind/lab/$d.test.identity"
  [ -f "$dst" ] && echo "Gi lai file dinh dang da co: $dst" || \
    install -m 644 -o root -g bind "$PROJECT/configs/dns/lab/$d.test.identity" "$dst"
done

echo
echo "=== 1. named-checkconf ==="
named-checkconf /etc/bind/named.conf

echo
echo "=== 2. named-checkzone (4 zone) ==="
named-checkzone congtyA.test     /var/lib/bind/db.congtyA.test
named-checkzone congtyB.test     /var/lib/bind/db.congtyB.test
named-checkzone darkside.test    /var/lib/bind/db.darkside.test
named-checkzone 0.30.10.in-addr.arpa /var/lib/bind/db.10.30.0

echo
echo "=== 3. khoi dong lai BIND ==="
systemctl enable bind9 >/dev/null 2>&1 || true
systemctl restart bind9
sleep 2
systemctl is-active bind9
ss -lun  | grep ':53 ' || echo "LOI: BIND khong nghe cong 53/udp"

EVID=/root/evidence/dns; mkdir -p "$EVID"
{
  echo "# time: $(date -u '+%F %T') UTC"
  echo "# cmd : dig @10.30.0.10 congtyA.test MX +noall +answer"
  dig @10.30.0.10 congtyA.test MX +noall +answer
  echo "# cmd : dig @10.30.0.10 mail1.congtyA.test A +noall +answer"
  dig @10.30.0.10 mail1.congtyA.test A +noall +answer
  echo "# cmd : dig @10.30.0.10 mail2.congtyB.test A +noall +answer"
  dig @10.30.0.10 mail2.congtyB.test A +noall +answer
  echo "# cmd : dig @10.30.0.10 -x 10.30.0.20 +noall +answer   (PTR)"
  dig @10.30.0.10 -x 10.30.0.20 +noall +answer
  echo "# --- PHAI THAY : khong co ban ghi nao duoi day (chua phong thu) ---"
  echo "# cmd : dig @10.30.0.10 TXT _dmarc.congtyA.test +noall +answer"
  dig @10.30.0.10 TXT _dmarc.congtyA.test +noall +answer
  echo "# cmd : dig @10.30.0.10 TXT congtyA.test +noall +answer   (chi co TXT ghi chu lab, khong co SPF)"
  dig @10.30.0.10 TXT congtyA.test +noall +answer
  echo "# cmd : dig @10.30.0.10 mail._domainkey.congtyA.test TXT +noall +answer"
  dig @10.30.0.10 mail._domainkey.congtyA.test TXT +noall +answer
  echo "# cmd : dig @10.30.0.10 www.google.com +noall +answer   (recursion no -> khong tra loi)"
  dig @10.30.0.10 www.google.com +noall +answer +comments | head -8
} | tee "$EVID/10-dns-dig.txt"

echo
echo "=== 4. kiem tra tu may khac (lam tren vm-mail1) ==="
echo
