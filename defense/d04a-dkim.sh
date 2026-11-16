#!/usr/bin/env bash
# D-04a  Sinh cap khoa DKIM RSA 2048 + cau hinh OpenDKIM (ky va kiem tra).
#   vm-mail1: sudo bash defense/d04a-dkim.sh alpha
#   vm-mail2: sudo bash defense/d04a-dkim.sh beta
# Sau buoc nay MTA san sang ky thu, Nhung thu se bi ben ngoai bo qua cho den khi
# ban ghi cong khai duoc xuat ban (d04b) - day dung la trinh tu cua DKIM that.
set -euo pipefail

ROLE="${1:?alpha hoac beta}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root"; exit 1; }
case "$ROLE" in
  alpha) HOST=mail1; DOMAIN=congtyA.test; ORG="Cong ty Alpha" ;;
  beta)  HOST=mail2; DOMAIN=congtyB.test; ORG="Cong ty Beta"  ;;
  *) echo "alpha | beta"; exit 1 ;;
esac
EVID="/root/evidence/$HOST"; mkdir -p "$EVID"
SEL="mail"

echo "=== [1] Sinh cap khoa (opendkim-genkey thuoc /usr/sbin) ==="
mkdir -p /etc/dkimkeys
if [ -f "/etc/dkimkeys/$SEL.private" ]; then
  echo "Da ton tai /etc/dkimkeys/$SEL.private - giu nguyen (khong sinh lai, keo lot khoa cu)."
else
  /usr/sbin/opendkim-genkey -b 2048 -d "$DOMAIN" -s "$SEL" -D /etc/dkimkeys -r -a
fi
chown opendkim:opendkim "/etc/dkimkeys/$SEL.private" "/etc/dkimkeys/$SEL.txt"
chmod 600 "/etc/dkimkeys/$SEL.private"
chmod 644 "/etc/dkimkeys/$SEL.txt"
ls -l /etc/dkimkeys/
openssl rsa -in "/etc/dkimkeys/$SEL.private" -noout -text 2>/dev/null | head -4

echo
echo "=== [2] Danh sach may duoc phep ky (InternalHosts - khong phai TrustedHosts) ==="
mkdir -p /etc/opendkim
cat > /etc/opendkim/InternalHosts <<EOF
# ATM Topic03 - nhung nguoi gui duoc phep nhan chu ky DKIM cua $DOMAIN
127.0.0.1
$HOST.$DOMAIN
10.30.0.50/32
10.30.0.20/32
10.30.0.30/32
EOF
chown opendkim:opendkim /etc/opendkim/InternalHosts
chmod 640 /etc/opendkim/InternalHosts
cat /etc/opendkim/InternalHosts

echo
echo "=== [3] Bo sung /etc/opendkim.conf (giu cac dong mac dinh cua Ubuntu) ==="
cp -a /etc/opendkim.conf /etc/opendkim.conf.pre-d04
# Socket: doi local:/run/... thanh inet:8891@localhost de Postfix ket noi de dang.
# LUU Y: file mac dinh dung TAB sau tu khoa 'Socket', nen pattern phai la
# [[:space:]]+ - dung 'Socket ' (dau cach) se khong khop va opendkim van nghe
# unix socket (loi nay tung lam 'smtpd_milters=inet:localhost:8891' khong chay).
sed -i -E 's|^Socket[[:space:]]+.*|Socket                   inet:8891@localhost|' /etc/opendkim.conf
grep -qE '^Socket[[:space:]]' /etc/opendkim.conf \
  || printf '\nSocket                   inet:8891@localhost\n' >> /etc/opendkim.conf
grep -nE '^Socket' /etc/opendkim.conf
if ! grep -q 'ATM Topic03 D-04' /etc/opendkim.conf; then
  cat >> /etc/opendkim.conf <<EOF

# ==== ATM Topic03 D-04 ($ORG) ====
Mode                    sv
Domain                  $DOMAIN
Selector                $SEL
KeyFile                 /etc/dkimkeys/$SEL.private
InternalHosts           /etc/opendkim/InternalHosts
AutoRestart             Yes
AutoRestartRate         10/1h
SyslogSuccess           Yes
LogWhy                  Yes
EOF
fi
grep -vE '^\s*(#|$)' /etc/opendkim.conf | sed 's/^/  /'

echo
echo "=== [4] Khoi dong OpenDKIM + gan milter cho Postfix ==="
systemctl enable opendkim >/dev/null 2>&1 || true
systemctl restart opendkim
sleep 1
postconf -c /etc/postfix -e \
  "milter_protocol=6" \
  "smtpd_milters=inet:localhost:8891" \
  "non_smtpd_milters=inet:localhost:8891"
postfix check
systemctl restart postfix

echo
echo "=== [5] XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - $HOST.$DOMAIN - sau D-04a (selector: $SEL)"
  echo "--- dich vu ---"
  systemctl is-active opendkim; systemctl is-active postfix
  echo "--- milter socket 8891 ---"
  ss -ltn | grep ':8891' || echo "LOI: opendkim khong nghe 127.0.0.1:8891"
  echo "--- phien ban ---"
  opendkim -V 2>&1 | head -3
  echo "--- postconf milter ---"
  postconf -n | grep -E '^(milter_protocol|smtpd_milters|non_smtpd_milters) *='
  echo "--- Ban ghi DKIM can cong bo (luu cau nay lai de d04b) ---"
  cat "/etc/dkimkeys/$SEL.txt"
} | tee "$EVID/d04a-dkim-$ROLE.txt"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# BUOC TIEP THEO - xuat ban ban ghi DKIM tren vm-dns (10.30.0.10):
#   sudo bash defense/d04b-dkim-publish.sh $ROLE
# Script do se yeu cau DAN noi dung file /etc/dkimkeys/$SEL.txt o may $HOST:
#   sudo cat /etc/dkimkeys/$SEL.txt
# Sau khi xuat ban, kiem tra mat $HOST bang (khong in ra 'key not found', exit 0 la DKIM OK):
#   opendkim-testkey -d $DOMAIN -s $SEL -vvv 2>&1 | tail -6
# TIEP
