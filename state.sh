#!/usr/bin/env bash
# In trang thai cau hinh theo chuan co dinh, de driver so sanh TRUOC/SAU tung buoc.
#   bash /root/lab/state.sh          -> tu nhan dien vai tro theo IP
#   bash /root/lab/state.sh mail|dns -> cu the hoa
set -uo pipefail

R="${1:-auto}"
if [ "$R" = auto ]; then
  case "$(hostname -I | awk '{print $1}')" in
    10.30.0.10) R=dns ;;
    10.30.0.20|10.30.0.30) R=mail ;;
    *) R=other ;;
  esac
fi

case "$R" in
  mail)
    echo '## postconf'
    postconf -n 2>/dev/null | LC_ALL=C sort
    echo '## doveconf'
    doveconf -n 2>/dev/null | LC_ALL=C sort
    echo '## aliases'
    cat /etc/aliases 2>/dev/null | grep -vE '^[[:space:]]*(#|$)' | LC_ALL=C sort
    echo '## dkim-keys'
    ls -l /etc/dkimkeys 2>/dev/null
    echo '## opendkim.conf'
    grep -vE '^[[:space:]]*(#|$)' /etc/opendkim.conf 2>/dev/null | LC_ALL=C sort
    echo '## opendmarc.conf'
    grep -vE '^[[:space:]]*(#|$)' /etc/opendmarc.conf 2>/dev/null | LC_ALL=C sort
    echo '## tls-files'
    ls -l /etc/ssl/certs/lab-ca.crt /etc/ssl/certs/lab-mail.crt /etc/ssl/private/lab-mail.key 2>/dev/null
    echo '## master.cf'
    grep -vE '^[[:space:]]*#' /etc/postfix/master.cf 2>/dev/null | grep -vE '^[[:space:]]*$'
    echo '## services'
    systemctl is-active postfix dovecot opendkim opendmarc 2>/dev/null
    ;;
  dns)
    echo '## identity-files'
    for D in congtyA.test congtyB.test darkside.test; do
      echo "--- $D"
      cat "/var/lib/bind/lab/$D.identity" 2>/dev/null | grep -vE '^[[:space:]]*(;|$)'
    done
    echo '## zone-serials'
    for D in congtyA.test congtyB.test darkside.test; do
      printf '%s ' "$D"
      sed -n -E 's/^[[:space:]]*([0-9]{10})[[:space:]]*;[[:space:]]*serial.*/\1/p' "/var/lib/bind/db.$D" 2>/dev/null
    done
    echo '## dig'
    for D in congtyA.test congtyB.test; do
      printf 'SPF   %s : ' "$D";   dig @127.0.0.1 TXT "$D" +short 2>/dev/null | tr '\n' ' '; echo
      printf 'DMARC %s : ' "$D";   dig @127.0.0.1 _dmarc."$D" TXT +short 2>/dev/null | tr '\n' ' '; echo
      printf 'DKIM  %s : ' "$D";   dig @127.0.0.1 mail._domainkey."$D" TXT +short 2>/dev/null | tr '\n' ' '; echo
    done
    echo '## labca'
    ls -l /srv/labca 2>/dev/null
    echo '## services'
    systemctl is-active bind9 2>/dev/null
    ss -ltn 2>/dev/null | grep -E ':(53|8080)[[:space:]]'
    ;;
  *)
    echo "## role $R : may nay khong giu cau hinh phong thu (chi sinh bang chung)"
    ;;
esac
