#!/bin/bash
# Lenh chup anh bang chung tren vm-mail2 (10.30.0.30 - MTA Beta, nha phong thu).
# bash /root/shot/vm-mail2.sh <ten>
set -u
LAST=$(ls -t /home/ketoan/Maildir/new/* 2>/dev/null | head -1)
case "${1:-}" in

spf)                           # H: bo loc SPF duoc ban hanh the nao
  echo "root@vm-mail2:~# grep -vE '^\\s*#|^\\s*$' /etc/postfix-policyd-spf-python/policyd-spf.conf"
  grep -vE '^\s*#|^\s*$' /etc/postfix-policyd-spf-python/policyd-spf.conf | sed 's/^/  /'
  echo
  echo "root@vm-mail2:~# grep -A1 'policyd-spf  unix' /etc/postfix/master.cf"
  grep -A1 'policyd-spf  unix' /etc/postfix/master.cf | sed 's/^/  /'
  echo
  echo "root@vm-mail2:~# postconf -h smtpd_recipient_restrictions"
  postconf -h smtpd_recipient_restrictions | tr ',' '\n' | sed 's/^/  /'
  ;;

spfdns)                        # H: ban ghi SPF da cong bo tren DNS
  echo "root@vm-mail2:~# dig @10.30.0.10 congtyA.test TXT +short"
  echo "  $(dig @10.30.0.10 congtyA.test TXT +short)"
  echo "root@vm-mail2:~# dig @10.30.0.10 congtyB.test TXT +short"
  echo "  $(dig @10.30.0.10 congtyB.test TXT +short)"
  echo
  echo "root@vm-mail2:~# postconf -h myhostname; systemctl is-active postfix dovecot opendkim opendmarc"
  echo "  $(postconf -h myhostname)"
  for s in postfix dovecot opendkim opendmarc; do printf '  %-10s %s\n' "$s" "$(systemctl is-active $s)"; done
  ;;

dmarc)                         # H: OpenDMARC p=reject + thu tu milter
  echo "root@vm-mail2:~# grep -vE '^\\s*#|^\\s*$' /etc/opendmarc.conf"
  grep -vE '^\s*#|^\s*$' /etc/opendmarc.conf | sed 's/^/  /' | head -10
  echo
  echo "root@vm-mail2:~# postconf -h smtpd_milters non_smtpd_milters milter_default_action"
  echo "  smtpd_milters        = $(postconf -h smtpd_milters)"
  echo "  non_smtpd_milters    = $(postconf -h non_smtpd_milters)"
  echo "  milter_default_action= $(postconf -h milter_default_action)"
  echo
  echo "root@vm-mail2:~# grep -A2 '^submission' /etc/postfix/master.cf   # DMARC chi ap dung cong 25"
  grep -A2 '^submission' /etc/postfix/master.cf | sed 's/^/  /'
  ;;

dns)                           # H: ba ban ghi dinh danh cua ca hai mien
  echo "root@vm-mail2:~# for d in congtyA congtyB; do dig _dmarc.\$d.test TXT +short; done"
  for d in congtyA congtyB; do
    echo "  _dmarc.$d.test  $(dig @10.30.0.10 _dmarc.$d.test TXT +short)"
  done
  echo "  mail._domainkey.congtyA.test  $(dig @10.30.0.10 mail._domainkey.congtyA.test TXT +short | cut -c1-72)..."
  echo "  mail._domainkey.congtyB.test  $(dig @10.30.0.10 mail._domainkey.congtyB.test TXT +short | cut -c1-72)..."
  ;;

auth)                          # H: header xac thuc tren thu den hop le
  bash /root/lab/verify/v05-auth-results.sh ketoan 2>&1 \
    | grep -aE 'Authentication-Results|Received-SPF|^DKIM-Signature' | cut -c1-118 | head -8
  ;;

dkimverify)                    # H: kiem chu DKIM doc lap (RFC 6376 3.5)
  echo "root@vm-mail2:~# python3 /root/lab/verify/dkim-check.py $LAST"
  python3 /root/lab/verify/dkim-check.py "$LAST" 2>&1 | tail -14
  ;;

testkey)                       # H: gioi han - milter khong lay duoc khoa qua libunbound
  echo "root@vm-mail2:~# opendkim-testkey -d congtyB.test -s mail -vvv 2>&1 | tail -4"
  opendkim-testkey -d congtyB.test -s mail -vvv 2>&1 | tail -4 | sed 's/^/  /'
  echo
  echo "root@vm-mail2:~# dig @10.30.0.10 mail._domainkey.congtyB.test TXT +short | cut -c1-60"
  echo "  $(dig @10.30.0.10 mail._domainkey.congtyB.test TXT +short | cut -c1-60)...   <- DNS TRA VE DU"
  echo
  echo "root@vm-mail2:~# ldd /usr/sbin/opendkim | grep unbound"
  ldd /usr/sbin/opendkim | grep -a unbound | sed 's/^/  /'
  ;;

rejects)                       # H: log may chu ghi lai hai lan chan
  echo "root@vm-mail2:~# tail -n 200 /var/log/mail.log | grep -E 'policyd-spf|opendmarc' | tail -8"
  tail -n 200 /var/log/mail.log | grep -aE 'policyd-spf|opendmarc' | tail -7 | cut -c1-118 | sed 's/^/  /'
  ;;

inbox)                         # H: hop thu nan nhan + 3 bo dem header xac thuc
  echo "root@vm-mail2:~# grep -E '^(From|Reply-To|Subject)' $LAST"
  grep -aE '^(From|Reply-To|Subject):' "$LAST" | sed 's/^/  /' | head -4
  echo
  echo "root@vm-mail2:~# for h in Authentication-Results Received-SPF DKIM-Signature; do grep -ac \$h file; done"
  for h in Authentication-Results Received-SPF DKIM-Signature; do
    printf '  %-24s %s\n' "$h" "$(grep -ac "$h" "$LAST")"
  done
  ;;

spoofinbox)                    # H: hop thu nan nhan - 3 bo dem header bang 0
  F=/root/evidence/mail2/at04-inbox-ketoan.txt
  echo "root@vm-mail2:~# cat $F   (bang chung AT-04, 09:03 UTC 18/10)"
  grep -aE "^(From|Reply-To|Subject|Received)|Authentication-Results|Received-SPF|DKIM-Signature|Maildir|so dong" "$F" 2>/dev/null | head -16
  ;;

*) exit 2 ;;
esac
