#!/usr/bin/env bash
# V-01  Kiem tra bo ba ban ghi dinh danh da duoc xuat ban dung cho chua.
#   Chay tren vm-dns:  sudo bash verify/v01-dns-records.sh
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

EVID=/root/evidence/dns; mkdir -p "$EVID"
OUT="$EVID/v01-dns-records.txt"
NS=10.30.0.10

# Tham so: ten (khong dau) va loai ban ghi tach rieng - neu ghep "ten TXT" vao
# mot bien thi dig nhan ca chu TXT nhu mot phan cua ten mien va khong tra loi.
q () { printf '%-46s %s\n' "$1 $2" "$(dig @$NS "$1" "$2" +short | tr '\n' '|')"; }

{
  echo "# time $(date -u '+%F %T') UTC - DNS kiem dinh danh (ns1.congtyA.test)"
  echo
  echo "===== 1. DINH TUYEN (A / MX / PTR) ====="
  q "congtyA.test"                A
  q "mail1.congtyA.test"          A
  q "congtyA.test"                MX
  q "congtyB.test"                MX
  printf '%-46s %s\n' "PTR 10.30.0.20"                 "$(dig @$NS -x 10.30.0.20 +short | tr '\n' '|')"
  printf '%-46s %s\n' "PTR 10.30.0.30"                 "$(dig @$NS -x 10.30.0.30 +short | tr '\n' '|')"
  echo
  echo "===== 2. SPF (RFC 7208) ====="
  q "congtyA.test"                TXT
  q "congtyB.test"                TXT
  echo
  echo "===== 3. DKIM (RFC 6376) - selector 'mail' ====="
  q "mail._domainkey.congtyA.test" TXT
  q "mail._domainkey.congtyB.test" TXT
  echo
  echo "===== 4. DMARC (RFC 7489) ====="
  q "_dmarc.congtyA.test"         TXT
  q "_dmarc.congtyB.test"         TXT
  echo
  echo "===== 5. Serial cua zone (moi lan sua phai tang) ====="
  for D in congtyA.test congtyB.test darkside.test; do
    printf '%-46s %s\n' "$D SOA-serial" "$(dig @$NS $D SOA +short | awk '{print $7}')"
  done
  echo
  echo "===== 6. Kiem tra AM (negative test) ====="
  echo "  _dmarc.khong-ton-tai.test  -> $(dig @$NS _dmarc.khong-ton-tai.test TXT +noall +comments | grep -oE 'status: [A-Z]+' )"
  echo "  recursion (google.com)     -> $(dig @$NS www.google.com +noall +comments | grep -oE 'status: [A-Z]+|flags: [^;]*')"
} | tee "$OUT"

echo
echo "===== DANH GIA ====="
FAIL=0
for SPEC in "congtyA.test:v=spf1" "congtyB.test:v=spf1" \
            "mail._domainkey.congtyA.test:v=DKIM1" "mail._domainkey.congtyB.test:v=DKIM1" \
            "_dmarc.congtyA.test:v=DMARC1" "_dmarc.congtyB.test:v=DMARC1"; do
  NAME="${SPEC%%:*}"; WANT="${SPEC##*:}"
  if dig @10.30.0.10 "$NAME" TXT +short | grep -q "$WANT"; then
    printf '  PASS  %-42s chua "%s"\n' "$NAME" "$WANT"
  else
    printf '  FAIL  %-42s KHONG thay "%s"\n' "$NAME" "$WANT"; FAIL=1
  fi
done
[ "$FAIL" = 0 ] && echo "  => Bo ba ban ghi SPF/DKIM/DMARC da san su dung cho phong thu." \
                 || echo "  => CON thieu ban ghi - chay lai defense/d03b, d04b, d05a tren vm-dns."
echo "  Ket qua luu: $OUT"
