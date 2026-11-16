#!/usr/bin/env bash
# AT-02  Nghe len noi dung thu ban ro (cleartext sniffing) - BUNG CHAY TREN vm-mail1
#   sudo bash attacks/at02-cleartext-sniff.sh
# Hai duong gui cung di cong 25, de so sanh chinh sach TLS phia CLIENT:
#   [2] swaks truc tiep toi mail2   -> swaks khong phat STARTTLS
#   [3] sendmail qua Postfix        -> Postfix tu STARTTLS neu smtp_tls_security_level=may/verify
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

if ! hostname -I | tr ' ' '\n' | grep -qx '^10.30.0.20$'; then
  echo "DUNG LAI: at02 phai chay tren vm-mail1 (10.30.0.20) - vi tri goi tui la MTA gui."
  echo "         May nay: $(hostname) / $(hostname -I | awk '{print $1}')"
  exit 1
fi

EVID=/root/evidence/mail1; mkdir -p "$EVID"
PCAP="$EVID/at02-smtp25.pcap"
TXT="$EVID/at02-cleartext.txt"
LOGMARK="$EVID/at02-postfix-hop.log"
rm -f "$PCAP" "$LOGMARK"
TOK_SWAKS='1029384756'
TOK_PF='5566778899'

echo "[1] Bat dau goi tui: tcpdump -i any 'tcp port 25' -> $PCAP"
tcpdump -i any -nn -s0 -w "$PCAP" 'tcp port 25' >/dev/null 2>&1 &
DPID=$!
sleep 2

echo "[2] Gui truc tiep bang swaks toi mail2.congtyB.test:25 (khong --tls)"
swaks --server mail2.congtyB.test --port 25 \
      --from    "giamdoc@congtyA.test" \
      --to      "ketoan@congtyB.test" \
      --helo    "mail1.congtyA.test" \
      --header  "Subject: Hop ban so luat - tai lieu kem theo" \
      --header  "X-Lab-Mark: AT-02-cleartext" \
      --body    "Ket noi ho so va tai khoan ngan hang: $TOK_SWAKS - AlphaBank." 2>&1 | tee "$EVID/at02-swaks.log"

echo
echo "[3] Gui qua hang doi Postfix (sendmail -> smtp -> mail2:25)"
printf 'From: giamdoc@congtyA.test\r\nTo: ketoan@congtyB.test\r\nSubject: [AT-02 qua Postfix] Hop so thu ky dien tu\r\nX-Lab-Mark: AT-02-POSTFIX\r\n\r\nMa so tai khoan di qua nhop MTA-to-MTA: %s - AlphaBank.\r\n' "$TOK_PF" \
  | /usr/sbin/sendmail -f giamdoc@congtyA.test ketoan@congtyB.test
sleep 4
grep -aE 'relay=mail2' /var/log/mail.log | tail -3 > "$LOGMARK"
sed 's/^/  /' "$LOGMARK"

sleep 1
kill "$DPID" 2>/dev/null || true
sleep 1

echo
echo "[4] Trich xuat noi dung ban ro tu pcap (tcpdump -A -r)"
{
  echo "# time $(date -u '+%F %T') UTC - $(postconf -h myhostname)"
  echo "# tcpdump -r $PCAP -A -nn 'tcp port 25'"
  tcpdump -r "$PCAP" -A -nn 'tcp port 25' 2>/dev/null | sed -n '1,200p'
  echo
  echo "--- [5] Bang thong ke dem duoc ---"
  for pat in 'STARTTLS' "MAIL FROM" "RCPT TO" "X-Lab-Mark: AT-02-cleartext" "X-Lab-Mark: AT-02-POSTFIX" "$TOK_SWAKS" "$TOK_PF"; do
    printf '  so lan xuat hien ban ro "%s": %s\n' "$pat" "$(tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -c "$pat" || true)"
  done
  echo "--- Duong dan cua hai phien ---"
  tcpdump -r "$PCAP" -A -nn 2>/dev/null | grep -a -E 'MAIL FROM|RCPT TO|Subject:|X-Lab-Mark' | sed 's/^/  /'
} | tee "$TXT"

echo
echo "  Bang chung: $TXT, $PCAP, $EVID/at02-swaks.log, $LOGMARK"
