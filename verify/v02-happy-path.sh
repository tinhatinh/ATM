#!/usr/bin/env bash
# V-02  Duong bien (happy path): thu hop le phai DI QUA duoc ca 3 loc.
#   Chay tren vm-client:  sudo bash verify/v02-happy-path.sh
#Nguoi dung that (giamdoc@congtyA.test) dang nhap qua 587 + TLS, gui cho
# ketoan@congtyB.test. Ky vong: mail1 ky DKIM, mail2 thay spf=pass dkim=pass
# dmarc=pass va PHAT thu (250 queued), khong phai 5xx.
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
EVID=/root/evidence/client; mkdir -p "$EVID"
LOG="$EVID/v02-happy-path.log"

echo "=== [0] Thong tin nen (ghi vao bao cao muc 3.6.2) ==="
echo "  May phat : $(hostname -f)  $(ip -4 -br addr | awk 'NR==1{print $3}')"
echo "  MX A     : $(dig @10.30.0.10 congtyA.test MX +short)"
echo "  SPF A    : $(dig @10.30.0.10 TXT congtyA.test +short | grep v=spf1 || echo '(chua co)')"
echo "  DMARC A  : $(dig @10.30.0.10 _dmarc.congtyA.test TXT +short | cut -c1-60 || echo '(chua co)')"

echo
echo "=== [1] Gui thu hop le (AUTH LOGIN + STARTTLS bat buoc) ==="
swaks --server mail1.congtyA.test --port 587 --tls \
      --from 'giamdoc@congtyA.test' \
      --to   'ketoan@congtyB.test' \
      --helo 'client.congtyA.test' \
      --auth LOGIN --auth-user giamdoc --auth-password 'Lab@2026' \
      --header 'From: Giam đoc Alpha <giamdoc@congtyA.test>' \
      --header 'Subject: [V-02] Xac nhan hop so hop dong HD-2026-0713-STB-123' \
      --header 'X-Lab-Mark: V02-HAPPY' \
      --body "@$PROJECT/attacks/payloads/invoice-legit.txt" 2>&1 | tee "$LOG"
RC=$?
echo "  swaks exit code = $RC"

echo
echo "=== [2] Tim dong tra loi quyet dinh ==="
grep -E '<[-~*]+[[:space:]]+[245][0-9]{2}' "$LOG" | tail -6 | sed 's/^/  /' || true

echo
echo "=== [3] CHIEU NGUOC LAI (Beta ky va gui cho Alpha) ==="
LOG2="$EVID/v02b-happy-path-beta.log"
swaks --server mail2.congtyB.test --port 587 --tls \
      --from 'ketoan@congtyB.test' \
      --to   'giamdoc@congtyA.test' \
      --helo 'client.congtyA.test' \
      --auth LOGIN --auth-user ketoan --auth-password 'Lab@2026' \
      --header 'Subject: [V-02b] Chieu nguoc lai Beta -> Alpha' \
      --header 'X-Lab-Mark: V02B-HAPPY' \
      --body 'Xac nhan thanh toan tu Cong ty Beta.' 2>&1 | tee "$LOG2"
RC2=$?
echo "  swaks exit code = $RC2"
echo
echo "  Bang chung: $LOG, $LOG2"
