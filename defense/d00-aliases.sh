#!/usr/bin/env bash
# D-00  Bao dam cac hop thu vu (alias) can thiet cho SPF/DMARC.
#   vm-mail1: sudo bash defense/d00-aliases.sh alpha
#   vm-mail2: sudo bash defense/d00-aliases.sh beta
# Alias dmarc-reports la dia chi nhan trong rua= cua ban ghi DMARC; neu khong ton tai,
# thu bao cao DMARC bi bounce va he thong loi day chu.
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
case "$ROLE" in
  alpha) DOMAIN=congtyA.test; BOX=admin ;;
  beta)  DOMAIN=congtyB.test; BOX=admin ;;
  *) echo "alpha | beta"; exit 1 ;;
esac

cp -a /etc/aliases /etc/aliases.pre-lab 2>/dev/null || true
for a in postmaster abuse dmarc-reports security-contact; do
  if ! grep -qE "^${a}:" /etc/aliases; then
    printf '%-20s %s\n' "$a:" "$BOX@$DOMAIN" >> /etc/aliases
  fi
done
# RFC 5321 yeu cau postmaster ton tai o moi he thong.
postalias /etc/aliases
systemctl reload postfix || systemctl restart postfix

echo
echo "=== XAC MINH ==="
grep -E '^(postmaster|abuse|dmarc-reports|security-contact):' /etc/aliases
echo "--- tra loi cua postalias (duong dan hash) ---"
ls -l /etc/aliases.db
echo "--- kiem tra nhan dia chi (khong co 'unknown user') ---"
sendmail -bv "dmarc-reports@$DOMAIN" 2>&1 | tail -3 || postmap -q "dmarc-reports@$DOMAIN" hash:/etc/aliases
