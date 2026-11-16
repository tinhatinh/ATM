#!/usr/bin/env bash
# D-03b  Xuat ban ban ghi SPF cua ca hai domain.  Chay tren vm-dns.
#   sudo bash defense/d03b-spf-publish.sh
# Cac dong duoc cong bo:
#   congtyA.test.  TXT "v=spf1 ip4:10.30.0.20 mx -all"
#   congtyB.test.  TXT "v=spf1 ip4:10.30.0.30 mx -all"
# -all = hard fail: moi nguon khong liet ke deu bi tinh la SPF Fail.
# mx la co che tham chieu toi MX cua chinh domain (RFC 7208 5.4), ip4 la goi y
# truc tiep; trong lab hai cach trung nhau, nhung viec co ca hai giup doc log de hon.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root TREN vm-dns"; exit 1; }
SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"

for SPEC in "congtyA.test:10.30.0.20" "congtyB.test:10.30.0.30"; do
  D="${SPEC%%:*}"; IP="${SPEC##*:}"
  echo "################## SPF cho $D ##################"
  bash "$PROJECT/defense/dns-add-record.sh" "$D" '@' "v=spf1 ip4:$IP mx -all"
  echo
done

echo "=== TONG HOP ban ghi dinh danh hien co ==="
for D in congtyA.test congtyB.test; do
  echo "--- $D (SPF) ---";   dig @10.30.0.10 TXT "$D" +noall +answer
  echo "--- $D (MX)  ---";   dig @10.30.0.10 MX  "$D" +noall +answer
done

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# KIEM CHUNG SPF TU PHIA NHAN (vm-mail2):
#   dig @10.30.0.10 TXT congtyA.test +short        -> "v=spf1 ip4:10.30.0.20 mx -all"
#   sudo tail -f /var/log/mail.log                 -> dong 'policyd-spf[...]:' khi co thu đen
# CHAY TIEP:
#   vm-mail1: sudo bash defense/d04a-dkim.sh alpha
#   vm-mail2: sudo bash defense/d04a-dkim.sh beta
# KET
