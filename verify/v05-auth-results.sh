#!/usr/bin/env bash
# V-05  Phan tich header cua thu VUA den - bang chung "3 lop deu pass".
#   Chay tren vm-mail2 (nguoi nhan) hoac vm-mail1:
#     sudo bash verify/v05-auth-results.sh ketoan
#     sudo bash verify/v05-auth-results.sh ketoan 3      (3 thu gan nhat)
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
USER="${1:?Thieu ten hop thu, vi du ketoan}"
N="${2:-1}"
DIR="/home/$USER/Maildir/new"
HOSTF="$(hostname -s)"
EVID="/root/evidence/$HOSTF"; mkdir -p "$EVID"

[ -d "$DIR" ] || { echo "Loi: khong co $DIR"; exit 1; }
COUNT=$(ls -1 "$DIR" 2>/dev/null | wc -l)
echo "So thu trong hop thu $USER: $COUNT"
[ "$COUNT" = "0" ] && { echo "Chua co thu nao - chay verify/v02-happy-path.sh tren vm-client truoc."; exit 1; }

for F in $(ls -1t "$DIR" | head -"$N"); do
  python3 "$PROJECT/verify/parse-headers.py" --body "$DIR/$F"
done | tee "$EVID/v05-auth-results-$USER.txt"

echo
echo "=== Dong lien quan trong /var/log/mail.log (20 dong cuoi) ==="
grep -aE "policyd-spf|opendkim|milter|opendmarc|postfix/local" /var/log/mail.log 2>/dev/null | tail -20 | tee -a "$EVID/v05-auth-results-$USER.txt"
echo
echo "=== Trich xuat bang cho bao cao (muc 3.6.2) ==="
grep -aoE 'spf=[a-z]+|dkim=[a-z]+|dmarc=[a-z]+' "$EVID/v05-auth-results-$USER.txt" | sort -u | sed 's/^/  /'
echo
