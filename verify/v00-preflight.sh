#!/usr/bin/env bash
# V-00  Kiem tra TRUOC KHI chay bat ky kich ban nao (chay tren vm-dns hoac vm-client).
#   sudo bash verify/v00-preflight.sh
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

EVID=/root/evidence/$(hostname -s); mkdir -p "$EVID"
{
echo "################ V-00 preflight $(date -u '+%F %T') UTC ################"
echo "--- 1. Ket noi IP (host-only 10.30.0.0/24) ---"
for IP in 10.30.0.10 10.30.0.20 10.30.0.30 10.30.0.40 10.30.0.50; do
  if ping -c1 -W1 "$IP" >/dev/null 2>&1; then printf '  %-14s OK\n' "$IP"; else printf '  %-14s MAT\n' "$IP"; fi
done
echo "--- 2. Phong van cua dich vu (ket noi TCP that, dung /dev/tcp) ---"
for SPEC in "10.30.0.10 53" "10.30.0.20 25" "10.30.0.20 587" "10.30.0.20 143" "10.30.0.20 993" \
            "10.30.0.30 25" "10.30.0.30 587" "10.30.0.30 143" "10.30.0.30 993" "10.30.0.40 2525"; do
  set -- $SPEC
  if timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; then
    printf '  %-10s port %-5s MO\n' "$1" "$2"
  else
    printf '  %-10s port %-5s dong\n' "$1" "$2"
  fi
done
echo "--- 3. Phan giai ten mien (can DNS dang live) ---"
printf '  MX A   : %s\n' "$(dig @10.30.0.10 congtyA.test MX +short | tr '\n' ' ')"
printf '  MX B   : %s\n' "$(dig @10.30.0.10 congtyB.test MX +short | tr '\n' ' ')"
printf '  mail1 A: %s\n' "$(dig @10.30.0.10 mail1.congtyA.test A +short)"
printf '  mail2 A: %s\n' "$(dig @10.30.0.10 mail2.congtyB.test A +short)"
echo "--- 4. Dong ho (anh huong toi cert va DKIM t=) ---"
printf '  UTC local: %s\n' "$(date -u '+%F %T')"
echo "--- 5. Trang thai dinh danh DNS ---"
for D in congtyA.test congtyB.test; do
  printf '  SPF %-14s : %s\n' "$D" "$(dig @10.30.0.10 TXT $D +short | grep -o 'v=spf1.*' | cut -c1-40 || echo '(khong co)')"
  printf '  DMARC %-14s : %s\n' "$D" "$(dig @10.30.0.10 _dmarc.$D TXT +short | cut -c1-40 || echo '(khong co)')"
  printf '  DKIM %-13s : %s\n' "$D" "$(dig @10.30.0.10 mail._domainkey.$D TXT +short | grep -o 'v=DKIM1' || echo '(khong co)')"
done
} 2>&1 | tee "$EVID/v00-preflight.txt"

