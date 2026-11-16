#!/usr/bin/env bash
# Day ban ghi dinh danh (TXT) len vm-dns va tai lai zone.
#   CACH 1 (ban ghi ngan, SPF/DMARC):
#     sudo bash defense/dns-add-record.sh congtyA.test '@' 'v=spf1 ip4:10.30.0.20 mx -all'
#     sudo bash defense/dns-add-record.sh congtyA.test '_dmarc' 'v=DMARC1; p=reject; ...'
#     sudo bash defense/dns-add-record.sh congtyB.test 'mail._domainkey' 'v=DKIM1; k=rsa; p=...'
#   CACH 2 (ban ghi DKIM dai, nhieu dong - dan noi dung tu mail.txt):
#     sudo bash defense/dns-add-record.sh congtyA.test --paste
#     (dan toan bo noi dung /etc/dkimkeys/mail.txt, nhan Enter roi Ctrl-D)
#
# Script luon: kiem tra trung lap -> tang serial -> named-checkzone -> rndc reload -> dig.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root TREN vm-dns (10.30.0.10)"; exit 1; }
[ -f /etc/bind/named.conf.local ] || { echo "Loi: may nay chua cai BIND (chay install/10-dns.sh truoc)"; exit 1; }

DOMAIN="${1:?Thieu domain, vi du: congtyA.test}"
IDENT="/var/lib/bind/lab/$DOMAIN.identity"
ZONE="/var/lib/bind/db.$DOMAIN"
[ -f "$IDENT" ] || { echo "Loi: khong tim thay $IDENT (zone chua duoc dang ky?)"; exit 1; }
[ -f "$ZONE" ]  || { echo "Loi: khong tim thay $ZONE"; exit 1; }

MODE="${2:?Thieu label (vi du @ | _dmarc | mail._domainkey) hoac --paste}"

if [ "$MODE" = "--paste" ]; then
  echo "Dan toan bo noi dung ban ghi vao day (moi dong la 1 phan cua TXT), ket thuc bang Ctrl-D:"
  NEW="$(cat)"
else
  TXT="${3:?Thieu noi dung TXT}"
  case "$TXT" in *'"'*) echo "Loi: noi dung TXT khong duoc chua dau nhay kep"; exit 1;; esac
  case "$MODE" in
    '@') NAME="$DOMAIN." ;;
    *.*) NAME="$MODE" ;;
    *)   NAME="$MODE.$DOMAIN." ;;
  esac
  NEW="$NAME	IN	TXT	\"$TXT\""
fi

# Ghi (idempotent: da co thi khong ghi trung)
if [ "$MODE" = "--paste" ]; then
  if grep -q 'p=' "$IDENT" 2>/dev/null; then
    echo "CANH BAO: $IDENT da co ban ghi DKIM (p=...). Ghi trung se lam zone co 2 khoa."
    echo "        Kiem tra: grep -n 'p=' $IDENT   |  xoa dong cu neu can."
  fi
fi
if grep -qF -- "$NEW" "$IDENT" 2>/dev/null; then
  echo "Ban ghi da ton tai trong $IDENT - khong ghi them."
else
  printf '%s\n' "$NEW" >> "$IDENT"
  echo "Da ghi vao $IDENT:"
  printf '  %s\n' "$NEW"
fi
echo "--- $IDENT hien co ---"
grep -vE '^\s*(;|$)' "$IDENT" | sed 's/^/  /'

# Tang serial (YYMMNN + 2 so dem, cung ngay thi dem them 1)
TODAY="$(date -u +%Y%m%d)"
CUR="$(sed -n -E 's/^[[:space:]]*([0-9]{10})[[:space:]]*;[[:space:]]*serial.*/\1/p' "$ZONE" | head -1)"
[ -n "$CUR" ] || { echo "Loi: doc khong duoc serial trong $ZONE"; exit 1; }
if [ "${CUR:0:8}" = "$TODAY" ]; then
  NEXT="$TODAY$(printf '%02d' $(( 10#${CUR:8:2} + 1 )))"
else
  NEXT="${TODAY}01"
fi
sed -i -E "s/^([[:space:]]*)[0-9]{10}([[:space:]]*;[[:space:]]*serial)/\1${NEXT}\2/" "$ZONE"
echo "Serial: $CUR -> $NEXT"

echo
echo "=== named-checkzone ==="
named-checkzone "$DOMAIN" "$ZONE"

echo
echo "=== rndc reload ==="
rndc reload "$DOMAIN" && sleep 1
systemctl is-active bind9

echo
echo "=== doc lai bang dig (day la bang chung cho bao cao) ==="
{
  echo "# $(date -u '+%F %T') UTC - sau khi reload zone $DOMAIN (serial $NEXT)"
  dig @10.30.0.10 "$DOMAIN" SOA +noall +answer
  echo "--- moi ban ghi TXT trong zone $DOMAIN ---"
  dig @10.30.0.10 "$DOMAIN" TXT +noall +answer
  for L in _dmarc mail._domainkey; do
    echo "--- $L.$DOMAIN TXT ---"
    dig @10.30.0.10 "$L.$DOMAIN" TXT +noall +answer
  done
  echo "--- toan bo noi dung TXT (dig dang day du, khong cat ngan) ---"
  dig @10.30.0.10 "$DOMAIN" TXT +noall +answer +cmd
  dig @10.30.0.10 _dmarc."$DOMAIN" TXT +noall +answer +cmd
  dig @10.30.0.10 mail._domainkey."$DOMAIN" TXT +noall +answer +cmd
} | tee -a "/root/evidence/dns/dig-identity-$DOMAIN.txt"
