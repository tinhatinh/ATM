#!/bin/bash
# Cac lenh dung de chup anh bang chung tren vm-dns (10.30.0.10).
# Cach dung: bash /root/shot/vm-dns.sh <ten>   (moi ten in ra <= 24 dong)
set -u
D=10.30.0.10
case "${1:-}" in

zone)                                   # H: BIND kiem tra cu phap + nap zone
  echo "root@vm-dns:~# named-checkconf /etc/bind/named.conf"
  named-checkconf /etc/bind/named.conf && echo "  (khong co loi - OK)"
  echo
  echo "root@vm-dns:~# named-checkzone <ten> <file>   # 4 zone: 3 thuan + 1 nguoc"
  for z in "congtyA.test db.congtyA.test" "congtyB.test db.congtyB.test" \
           "darkside.test db.darkside.test" "0.30.10.in-addr.arpa db.10.30.0"; do
    set -- $z
    named-checkzone "$1" "/var/lib/bind/$2" 2>&1 | sed 's/^/  /' | tail -2
  done
  echo
  echo "root@vm-dns:~# rndc reload && systemctl is-active bind9"
  rndc reload && systemctl is-active bind9
  echo
  echo "root@vm-dns:~# ss -lnt | grep :53"
  ss -lnt | grep ':53 ' | sed 's/^/  /'
  ;;

records)                                # H: toan bo ban ghi dinh danh da cong bo
  bash /root/lab/verify/v01-dns-records.sh 2>&1 | tail -22
  ;;

quyhoach)                               # H: noi dung zone congtyA.test
  echo "root@vm-dns:~# grep -vE '^\\s*;|^\\s*\$' /var/lib/bind/db.congtyA.test | head -20"
  grep -vE '^\s*;|^\s*$' /var/lib/bind/db.congtyA.test | head -18
  ;;

recursion)                              # H: may chu DNS tu choi phan giai de quy
  echo "root@vm-dns:~# grep -E 'recursion|dnssec|listen' /etc/bind/named.conf.options | grep -v '^//'"
  grep -E 'recursion|dnssec-validation|listen-on' /etc/bind/named.conf.options | grep -v '^\s*//' | sed 's/^/  /'
  echo
  echo "root@vm-dns:~# dig @10.30.0.10 www.google.com A +short     # ngoai lab"
  dig @10.30.0.10 www.google.com A +noall +comments +short 2>&1 | grep -iE 'status|REFUSED' | head -2
  dig @10.30.0.10 www.google.com A 2>&1 | grep -E 'status:|;; ->>HEADER' | sed 's/^/  /'
  ;;
*) exit 2 ;;
esac
