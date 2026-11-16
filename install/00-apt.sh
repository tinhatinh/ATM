#!/usr/bin/env bash
# Cai package cho tung vai tro. Chay KHI VM CON o VMnet NAT (can Internet),
# TRUOC khi chay 00-base.sh đe cat sang mang host-only co lap.
#   sudo bash install/00-apt.sh dns
#   sudo bash install/00-apt.sh mail
#   sudo bash install/00-apt.sh atk
#   sudo bash install/00-apt.sh client
set -euo pipefail

ROLE="${1:?}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root (sudo -i)"; exit 1; }

SRC=/etc/apt/sources.list.d/ubuntu.sources
if [ -f "$SRC" ] && ! grep -qi 'universe' "$SRC"; then
  sed -i 's/^\(components:.*\)main\(.*\)$/\1main universe \2/' "$SRC"
  sed -i 's/^\(Components:.*\)main\(.*\)$/\1main universe \2/' "$SRC" || true
  echo "Da bat repository universe (can cho swaks/opendkim/opendmarc/policyd-spf)"
fi

apt-get update

PKG_COMMON="openssh-server ca-certificates tcpdump ipcalc curl"

case "$ROLE" in
  dns)     PKG_ROLE="bind9 bind9-utils bind9-dnsutils openssl"
           BIN_CHECK="named rndc openssl dig named-checkzone named-checkconf" ;;
  mail)    PKG_ROLE="postfix dovecot-core dovecot-imapd dovecot-lmtpd openssl mailutils opendkim opendkim-tools opendmarc postfix-policyd-spf-python swaks bind9-dnsutils"
           BIN_CHECK="postfix postconf doveconf sendmail openssl mail opendkim opendkim-genkey opendmarc policyd-spf swaks dig" ;;
  atk)     PKG_ROLE="swaks nmap ncat openssl python3 ettercap-text-only"
           BIN_CHECK="swaks nmap ncat openssl python3 ettercap" ;;
  client)  PKG_ROLE="mutt mailutils swaks tshark openssl"
           BIN_CHECK="mutt mail swaks tshark openssl" ;;
  *) echo "Role phai la: dns | mail | atk | client"; exit 1 ;;
esac

DEBIAN_FRONTEND=noninteractive apt-get install -y $PKG_COMMON $PKG_ROLE

echo
echo "=== XAC MINH 1: package da cai (ten + version that tu dpkg) ==="
ALL_PKGS="postfix dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools opendmarc postfix-policyd-spf-python bind9 bind9-utils bind9-dnsutils swaks nmap nmap-common ncat tcpdump ettercap-text-only mutt mailutils tshark openssl ipcalc curl openssh-server"
dpkg-query -W -f='${binary:Package}  ${Version}\n' $ALL_PKGS 2>/dev/null | sort

echo
echo "=== XAC MINH 2: binary cua vai tro $ROLE co ton tai khong ==="
MISSING=0
for b in $BIN_CHECK; do
  if command -v "$b" >/dev/null 2>&1; then
    printf '  co      %s\n' "$b"
  else
    printf '  THIEU   %s\n' "$b"
    MISSING=1
  fi
done
[ "$MISSING" -eq 0 ] && echo "OK: du package cho vai tro $ROLE." || echo "THIEU binary nhu tren - dung buoc tiep theo."
