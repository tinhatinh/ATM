#!/bin/bash
# Lenh chup anh bang chung tren vm-mail1 (10.30.0.20 - MTA Alpha).
# bash /root/shot/vm-mail1.sh <ten>
set -u
case "${1:-}" in

mang)                          # H: MAY AO + TINH NHAT DIA CHI
  echo "root@vm-mail1:~# ip -br addr show ens33 && postconf -h myhostname"
  ip -br addr show ens33 | sed 's/^/  /'
  echo "  myhostname = $(postconf -h myhostname)   mydomain = $(postconf -h mydomain)"
  echo
  echo "root@vm-mail1:~# cat /etc/netplan/60-lab.yaml"
  cat /etc/netplan/60-lab.yaml | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# cat /etc/resolv.conf"
  grep -v '^#' /etc/resolv.conf | sed 's/^/  /'
  ;;

trithuc)                       # B: tai nguyen + phien ban moi may ao
  echo "root@vm-mail1:~# nproc; free -m; df -h /; dpkg-query -W -f=\\'\\${Version}\\' postfix ..."
  echo "  vCPU : $(nproc)"
  echo "  RAM  : $(free -m | awk '/^Mem/{print $2}') MB"
  echo "  Disk : $(df -h / | awk 'NR==2{print $2}')"
  echo "  OS   : $(. /etc/os-release; echo $PRETTY_NAME)"
  echo "  SMTP : postfix $(postconf -h mail_version)"
  echo "  IMAP : dovecot $(dpkg-query -W -f='${Version}' dovecot-core)"
  echo "  DKIM : opendkim $(dpkg-query -W -f='${Version}' opendkim)"
  echo "  DMARC: opendmarc $(dpkg-query -W -f='${Version}' opendmarc)"
  echo "  SPF  : postfix-policyd-spf-python $(dpkg-query -W -f='${Version}' postfix-policyd-spf-python)"
  echo "  TLS  : openssl $(openssl version | awk '{print $2}')"
  ;;

ca)                            # H: CA RIENG CUA LAB + CHUNG CHI mail1
  echo "root@vm-mail1:~# openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -subject -issuer -dates"
  openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -subject -issuer -dates | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -ext subjectAltName"
  openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -ext subjectAltName | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# openssl verify -CAfile /etc/ssl/certs/lab-ca.crt /etc/ssl/certs/lab-mail.crt"
  openssl verify -CAfile /etc/ssl/certs/lab-ca.crt /etc/ssl/certs/lab-mail.crt | sed 's/^/  /'
  ;;

tls)                           # H: CAU HINH TLS sau D-02b
  echo "root@vm-mail1:~# postconf -n | grep -E 'smtpd?_(tls|TLS)'"
  postconf -n | grep -E '^smtpd?_(tls|TLS)' | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# doveconf -a | grep -E '^ssl|disable_plaintext_auth'"
  doveconf -a 2>/dev/null | grep -E '^ssl =|^ssl_min_protocol|^disable_plaintext_auth|^ssl_cert|^ssl_key' | sed 's/^/  /'
  ;;

dkim)                          # H: cau hinh OpenDKIM phia ky
  echo "root@vm-mail1:~# grep -vE '^\\s*#|^\\s*$' /etc/opendkim.conf"
  grep -vE '^\s*#|^\s*$' /etc/opendkim.conf | sed 's/^/  /' | head -14
  echo
  echo "root@vm-mail1:~# ls -l /etc/dkimkeys/ && head -c 96 /etc/dkimkeys/mail.txt"
  ls -l /etc/dkimkeys/ | sed 's/^/  /' | tail -3
  echo "  $(head -c 96 /etc/dkimkeys/mail.txt)..."
  ;;

relay)                         # H: dong relay - restriction that duoc ban hanh
  echo "root@vm-mail1:~# postconf -n | grep -E 'mynetworks|relay_restrictions|recipient_restrictions|sender_restrictions|helo_required|vrfy'"
  postconf -n | grep -E 'mynetworks|relay_restrictions|recipient_restrictions|sender_restrictions|helo_required|vrfy_command' | fold -w 110 | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# postconf -h smtpd_milters non_smtpd_milters"
  echo "  smtpd_milters      = $(postconf -h smtpd_milters)"
  echo "  non_smtpd_milters  = $(postconf -h non_smtpd_milters)"
  ;;

pcap)                          # H: NOI DUNG BAN RO TRONG GOI TIN (AT-02)
  echo "root@vm-mail1:~# tcpdump -A -nn -r /root/evidence/mail1/at02-smtp25.pcap | grep -E 'MAIL FROM|RCPT TO|Subject|1029384756'"
  tcpdump -A -nn -r /root/evidence/mail1/at02-smtp25.pcap 2>/dev/null \
    | grep -aoE 'MAIL FROM:<[^>]*>|RCPT TO:<[^>]*>|Subject: .*|.*1029384756.*' | head -8 | sed 's/^/  /'
  echo
  echo "root@vm-mail1:~# tcpdump -A -nn -r ... | grep -c STARTTLS"
  echo "  so dong chua STARTTLS trong bao goi: $(tcpdump -A -nn -r /root/evidence/mail1/at02-smtp25.pcap 2>/dev/null | grep -ac STARTTLS)"
  ;;

auth)                          # H: header xac thuc cua thu den Alpha (chieu Beta->Alpha)
  F=$(grep -las "Authentication-Results" /home/giamdoc/Maildir/new/* 2>/dev/null | tail -1)
  echo "root@vm-mail1:~# grep -E 'Authentication-Results|Received-SPF|^DKIM-Signature' <thu cuoi trong Maildir>"
  echo "  file: ${F#/home/}"
  grep -aE 'Authentication-Results|Received-SPF|^DKIM-Signature|^Return-Path|^From:' "$F" | cut -c1-118 | head -9
  ;;

dmarc)                         # H: opendmarc + milter chain tren Alpha
  echo "root@vm-mail1:~# grep -vE '^\\s*#|^\\s*$' /etc/opendmarc.conf"
  grep -vE '^\s*#|^\s*$' /etc/opendmarc.conf | sed 's/^/  /' | head -10
  echo
  echo "root@vm-mail1:~# postconf -h smtpd_milters; grep -A2 '^submission' /etc/postfix/master.cf"
  echo "  smtpd_milters = $(postconf -h smtpd_milters)"
  grep -A2 '^submission' /etc/postfix/master.cf | sed 's/^/  /'
  ;;

*) exit 2 ;;
esac
