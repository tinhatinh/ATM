#!/usr/bin/env bash
# D-01  Dong Open Relay + siet danh sach khach duoc tin cay + chong do thu.
#   Chay tren CA HAI mail server:
#     vm-mail1: sudo bash defense/d01-close-relay.sh alpha
#     vm-mail2: sudo bash defense/d01-close-relay.sh beta
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
case "$ROLE" in
  alpha) DOMAIN=congtyA.test; HOST=mail1 ;;
  beta)  DOMAIN=congtyB.test; HOST=mail2 ;;
  *) echo "alpha | beta"; exit 1 ;;
esac
EVID=/root/evidence/$HOST; mkdir -p "$EVID"

cp -a /etc/postfix/main.cf "/etc/postfix/main.cf.pre-d01-$(date -u +%Y%m%dT%H%M%S)"

postconf -c /etc/postfix -e \
  "mynetworks=127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128" \
  "smtpd_relay_restrictions=permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination" \
  "smtpd_recipient_restrictions=reject_non_fqdn_recipient, permit_sasl_authenticated, reject_unauth_destination" \
  "smtpd_sender_restrictions=reject_non_fqdn_sender, reject_unknown_sender_domain, permit_sasl_authenticated" \
  "smtpd_helo_required=yes" \
  "smtpd_helo_restrictions=permit" \
  "disable_vrfy_command=yes" \
  "strict_rfc821_envelopes=no" \
  "message_size_limit=10485760" \
  "smtpd_error_sleep_time=1s" \
  "smtpd_soft_error_limit=10" \
  "smtpd_hard_error_limit=20"

# Chay lai d01 SAU d03 thi phai chay lai d03: postconf -e o day ghi de toan bo smtpd_recipient_restrictions.
postfix check
systemctl reload postfix || systemctl restart postfix

echo
echo "=== XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - $HOST.$DOMAIN - sau D-01"
  echo "--- cac restrictions dang ap dung ---"
  postconf -n | grep -E '^(mynetworks|smtpd_relay_restrictions|smtpd_recipient_restrictions|smtpd_sender_restrictions|smtpd_helo_required|smtpd_helo_restrictions|disable_vrfy_command) *='
  echo "--- kiem tra cu phap ---"
  postfix check && echo "  postfix check: khong co loi"
  systemctl is-active postfix
} | tee "$EVID/d01-close-relay.txt"
