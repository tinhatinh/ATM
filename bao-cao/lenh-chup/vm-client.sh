#!/bin/bash
# Lenh chup anh bang chung tren vm-client (10.30.0.50 - MUA + may do).
# bash /root/shot/vm-client.sh <ten>
set -u
E=/root/evidence/client
case "${1:-}" in

cred)                          # H: danh cap credential qua AUTH LOGIN ban ro (AT-03)
  echo "root@vm-client:~# grep -E 'AUTH|334|base64|235|queued' /root/evidence/client/at03-credentials.txt"
  grep -aE "250-AUTH|334 |^  *AUTH|giải mã|base64 -d|giamdoc|Lab@2026|235 |queued" $E/at03-credentials.txt 2>/dev/null | head -12 | sed 's/^/  /'
  ;;

happy)                         # H: duong di thu hop le Alpha -> Beta (V-02)
  echo "root@vm-client:~# bash /root/lab/verify/v02-happy-path.sh"
  bash /root/lab/verify/v02-happy-path.sh 2>&1 | grep -aE "^ +[<-~]|queued|exit code|235|Authentication" | tail -14
  ;;

tls)                           # H: STARTTLS that + chan downgrade (V-04)
  echo "root@vm-client:~# bash /root/lab/verify/v04-tls-and-downgrade.sh"
  bash /root/lab/verify/v04-tls-and-downgrade.sh 2>&1 | grep -aE "Verify return code|Protocol|TLS[vs]|530|538|Must issue|exit code|did not advertise|queued" | head -14 | sed 's/^/  /'
  ;;

imaps)                         # H: IMAPS 993 + chan AUTH ngoai TLS
  echo "root@vm-client:~# openssl s_client -connect mail2.congtyB.test:993 -CAfile /etc/ssl/certs/lab-ca.crt -brief"
  timeout 8 openssl s_client -connect mail2.congtyB.test:993 -CAfile /etc/ssl/certs/lab-ca.crt -brief 2>&1 | head -6 | sed 's/^/  /'
  echo
  echo "root@vm-client:~# doi chieu: IMAP 143 khong TLS"
  echo "  $(timeout 6 python3 -c "
import socket
s=socket.create_connection(('mail2.congtyB.test',143),5)
print(s.recv(200).decode(errors='replace').strip())
s.sendall(b'a1 LOGIN ketoan Lab@2026\r\n')
print('a1 LOGIN ->', s.recv(200).decode(errors='replace').strip())
" 2>&1 | tr '\n' ' | ')"
  ;;

*) exit 2 ;;
esac
