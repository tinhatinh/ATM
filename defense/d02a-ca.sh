#!/usr/bin/env bash
# D-02a  Lam CA cua lab + cap chung chi TLS cho mail1/mail2  (chay tren vm-dns)
#   sudo bash defense/d02a-ca.sh
#   sudo bash defense/d02a-ca.sh stop      (tat het phat chung chi khi xong lab)
#
# Ly do co CA rieng: STARTTLS chi co nghia khi chu chung duoc xac minh. Voi
# `smtp_tls_security_level = verify` (d02b che do encrypt), MTA pha biet CA nao
# dang tin cay -> khong the dung snakeoil cua Ubuntu duoc nua.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root TREN vm-dns"; exit 1; }
OUT=/srv/labca
ACTION="${1:-build}"

if [ "$ACTION" = "stop" ]; then
  pkill -f 'http.server 8080' 2>/dev/null || true
  echo "Da tat dich vu phat tai lieu chung chi (cong 8080)."
  exit 0
fi

mkdir -p "$OUT"; cd "$OUT"

echo "=== [1] Root CA cua lab ==="
if [ ! -f lab-ca.key ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes \
    -keyout lab-ca.key -out lab-ca.crt \
    -subj "/C=VN/O=PTIT INT1482 ATM Lab/CN=Lab Mail Root CA"
fi
openssl x509 -in lab-ca.crt -noout -subject -issuer -dates

for SPEC in "mail1.congtyA.test:Alpha:10.30.0.20" "mail2.congtyB.test:Beta:10.30.0.30"; do
  H="${SPEC%%:*}"; REST="${SPEC#*:}"; ORG="${REST%%:*}"; IP="${REST##*:}"
  DOM="${H#*.}"
  echo
  echo "=== [2] Chung chi cho $H ($IP) ==="
  [ -f "$H.key" ] || openssl genrsa -out "$H.key" 2048
  openssl req -new -key "$H.key" -subj "/C=VN/O=Cong ty $ORG/CN=$H" -out "$H.csr"
  cat > "$H.ext" <<EOF
subjectAltName=DNS:$H,DNS:mail.$DOM,IP:$IP
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF
  openssl x509 -req -in "$H.csr" -CA lab-ca.crt -CAkey lab-ca.key -CAcreateserial \
    -days 825 -sha256 -extfile "$H.ext" -out "$H.crt"
  echo "--- xac minh chu chung ky boi Lab CA, SAN = $H,$IP ---"
  openssl verify -CAfile lab-ca.crt "$H.crt"
  openssl x509 -in "$H.crt" -noout -subject -issuer -dates -ext subjectAltName
done

echo
echo "=== [3] Mo dich vu phat file noi bo (chi tren 10.30.0.10:8080) ==="
if ! ss -ltn | grep -q ':8080'; then
  nohup python3 -m http.server 8080 --bind 10.30.0.10 --directory "$OUT" \
      > /var/log/labca-http.log 2>&1 &
  sleep 1
fi
ss -ltn | grep ':8080'
echo "Danh sach file phat ra:"
ls -l "$OUT"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# ========================================================================
#  BUOC TIEP THEO - chay tren vm-mail1 va vm-mail2 (moi may 1 lenh):
#    sudo bash defense/d02b-tls.sh may
#  Khi toan bo lab o che do opportunistic (may) va xong AT-06 thi:
#    sudo bash defense/d02b-tls.sh encrypt
#  Khi lab ket thuc, TAT dich vu phat file tren vm-dns:
#    sudo bash defense/d02a-ca.sh stop
# ========================================================================
#  LUU Y SU PHAM (viet duoc vao bao cao Phan 4): private key di qua HTTP trong
#  khoang net noi bo cua lab. Trong san xuat dung: scp/tls mang quan tri, SCEP/EST,
#  hoac ky thu cong khoa va ky tay chu key tren may chu - key khong roi may chu.
# ========================================================================
# HuongDan
