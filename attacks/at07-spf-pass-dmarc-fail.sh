#!/usr/bin/env bash
# AT-07  "SPF pass van bi tu choi" - chung minh DMARC alignment (kich ban nang cao)
#   Chay tren vm-atk (10.30.0.40), SAU khi da xong d03/d04/d05 (SPF+DKIM+DMARC).
#   sudo bash attacks/at07-spf-pass-dmarc-fail.sh
#
# Ke tan cong dung domain cua MINH (darkside.test) va cong bo SPF hop le cho no,
# nen loc SPF cho qua (spf=pass). Nhung dong Header From lai la
# giamdoc@congtyA.test -> domain cua phong thu khong 'lien ket' (align) voi
# domain duoc xac thuc -> DMARC = fail -> mail2 tu choi theo p=reject.
# Bai hoc: SPF/DKIM ty no chi tra loi "thu nay den tu dau", DMARC moi tra loi
# "thu nay co dung la cua cong ty A hay khong".
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

EVID=/root/evidence/atk; mkdir -p "$EVID"

echo "=== [0] Dieu kien: darkside.test phai co SPF hop le (10.30.0.40 duoc phep gui) ==="
SPF=$(dig @10.30.0.10 TXT darkside.test +short | grep -c 'v=spf1' || true)
if [ "$SPF" = "0" ]; then
  cat <<'HOI'
Thieu SPF cho darkside.test. Chay LENH NAY tren vm-dns (10.30.0.10) truoc:

#   sudo bash defense/dns-add-record.sh darkside.test '@' 'v=spf1 ip4:10.30.0.40 -all'

roi quay lai vm-atk chay lai script nay.
HOI
  exit 1
fi
echo "--- SPF hien tai: ---"
dig @10.30.0.10 TXT darkside.test +noall +answer | sed 's/^/  /'
echo "--- DMARC cua nan nhan (congtyA.test): ---"
dig @10.30.0.10 TXT _dmarc.congtyA.test +noall +answer | sed 's/^/  /'

echo
echo "=== [1] Gui thu: envelope = darkside.test (SPF pass), Header From = congtyA.test ==="
swaks --server mail2.congtyB.test --port 25 \
      --from 'thongbao@darkside.test' \
      --to   'ketoan@congtyB.test' \
      --helo 'mail.darkside.test' \
      --header 'From: Giam đoc Alpha <giamdoc@congtyA.test>' \
      --header 'Reply-To: attacker@darkside.test' \
      --header 'Subject: [AT-07] Xac nhan don chuyen khoan (SPF pass, DMARC fail)' \
      --header 'X-Lab-Mark: AT-07-MISALIGNED' \
      --body 'SPF pass cho darkside, khong align voi Header From cua congtyA.' 2>&1 | tee "$EVID/at07-misaligned.log"
RC=$?

echo
echo "=== [2] Ket luan ==="
echo "  swaks exit code = $RC"
grep -E '<<< [25]' "$EVID/at07-misaligned.log" | tail -6 | sed 's/^/  /'
echo
echo "=== [3] Doc log tren vm-mail2 (10.30.0.30) de tim dong ket luan cua he thong ==="
echo "    sudo grep -E 'dmARC|DMARC|policyd-spf|opendkim' /var/log/mail.log | tail -30"
echo "    sudo tail -n 60 /var/log/mail.log"
echo
