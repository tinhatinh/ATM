#!/usr/bin/env bash
# AT-04b  Bang chung phat thu - chay tren vm-mail2 (10.30.0.30)
#   sudo bash attacks/at04-check-inbox.sh ketoan
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

USER="${1:?Thieu ten hop thu, vi du ketoan}"
HOME_DIR="/home/$USER"
EVID="/root/evidence/mail2"; mkdir -p "$EVID"
OUT="$EVID/at04-inbox-$USER.txt"
# hostname -f co the tra ve 'vm-mail2' (khong co dau cham) sau khi /etc/hosts co
# dong 127.0.1.1, nen lay ten dinh danh tu myhostname cua Postfix.
MYFQDN="$(postconf -h myhostname 2>/dev/null || hostname -f)"

{
  echo "# time $(date -u '+%F %T') UTC - may $MYFQDN - hop thu cua $USER"
  echo "--- [1] Danh sach thu trong Maildir/new ---"
  ls -l "$HOME_DIR/Maildir/new" | tail -8

  NEWEST="$(ls -1t "$HOME_DIR/Maildir/new" 2>/dev/null | head -1 || true)"
  if [ -z "$NEWEST" ]; then
    echo "CHUA CO THU nao trong Maildir/new - quay lai vm-atk chay at04 truoc."
    exit 1
  fi
  echo
  echo "--- [2] Toan bo dau de cua thu moi nhat: $NEWEST ---"
  sed -n '1,60p' "$HOME_DIR/Maildir/new/$NEWEST" | sed -e '/^\s*$/q' -e 's/^/  /'
  echo
  echo "--- [3] Cac dau de dinh danh (phai VANG o Giai doan 1) ---"
  echo "# Authentication-Results:"; grep -c '^Authentication-Results:' "$HOME_DIR/Maildir/new/$NEWEST" || true
  echo "# Received-SPF:";           grep -c '^Received-SPF:'           "$HOME_DIR/Maildir/new/$NEWEST" || true
  echo "# DKIM-Signature:";         grep -c '^DKIM-Signature:'         "$HOME_DIR/Maildir/new/$NEWEST" || true
  echo "# DMARC-Result / Authentication-Results dkim=:";  grep -c 'dkim=' "$HOME_DIR/Maildir/new/$NEWEST" || true
  echo
  echo "--- [4] Header quan sat duoc tu MUA (nguoi nhan thay dieu gi) ---"
  echo "# From        : $(grep -m1 '^From:' "$HOME_DIR/Maildir/new/$NEWEST")"
  echo "# Reply-To    : $(grep -m1 '^Reply-To:' "$HOME_DIR/Maildir/new/$NEWEST" || echo '(khong co)')"
  echo "# Subject     : $(grep -m1 '^Subject:' "$HOME_DIR/Maildir/new/$NEWEST")"
  echo "# Received    : duoi cung (may nao thuc phat)"
  grep '^Received:' "$HOME_DIR/Maildir/new/$NEWEST" | tail -2 | sed 's/^/  /'
  echo
  echo "--- [5] Log postfix + dovecot chung minh phat thanh cong ---"
  echo "# grep queueid/noi dung trong /var/log/mail.log (15 dong cuoi lien quan $USER)"
  grep -a "$USER@" /var/log/mail.log 2>/dev/null | grep -a -E 'postfix/local|dovecot|status=SENT|delivered' | tail -8 || \
    journalctl -u postfix --no-pager -n 20 | grep -a "$USER" || true
} | tee "$OUT"

echo
echo
