#!/usr/bin/env bash
# D-03  Bat bo loc SPF (policyd-spf) tren MTA. Chay tren CA HAI mail server.
#   vm-mail1: sudo bash defense/d03-spf-enforce.sh alpha
#   vm-mail2: sudo bash defense/d03-spf-enforce.sh beta
# Thu tu QUYET DINH: check_policy_service dat SAU reject_unauth_destination
# (README.Debian canh bao: dat truoc se bien may thanh open relay), va
# mynetworks chi con loopback (D-01) de permit_mynetworks khong cat ngan SPF.
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
case "$ROLE" in
  alpha) HOST=mail1; DOMAIN=congtyA.test ;;
  beta)  HOST=mail2; DOMAIN=congtyB.test ;;
  *) echo "alpha | beta"; exit 1 ;;
esac
EVID="/root/evidence/$HOST"; mkdir -p "$EVID"

echo "=== [1] Package policyd-spf ==="
if [ ! -x /usr/bin/policyd-spf ]; then
  apt-get install -y postfix-policyd-spf-python
fi
# KHONG chay 'policyd-spf --version': daemon khong co co nay, no se mo stdin va
# treo vo han. Lay phien ban tu dpkg.
dpkg-query -W -f='postfix-policyd-spf-python ${Version}\n' postfix-policyd-spf-python
id policyd-spf

echo
echo "=== [2] master.cf: dich vu policyd-spf (spawn qua unix socket) ==="
if ! grep -qE '^policyd-spf[[:space:]]+unix' /etc/postfix/master.cf; then
  cat >> /etc/postfix/master.cf <<'EOF'

# ==== ATM Topic03 D-03: SPF policy daemon (README.Debian cua postfix-policyd-spf-python)
policyd-spf  unix  -       n       n       -       0       spawn
    user=policyd-spf argv=/usr/bin/policyd-spf
EOF
fi
grep -n -A1 '^policyd-spf' /etc/postfix/master.cf

echo
echo "=== [3] TestOnly phai = 1 (CHE DO THUC THI) - bay kinh đien ==="
CONF=/etc/postfix-policyd-spf-python/policyd-spf.conf
grep -vE '^\s*(#|$)' "$CONF" | sed 's/^/  /'
echo "--- Trich dan man 5 policyd-spf.conf ---"
timeout 25 man 5 policyd-spf.conf 2>/dev/null | col -bx | grep -A3 -B3 'TestOnly' | sed 's/^/  /' || true
# TestOnly = 1 la CHE DO THUC THI (chan thu). TestOnly = 0 moi la "chi ghi header".
sed -i -E 's/^TestOnly *=.*/TestOnly = 1/' "$CONF"
grep -E '^TestOnly' "$CONF" | sed 's/^/  hien tai: /'

echo
echo "=== [4] main.cf: ghep check_policy_service vao sau reject_unauth_destination ==="
postconf -c /etc/postfix -e \
  "policyd-spf_time_limit=3600" \
  "smtpd_recipient_restrictions=reject_non_fqdn_recipient, permit_sasl_authenticated, reject_unauth_destination, check_policy_service unix:private/policyd-spf"
postconf -n | grep -E '^(smtpd_recipient_restrictions|policyd-spf_time_limit|mynetworks) *=' | sed 's/^/  /'

postfix check
systemctl restart postfix

echo
echo "=== [5] XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - $HOST.$DOMAIN - sau D-03"
  echo "--- postconf ---"
  postconf -n | grep -E '^(smtpd_recipient_restrictions|smtpd_relay_restrictions|policyd-spf_time_limit|mynetworks) *='
  echo "--- master.cf service ---"
  postconf -M 'policyd-spf/unix' 2>&1
  echo "--- dich vu ---"
  systemctl is-active postfix
  echo "--- SPF record cua $DOMAIN da ton tai chua (tren vm-dns) ---"
  dig @10.30.0.10 TXT "$DOMAIN" +noall +answer
} | tee "$EVID/d03-spf.txt"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# BUOC TIEP THEO (tren vm-dns 10.30.0.10) - xuat ban ban ghi SPF:
#   sudo bash defense/d03b-spf-publish.sh
# 
# ROI KIEM CHUNG NGAY (tren vm-atk):
#   sudo bash attacks/at04-spoof-header.sh        -> bi tu choi tai RCPT, ma 550 5.7.23
#   sudo bash attacks/at01-open-relay.sh          -> van khong phai open relay
# Ghi NGUYEN VAN hoi dap SMTP va 3-5 dong cuoi /var/log/mail.log cua vm-mail2.
# KHUYEN: neu muon "chi ghi log khong chan" thi dat TestOnly = 0, tuc che do
# guan sat; o day ta muon CHAN nen gi TestOnly = 1.
# KHUYEN
