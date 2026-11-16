#!/usr/bin/env bash
# Cat VM sang VMnet host-only 10.30.0.0/24, dat IP tinh, tro DNS ve 10.30.0.10.
# CHAY SAU khi 00-apt.sh da xong (luu y: tu buoc nay VM khong con Internet nua).
#   sudo bash install/00-base.sh 10.30.0.10 ns1.congtyA.test vm-dns
#   sudo bash install/00-base.sh 10.30.0.20 mail1.congtyA.test vm-mail1
#   sudo bash install/00-base.sh 10.30.0.30 mail2.congtyB.test vm-mail2
#   sudo bash install/00-base.sh 10.30.0.40 atk.darkside.test vm-atk
#   sudo bash install/00-base.sh 10.30.0.50 client.congtyA.test vm-client
set -euo pipefail

IP="${1:?Thieu dia chi IP tinh}"
FQDN="${2:?Thieu FQDN, vi du: mail1.congtyA.test}"
SHORT="${3:?Thieu hostname ngan, vi du: vm-mail1}"

[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root (dong lenh phai la root@...)"; exit 1; }

IF="${4:-$(ip -o link show | awk -F': ' '$2!="lo" && $2 !~ /^(docker|br-|virbr|veth)/ {print $2; exit}')}"
[ -d "/sys/class/net/$IF" ] || {
  echo "Loi: khong tim thay ao dong '$IF'. Kiem tra: ip -br link"
  exit 1
}

echo "Ao dong lab  : $IF"
echo "IP moi      : $IP/24 (khong co gateway - mang host-only)"
echo "FQDN        : $FQDN"

# 1. Ngan cloud-init ghi de lai netplan sau khi khoi dong
mkdir -p /etc/cloud/cloud.cfg.d
printf 'network: {config: disabled}\n' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# 2. Netplan tinh, renderer networkd (KHONG dung systemd-resolved)
cat > /etc/netplan/60-lab.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF:
      dhcp4: no
      dhcp6: no
      addresses:
        - $IP/24
      nameservers:
        addresses:
          - 10.30.0.10
        search:
          - congtyA.test
          - congtyB.test
EOF
chmod 600 /etc/netplan/60-lab.yaml

# 3. Tenant + /etc/hosts (giup bootstrap truoc khi DNS keo)
#    LUU Y: luon phai co ca ten may (vm-mail1) vi do la hostname do
#    hostnamectl dat; thieu no thi moi lenh sudo in ra
#    "sudo: unable to resolve host vm-mail1".
hostnamectl set-hostname "$SHORT"
sed -i '/^127.0.1.1/d' /etc/hosts
sed -i "/[[:space:]]${SHORT}\$/d" /etc/hosts
cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   ${SHORT}
10.30.0.10  ns1.congtyA.test      ns1        vm-dns
10.30.0.20  mail1.congtyA.test    mail1      vm-mail1
10.30.0.30  mail2.congtyB.test    mail2      vm-mail2
10.30.0.40  atk.darkside.test     atk        vm-atk
10.30.0.50  client.congtyA.test   client     vm-client
EOF

# 4. Tat systemd-resolved va TU VIET /etc/resolv.conf.
#    Ly do phai viet tay: khi resolved da bi tat, systemd-networkd KHONG tu tao
#    lai /etc/resolv.conf tren Ubuntu 24.04 -> neu chi `rm` thi may mat het duong
#    tra ten, va Postfix/OpenDKIM/policyd-spf khong phan giai duoc MX.
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf

netplan apply
sleep 3

printf 'nameserver 10.30.0.10\nsearch congtyA.test congtyB.test\noptions timeout:1 attempts:2\n' > /etc/resolv.conf

echo
echo "=== XAC MINH ==="
ip -4 -br addr show "$IF"
echo "--- /etc/resolv.conf ---"
cat /etc/resolv.conf
echo "--- ping thong ke giua cac may (host-only) ---"
for peer in 10.30.0.1 10.30.0.10 10.30.0.20 10.30.0.30 10.30.0.40 10.30.0.50; do
  if ping -c1 -W1 "$peer" >/dev/null 2>&1; then echo "$peer  OK"; else echo "$peer  khong dap (binh thong neu may do chua bat)"; fi
done

echo
echo "--- dong ho (TLS/DKIM chiu anh huong cua sai gio) ---"
date -u

if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi 'Status: active'; then
  echo
  echo "LUU Y: UFW dang bat - can mo cong lab, chay tung dong:"
  echo "  ufw allow 53/udp; ufw allow 53/tcp; ufw allow 25/tcp; ufw allow 587/tcp; ufw allow 143/tcp; ufw allow 993/tcp"
fi

echo
