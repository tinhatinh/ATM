#!/usr/bin/env bash
# D-05b  Bat buoc kiem tra va THUC THI DMARC tren MTA nhan.
#   vm-mail1: sudo bash defense/d05b-dmarc-enforce.sh alpha
#   vm-mail2: sudo bash defense/d05b-dmarc-enforce.sh beta
# Thu tu milter RAT quan trong: OpenDMARC doc ket qua do OpenDKIM va policyd-spf
# ghi vao Authentication-Results, nen no PHAI dung SAU OpenDKIM trong smtpd_milters
# (README.opendmarc cua package ghi ro dieu nay).
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
case "$ROLE" in
  alpha) HOST=mail1; DOMAIN=congtyA.test ;;
  beta)  HOST=mail2; DOMAIN=congtyB.test ;;
  *) echo "alpha | beta"; exit 1 ;;
esac
EVID="/root/evidence/$HOST"; mkdir -p "$EVID"

echo "=== [1] Package OpenDMARC ==="
[ -x /usr/sbin/opendmarc ] || apt-get install -y opendmarc
/usr/sbin/opendmarc -V 2>&1 | head -2

echo
echo "=== [2] /etc/opendmarc.conf ==="
cp -a /etc/opendmarc.conf /etc/opendmarc.conf.pre-d05
# File mac dinh cua Ubuntu KHONG co dong 'Socket' khong comment -> sed khong thay
# duoc gi, opendmarc van nghe unix socket. Phai thay hoac THEM vao.
sed -i -E 's|^Socket[[:space:]]+.*|Socket                   inet:8893@localhost|' /etc/opendmarc.conf
grep -qE '^Socket[[:space:]]' /etc/opendmarc.conf \
  || printf '\nSocket                   inet:8893@localhost\n' >> /etc/opendmarc.conf
grep -nE '^Socket' /etc/opendmarc.conf
if ! grep -q 'ATM Topic03 D-05' /etc/opendmarc.conf; then
  cat >> /etc/opendmarc.conf <<EOF

# ==== ATM Topic03 D-05 ====
Syslog                    true
AuthservID                $HOST.$DOMAIN
TrustedAuthservIDs        $HOST.$DOMAIN
RejectFailures            true
FailureReports            false
EOF
fi
grep -vE '^\s*(#|$)' /etc/opendmarc.conf | sed 's/^/  /'

echo
echo "=== [3] Xich milter: OpenDKIM (8891) ROI MOI OpenDMARC (8893) ==="
postconf -c /etc/postfix -e \
  "smtpd_milters=inet:localhost:8891, inet:localhost:8893" \
  "non_smtpd_milters=inet:localhost:8891, inet:localhost:8893" \
  "milter_default_action=tempfail"

# DMARC la phep thu cua ben NHAN: no tra loi cau hoi "ke nay co duoc phep dung
# ten domain nay khong". Ap no len ca cong submission 587 se chan nguoi dung HOP
# LE cua minh (measured: T5 bi '550 5.7.1 rejected by DMARC policy' tu chinh
# mail1), vi tai 587 client la vm-client 10.30.0.50 - khong nam trong
# "v=spf1 ip4:10.30.0.20 mx -all" - nen spf=fail, cong voi dkim chua verify
# duoc => dmarc=fail. Chuan thuc nghiep: o submission chi ky DKIM, danh gia
# DMARC o cong 25 (thu DEN). Postfix cho phep de override milter theo tung
# service trong master.cf.
if ! grep -A3 '^submission[[:space:]]' /etc/postfix/master.cf | grep -q 'smtpd_milters'; then
  sed -i '/^submission[[:space:]]/a\  -o smtpd_milters=inet:localhost:8891' /etc/postfix/master.cf
  echo "  da them override smtpd_milters cho service submission"
else
  echo "  submission da co override smtpd_milters - khong them nua"
fi
postconf -M submission
postfix check

systemctl enable opendmarc >/dev/null 2>&1 || true
systemctl restart opendmarc
sleep 1
systemctl restart postfix

echo
echo "=== [4] XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - $HOST.$DOMAIN - sau D-05 (he thong phong thu day du)"
  echo "--- dich vu ---"
  for s in postfix dovecot opendkim opendmarc; do printf '%-12s %s\n' "$s" "$(systemctl is-active $s)"; done
  echo "--- milter lang nghe ---"
  ss -ltn | grep -E ':(8891|8893)' || echo "LOI: khong thay milter 8891/8893"
  echo "--- postconf ---"
  postconf -n | grep -E '^(smtpd_milters|non_smtpd_milters|milter_default_action|smtpd_recipient_restrictions|smtpd_relay_restrictions|mynetworks|smtpd_tls_security_level|smtp_tls_security_level) *='
  echo "--- master.cf policyd-spf ---"
  postconf -M 'policyd-spf/unix' 2>&1
  echo "--- ban ghi DNS ben nhan thay duoc ---"
  dig @10.30.0.10 TXT congtyA.test +short
  dig @10.30.0.10 _dmarc.congtyA.test TXT +short
  dig @10.30.0.10 mail._domainkey.congtyA.test TXT +short | cut -c1-60
} | tee "$EVID/d05b-dmarc-enforce-$ROLE.txt"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# HE THONG PHONG THU DA HOAN CHINH. Chay bo KIEM CHUNG:
#   sudo bash verify/v01-dns-records.sh        (tren vm-dns)
#   sudo bash verify/v02-happy-path.sh         (tren vm-client)
#   sudo bash verify/v03-replay-attacks.sh     (tren vm-atk)
#   sudo bash verify/v04-tls-and-downgrade.sh  (tren vm-client)
# TIET
