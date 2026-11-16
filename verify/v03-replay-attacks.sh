#!/usr/bin/env bash
# V-03  Chay LAI cac tan cong sau khi da phong thu (bang "truoc / sau").
#   Chay tren vm-atk:  sudo bash verify/v03-replay-attacks.sh
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

EVID=/root/evidence/atk; mkdir -p "$EVID"
OUT="$EVID/v03-replay.txt"
ROWS=()

case_run () {   # $1 ten  $2 ma ky vong (5=bi chan, 2=duoc phep)  ${@:3} tham so swaks
  local NAME="$1" EXPECT="$2"; shift 2
  local LOG="$EVID/v03-$(echo "$NAME" | tr ' /' '__').log"
  local OUTP REJ OKQ RC NOTE
  OUTP="$(swaks "$@" 2>&1 || true)"
  printf '%s\n' "$OUTP" > "$LOG"
  # Ma TU CHOI dau tien (4xx/5xx). LUU Y: swaks doi tien to theo giai doan —
  # '<-' truoc TLS, '<~' SAU TLS. Bo qua '<~' la toan bo ma 5xx bi nut (da xay ra).
  REJ=$(printf '%s\n' "$OUTP" | grep -oE '<[-~*]+[[:space:]]+[45][0-9]{2}' | head -1 | grep -oE '[45][0-9]{2}' || true)
  OKQ=$(printf '%s\n' "$OUTP" | grep -cE '<[-~*]+[[:space:]]+250 2\.0\.0 Ok: queued' || true)
  if [ "$EXPECT" = "5" ]; then
    RC="${REJ:-000}"
    if [ -n "$REJ" ]; then NOTE="KHOP - da chan bang $REJ"; else NOTE="KHONG KHOP - thu VAN duoc chap nhan"; fi
  else
    if [ "$OKQ" -gt 0 ]; then RC="250"; NOTE="KHOP - thu hop le duoc phat"; else RC="${REJ:-000}"; NOTE="KHONG KHOP - bi chan nham thu hop le"; fi
  fi
  ROWS+=("$(printf '%-34s ky_vong=%s*  thuc_te=%s  %s' "$NAME" "$EXPECT" "$RC" "$NOTE")")
  printf '%-34s -> %s  (%s)\n' "$NAME" "$RC" "$NOTE"
  echo "   chi tiet: $LOG"
}

{
echo "################ V-03 replay attacks $(date -u '+%F %T') UTC ################"

echo "--- [T1] Open relay: muon gui ho sang domain la (qua mail1:25) ---"
# LUU Y: sau d02b encrypt, may thu TU CHOI lenh MAIL FROM/RCPT tren kenh khong
# TLS (ma 530 "Must issue a STARTTLS command first"). Neu gui ban ro thi test
# chi chung minh duoc TLS bat buoc, KHONG kiem chung duoc SPF/DMARC. Vi vay
# T1-T4 deu bat tay bat chu TLS (--tls-optional) de phien den duoc RCPT va
# policy/DMARC moi duoc danh gia.
case_run "T1 relay-domain-la" 5 \
  --server 10.30.0.20 --port 25 --tls-optional --from 'attacker@darkside.test' \
  --to 'nguoidung@domain-khong-lab.test' --quit-after RCPT

echo "--- [T2] Gia mao admin@congtyA.test gui cho Beta (AT-04) ---"
case_run "T2 spoof-alpha-to-beta" 5 \
  --server 10.30.0.30 --port 25 --tls-optional --from 'admin@congtyA.test' --to 'ketoan@congtyB.test' \
  --header 'From: Admin <admin@congtyA.test>' --header 'Subject: [V03] spoof replay' \
  --body 'Noi dung thu gia mao'

echo "--- [T3] Gia mao chinh domain ben nhan gui cho Alpha (AT-05) ---"
case_run "T3 spoof-own-domain" 5 \
  --server 10.30.0.20 --port 25 --tls-optional --from 'postmaster@congtyA.test' --to 'admin@congtyA.test' \
  --header 'From: IT Support <postmaster@congtyA.test>' --header 'Subject: [V03] own domain' \
  --body 'Noi dung thu gia mao'

echo "--- [T4] SPF pass cho darkside.test nhung Header From cua Alpha (AT-07) ---"
case_run "T4 spf-pass-dmarc-fail" 5 \
  --server 10.30.0.30 --port 25 --tls-optional --from 'thongbao@darkside.test' --to 'ketoan@congtyB.test' \
  --header 'From: Giam đoc <giamdoc@congtyA.test>' --header 'Subject: [V03] misaligned' \
  --body 'SPF pass cho darkside, khong align voi congtyA'

echo "--- [T5] DIEU CHIEM DUONG: thu HOP LE (co AUTH + TLS) van phai di qua ---"
case_run "T5 hop le (auth+tls)" 2 \
  --server 10.30.0.20 --port 587 --tls --auth LOGIN --auth-user giamdoc --auth-password 'Lab@2026' \
  --from 'giamdoc@congtyA.test' --to 'ketoan@congtyB.test' \
  --header 'Subject: [V03] hop le van duoc phat' --body 'Thu that cua nguoi dung that'

echo
echo "################ BANG TOM TAT ################"
for r in "${ROWS[@]}"; do echo "$r"; done
} 2>&1 | tee "$OUT"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# DOC KET QUA (so sinh voi Giai doan 2 - muc 3.6.1 bao cao):
#   T1  : 554 5.7.1 Relay access denied           (mo relay da dong)
#   T2  : 550 5.7.23 ...                          (policyd-spf: SPF Fail cua congtyA.test)
#   T3  : 5xx  (SPF Fail, vi 10.30.0.40 khong nam trong "ip4:10.30.0.20 mx -all")
#   T4  : 550 5.7.1 ... DMARC policy ...          (alignment fail, p=reject)
#   T5  : 250 2.0.0 Ok: queued                   (khong chan nham thu hop le)
# MAU CAC DONG '5xx' PHAI LAY NGUYEN VAN TU $OUT, khong duoc viet tay.
# KET
