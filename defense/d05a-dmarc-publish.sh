#!/usr/bin/env bash
# D-05a  Xuat ban ban ghi DMARC (_dmarc) cho ca hai domain. Chay tren vm-dns.
#   sudo bash defense/d05a-dmarc-publish.sh
# p=reject la muc ap dung cao nhat: khi DMARC fail, ben nhan tu choi thu o buoi
# cuoi cung cua phien SMTP (ma 5xx). Thuc te doanh nghiep bat dau bang p=none
# vai tuan de thu thap bao cao, roi moi nang len quarantine/reject.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root TREN vm-dns"; exit 1; }
SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"

for D in congtyA.test congtyB.test; do
  echo "################## DMARC cho $D ##################"
  bash "$PROJECT/defense/dns-add-record.sh" "$D" '_dmarc' \
    "v=DMARC1; p=reject; sp=none; adkim=r; aspf=r; pct=100; fo=1; rua=mailto:dmarc-reports@$D"
  echo
done

echo "=== Tong hop ba ban ghi dinh danh (SPF + DKIM + DMARC) ==="
for D in congtyA.test congtyB.test; do
  echo "----- $D -----"
  printf '  SPF   : '; dig @10.30.0.10 TXT "$D" +short
  printf '  DKIM  : '; dig @10.30.0.10 "mail._domainkey.$D" TXT +short | cut -c1-70
  printf '  DMARC : '; dig @10.30.0.10 "_dmarc.$D" TXT +short
done | tee "/root/evidence/dns/dig-identity-summary.txt"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# BA DONG CAN NHIN THAY (ghi nguyen van vao bao cao muc 3.5.2 - 3.5.4):
#   SPF   : "v=spf1 ip4:10.30.0.20 mx -all"
#   DKIM  : "v=DKIM1; h=sha256; k=rsa; " "p=MIIBIjAN..."
#   DMARC : "v=DMARC1; p=reject; sp=none; adkim=r; aspf=r; pct=100; fo=1;
#            rua=mailto:dmarc-reports@congtyA.test"
# 
# TIEP THEO - tren vm-mail1 va vm-mail2:
#   sudo bash defense/d05b-dmarc-enforce.sh alpha
#   sudo bash defense/d05b-dmarc-enforce.sh beta
# NHANXET
