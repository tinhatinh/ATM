#!/bin/bash
# Lenh chup anh bang chung tren vm-atk (10.30.0.40 - may tan cong).
# bash /root/shot/vm-atk.sh <ten>
set -u
E=/root/evidence/atk
case "${1:-}" in

relaytrc)                      # H: TRUOC phong thu - toan bo 3 bang chung open relay
  echo "root@vm-atk:~# cat /root/evidence/atk/at01-open-relay.txt | grep -E 'open relay|RCPT|250 2.1.5'"
  echo "    (file bang chung luu luc 08:54 UTC, 18/10/2026 - Giai doan 2)"
  grep -aE "open relay|RCPT TO|250 2.1.5|VRFY|252" /root/evidence/atk/at01-open-relay.txt 2>/dev/null | head -6 | sed 's/^/  /'
  echo
  echo "root@vm-atk:~# grep 'open relay' /root/lab/docs/03-test-cases.md   # ket luan da ghi khi do"
  grep -aoE "Server is an open relay \(16/16 tests\)[^|]*" /root/lab/docs/03-test-cases.md | head -2 | sed 's/^/  /'
  ;;

spooftrc)                      # H: TRUOC phong thu - gia mao Header From that cong
  echo "root@vm-atk:~# swaks --to ketoan@congtyB.test --from admin@congtyA.test --server mail2.congtyB.test --header 'Subject: CANH BAO'"
  grep -aE "^ +[<-]  (2[0-9][0-9]|25[0-9])|queued|Subject:|Reply-To:|MAIL FROM|RCPT TO" $E/at04-spoof.log | head -14 | sed 's/^/  /'
  ;;

strip)                         # H: log proxy MitM - ba hanh dong gay ra
  echo "root@vm-atk:~# grep -E 'STRIP|AUTH-THIEP|TAMPER' /root/evidence/atk/at06-proxy.log"
  grep -aE "STRIP|AUTH-THIEP|TAMPER|LISTEN" $E/at06-proxy.log 2>/dev/null | head -9 | sed 's/^/  /'
  echo
  echo "root@vm-atk:~# swaks cua nan nhan (qua proxy 2525) - ket luan phien"
  grep -aE "did not advertise|Authentication successful|queued|exit code" $E/../atk/at06-proxy.stdout 2>/dev/null | head -4 | sed 's/^/  /'
  grep -aE "did not advertise|Authentication successful|queued as|exit code" /root/evidence/client/at06-downgrade.txt 2>/dev/null | head -4 | sed 's/^/  /'
  ;;

replay)                        # H: PHAT LAI 5 tan cong sau phong thu
  echo "root@vm-atk:~# bash /root/lab/verify/v03-replay-attacks.sh"
  bash /root/lab/verify/v03-replay-attacks.sh 2>&1 | sed -n '/BANG TOM TAT/,$p' | head -10
  ;;

*) exit 2 ;;
esac
