#!/usr/bin/env bash
# Dung 2 may mail o TRANG THAI DE TON THUONG (Giai doan 1) - dung dung
# trang thai ma mot mail server bo ngac mac dinh dau tien co that, de cac
# tan cong AT-01..AT-06 chay THAT. Phong thu o defense/d01..d05.
#   vm-mail1 : sudo bash install/20-mail.sh alpha
#   vm-mail2 : sudo bash install/20-mail.sh beta
set -euo pipefail

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
ROLE="${1:?Role phai la alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }

case "$ROLE" in
  alpha)  HOST=mail1; DOMAIN=congtyA.test; IP=10.30.0.20; USERS="giamdoc admin" ;;
  beta)   HOST=mail2; DOMAIN=congtyB.test; IP=10.30.0.30; USERS="ketoan admin" ;;
  *) echo "Role phai la: alpha (tren vm-mail1) hoac beta (tren vm-mail2)"; exit 1 ;;
esac
FQDN="$HOST.$DOMAIN"
EVID=/root/evidence/$HOST; mkdir -p "$EVID"

# ---------- 1. Nguoi dung local (hop thu Maildir) ----------
for u in $USERS; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  echo "$u:Lab@2026" | chpasswd
  install -d -m 700 -o "$u" -g "$u" "/home/$u/Maildir"
  install -d -m 700 -o "$u" -g "$u" "/home/$u/Maildir/new" "/home/$u/Maildir/cur" "/home/$u/Maildir/tmp"
  # install -d KHONG doi chu thong ke cha no tao an, nen phai ep chu so huu ca cay:
  chown -R "$u:$u" "/home/$u/Maildir"
done
echo "Da tao user: $USERS  (mat khau lab: Lab@2026)"

# ---------- 2. Postfix - trang thai mac dinh / de ton thuong ----------
echo "$DOMAIN" > /etc/mailname

postconf -c /etc/postfix -e \
  "myhostname=$FQDN" \
  "mydomain=$DOMAIN" \
  "myorigin=\$mydomain" \
  "mydestination=\$myhostname, localhost.\$mydomain, localhost, \$mydomain" \
  "mynetworks=127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 10.30.0.0/24" \
  "relay_domains=" \
  "smtpd_relay_restrictions=permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination" \
  "smtpd_recipient_restrictions=permit_mynetworks" \
  "smtpd_sender_restrictions=" \
  "smtpd_helo_required=no" \
  "disable_vrfy_command=no" \
  "home_mailbox=Maildir/" \
  "mailbox_command=" \
  "smtpd_tls_security_level=none" \
  "smtp_tls_security_level=none" \
  "smtpd_tls_auth_only=no" \
  "smtpd_sasl_type=dovecot" \
  "smtpd_sasl_path=private/auth" \
  "smtpd_sasl_auth_enable=yes" \
  "smtpd_sasl_security_options=noanonymous" \
  "smtpd_milters=" \
  "non_smtpd_milters=" \
  "compatibility_level=3.6"

# Cong 587 (submission) da co san trong master.cf cua Ubuntu, chi bi comment.
if ! grep -qE '^submission[[:space:]]+inet' /etc/postfix/master.cf; then
  sed -i -E 's/^#(submission[[:space:]]+inet[[:space:]]+n)/\1/' /etc/postfix/master.cf
fi
grep -qE '^submission[[:space:]]+inet' /etc/postfix/master.cf || \
  { echo "LOI: khong mo duoc dich vu submission trong /etc/postfix/master.cf"; exit 1; }

postalias /etc/aliases
postfix check
systemctl enable postfix >/dev/null 2>&1 || true
systemctl restart postfix

# ---------- 3. Dovecot: IMAP cho user local, CHUA ma hoa ----------
cat > /etc/dovecot/conf.d/99-lab.conf <<'EOF'
# ==== ATM Topic03 - Giai doan 1: TRANG THAI DE TON THUONG ====
# File 99-* duoc doc CUOI CUNG trong conf.d (sap xep theo ASCII) nen ghi de 10-*.
mail_location = maildir:~/Maildir
protocols = imap

# Cho phep AUTH LOGIN tren ket noi KHONG ma hoa - can cho AT-03 (doan cap
# credential). Day la loi CO Y, defense/d02 doi thanh disable_plaintext_auth = yes.
disable_plaintext_auth = no
ssl = no

auth_mechanisms = plain login

# Mo socket SASL trong quarantine cua Postfix (khong can libsasl2-modules)
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

systemctl enable dovecot >/dev/null 2>&1 || true
systemctl restart dovecot

echo
echo "=== XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - role $ROLE - $FQDN"
  echo "--- cong nghe: ss -ltnp ---"
  ss -ltnp | grep -E ':(25|587|143|993)[[:space:]]' || echo "LOI: khong thay cong 25/587/143"
  echo "--- postconf -n ---"
  postconf -n | grep -E '^(myhostname|mydomain|myorigin|mydestination|mynetworks|relay_domains|home_mailbox|mailbox_command|smtpd_relay_restrictions|smtpd_recipient_restrictions|smtpd_sender_restrictions|smtpd_helo_required|disable_vrfy_command|smtpd_tls_security_level|smtp_tls_security_level|smtpd_tls_auth_only|smtpd_sasl_auth_enable|smtpd_sasl_type|smtpd_sasl_path|smtpd_milters|non_smtpd_milters) *='
  echo "--- doveconf -n ---"
  doveconf -n | grep -E '^(mail_location|protocols|disable_plaintext_auth|ssl|auth_mechanisms) *='
  echo "--- socket SASL ---"
  ls -l /var/spool/postfix/private/auth
  echo "--- nguoi dung ---"
  for u in $USERS; do id "$u"; done
} | tee "$EVID/20-mail-$ROLE.txt"

echo
echo "--- Smoke test: EHLO toi chinh no (khong gui thu) ---"
if command -v swaks >/dev/null 2>&1; then
  swaks --server 127.0.0.1 --port 25 --quit-after EHLO \
        --from "probe@$DOMAIN" --to "probe@$DOMAIN" 2>&1 | tail -20
else
  echo "BO QUA smoke test: may nay chua cai swaks (khong anh huong cau hinh)."
  echo "Kiem tra bang: postconf -h myhostname  va  systemctl is-active postfix dovecot"
fi

