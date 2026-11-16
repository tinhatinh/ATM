#!/usr/bin/env bash
# D-04b  Cong khai ban ghi DKIM (TXT mail._domainkey) len DNS. Chay tren vm-dns.
#   sudo bash defense/d04b-dkim-publish.sh alpha     (cho congtyA.test)
#   sudo bash defense/d04b-dkim-publish.sh beta      (cho congtyB.test)
# Noi dung ban ghi duoc lay tu file /etc/dkimkeys/mail.txt ma d04a sinh ra ben
# mail server; nguoi quan tri dan vao day. Cach nay trung voi thuc te:
# khoa o MTA, ban ghi o DNS, va hai ben khong can tai khoan cua nhau.
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root TREN vm-dns"; exit 1; }
SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"

case "$ROLE" in
  alpha) DOMAIN=congtyA.test; HOST=mail1; IP=10.30.0.20 ;;
  beta)  DOMAIN=congtyB.test; HOST=mail2; IP=10.30.0.30 ;;
  *) echo "alpha | beta"; exit 1 ;;
esac

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# ========================================================================
#  1) Tren vm-$HOST ($IP), lay noi dung ban ghi:
#       sudo cat /etc/dkimkeys/mail.txt
#  2) Tro lai vm-dns, chay lenh duoi day ROI DAN toan bo noi dung o buoc 1,
#     ket thuc bang Ctrl-D:
#       sudo bash $PROJECT/defense/dns-add-record.sh $DOMAIN --paste
# ========================================================================
# CHIDAN

bash "$PROJECT/defense/dns-add-record.sh" "$DOMAIN" --paste

echo
echo "=== Doc lai tu DNS (ben ngoai phai thay giong ban vua dan) ==="
dig @10.30.0.10 "mail._domainkey.$DOMAIN" TXT +noall +answer +cmd
echo
echo "=== Trich xuat chieu dai chuoi p= (ky vong ~392-400 ky tu cho RSA-2048) ==="
P="$(dig @10.30.0.10 "mail._domainkey.$DOMAIN" TXT +short | tr -d '"' | sed -n 's/.*p=\(.*\)/\1/p')"
echo "  p= co ${#P} ky tu"
[ "${#P}" -ge 300 ] && echo "  OK: do dai phu hop voi khoa RSA-2048 base64." || echo  "  NGHI: ngan qua - co the dan sot dong."

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# KIEM TRA KY (tren vm-$HOST) - so khoa pub trong DNS voi khoa private local:
#     opendkim-testkey -d $DOMAIN -s mail -vvv 2>&1 | tail -8
#   - Thanh cong: khong in ra 'key not found'/'unknown key', exit code 0.
#   - That bai thuong do: (a) dan thieu dong chuoi, (b) serial zone chua tang,
#     (c) selector trong /etc/opendkim.conf khac 'mail'.
# TIET
