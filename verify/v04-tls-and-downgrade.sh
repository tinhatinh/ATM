#!/usr/bin/env bash
# V-04  Kiem chung ma hoa + kiem chung chong ha cap STARTTLS.
#   Chay tren vm-client:  sudo bash verify/v04-tls-and-downgrade.sh
#   (muon kiem phan downgrade: chay tren vm-atk truoc
#      sudo bash attacks/atk-run-strip-proxy.sh start )
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
PROBE="python3 $PROJECT/verify/smtp-probe.py"
EVID=/root/evidence/client; mkdir -p "$EVID"
CA=/tmp/lab-ca.crt

{
echo "################ V-04 TLS & downgrade $(date -u '+%F %T') UTC ################"

echo "--- [1] Lay CA cua lab tu vm-dns ---"
if curl -fsS -o "$CA" http://10.30.0.10:8080/lab-ca.crt 2>/dev/null; then
  echo "  da tai $CA (dich vu phat file cua d02a van dang mo)"
else
  echo "  khong lay duoc CA tu 10.30.0.10:8080, dung $CA luu tu lan truoc"
fi

echo
echo "--- [2] STARTTLS va chu chung tren mail1:25 ---"
if [ -f "$CA" ]; then
  openssl s_client -starttls smtp -connect 10.30.0.20:25 -CAfile "$CA" </dev/null 2>/dev/null \
    | grep -E '^New, |Protocol\s*:|Cipher\s*:|Verify return code:|subject=|issuer=' | sed 's/^/  /'
  echo "  --- mail2:25 ---"
  openssl s_client -starttls smtp -connect 10.30.0.30:25 -CAfile "$CA" </dev/null 2>/dev/null \
    | grep -E '^New, |Protocol\s*:|Verify return code:|subject=' | sed 's/^/  /'
  echo "  --- IMAPS mail2:993 ---"
  openssl s_client -connect 10.30.0.30:993 -CAfile "$CA" </dev/null 2>/dev/null \
    | grep -E '^New, |Protocol\s*:|Verify return code:' | sed 's/^/  /'
fi

echo
echo "--- [3] EHLO co quan bo STARTTLS / AUTH khong ---"
for SPEC in "10.30.0.20 25" "10.30.0.20 587" "10.30.0.30 25"; do
  set -- $SPEC
  printf '  %s:%s\n' "$1" "$2"
  printf 'EHLO preflight.%s\nQUIT\n' 'congtyA.test' | $PROBE "$1" "$2" \
     | grep -E '^(220|250)' | sed 's/^/     /' || true
done

echo
echo "--- [4] THU CAM: AUTH qua kenh KHONG TLS (phai bi tu choi sau d02b encrypt) ---"
printf 'EHLO client.congtyA.test\nAUTH LOGIN\nZm9v\nYmFy\nQUIT\n' \
  | $PROBE 10.30.0.20 25 | sed -n '1,14p' | sed 's/^/  /' || true

echo
echo "--- [5] THU HA CAP: gui qua proxy 10.30.0.40:2525 (neu dang chay) ---"
if timeout 3 bash -c 'exec 3<>/dev/tcp/10.30.0.40/2525' 2>/dev/null; then
  swaks --server 10.30.0.40 --port 2525 --tls-optional \
        --from 'giamdoc@congtyA.test' --to 'ketoan@congtyB.test' \
        --auth LOGIN --auth-user giamdoc --auth-password 'Lab@2026' \
        --header 'Subject: [V04] thu downgrade sau phong thu' \
        --body 'Thu nay khong bao gio den duoc tay ketoan.' 2>&1 | tail -24
  echo "  swaks exit code = ${PIPESTATUS[0]}"
else
  echo "  Khong ket noi duoc 10.30.0.40:2525 - proxy MitM dang tat nen buoc nay bo qua."
fi

echo
echo "--- [6] Log cua mail1 chung minh phien bi tu choi (xem tren vm-mail1) ---"
echo "  sudo tail -n 40 /var/log/mail.log | grep -E 'TLS|STARTTLS|reject'"
} 2>&1 | tee "$EVID/v04-tls-and-downgrade.txt"

echo
