#!/usr/bin/env bash
# D-02b  Bat STARTTLS tren MTA + Dovecot.  Chay tren vm-mail1 HOAC vm-mail2.
#   sudo bash defense/d02b-tls.sh may        (opportunistic TLS - cho AT-06)
#   sudo bash defense/d02b-tls.sh encrypt    (mandatory TLS + verify + IMAPS)
# Dieu kien: vm-dns dang chay dich vu phat chung chi (defense/d02a-ca.sh).
set -euo pipefail

MODE="${1:?may hoac encrypt}"
[ "$(id -u)" -eq 0 ] || { echo "Loi: chay bang root tren vm-mail1/vm-mail2"; exit 1; }
case "$MODE" in may|encrypt) ;; *) echo "may | encrypt"; exit 1 ;; esac

# Lay FQDN tu myhostname cua Postfix: `hostname -f` co the tra ve 'vm-mail1'
# (khong dau cham) khi /etc/hosts con dong 127.0.1.1 -> ten chu chung sai.
HOST="$(postconf -h myhostname 2>/dev/null || hostname -f)"
case "$HOST" in
  *.*.test) ;;
  *) echo "Loi: khong lay duoc FQDN cua may (HOST='$HOST'). Chay: postconf -h myhostname"; exit 1 ;;
esac
DOMAIN="${HOST#*.}"
EVID="/root/evidence/$(echo "$HOST" | cut -d. -f1)"; mkdir -p "$EVID"
CA=http://10.30.0.10:8080

echo "=== [1] Lay chung chi tu vm-dns cho $HOST ==="
curl -fsS -o /tmp/lab-ca.crt  "$CA/lab-ca.crt"
curl -fsS -o "/tmp/$HOST.crt" "$CA/$HOST.crt"
curl -fsS -o "/tmp/$HOST.key" "$CA/$HOST.key"
echo "  da tai: lab-ca.crt, $HOST.crt, $HOST.key"

install -m 644 /tmp/lab-ca.crt    /etc/ssl/certs/lab-ca.crt
install -m 644 "/tmp/$HOST.crt"   /etc/ssl/certs/lab-mail.crt
install -m 640 -o root -g postfix "/tmp/$HOST.key" /etc/ssl/private/lab-mail.key
install -m 644 /tmp/lab-ca.crt    /usr/local/share/ca-certificates/lab-ca.crt
update-ca-certificates >/dev/null
openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -subject -dates -ext subjectAltName

echo
echo "=== [2] Cau hinh Postfix TLS (che do: $MODE) ==="
postconf -c /etc/postfix -e \
  "smtpd_tls_cert_file=/etc/ssl/certs/lab-mail.crt" \
  "smtpd_tls_key_file=/etc/ssl/private/lab-mail.key" \
  "smtpd_tls_security_level=may" \
  "smtp_tls_security_level=may" \
  "smtp_tls_CAfile=/etc/ssl/certs/lab-ca.crt" \
  "smtpd_tls_loglevel=1" \
  "smtp_tls_loglevel=1" \
  "smtpd_tls_received_header=yes" \
  "smtpd_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1" \
  "smtp_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1" \
  "smtpd_tls_session_cache_database=btree:\${data_directory}/smtpd_scache" \
  "smtp_tls_session_cache_database=btree:\${data_directory}/smtp_scache"

if [ "$MODE" = "encrypt" ]; then
  # TLS bat buoc: khong chap phien lam, va khi GUI THI phai verify chu chung
  # cua dau ben kia (chong strip o chinh chieu MTA->MTA).
  postconf -c /etc/postfix -e \
    "smtpd_tls_security_level=encrypt" \
    "smtpd_tls_auth_only=yes" \
    "smtp_tls_security_level=verify" \
    "smtp_tls_loglevel=2"
else
  postconf -c /etc/postfix -e "smtpd_tls_auth_only=no"
fi

postfix check
systemctl restart postfix

echo
echo "=== [3] Cau hinh Dovecot (IMAP/IMAPS) ==="
# Ten file phai xep SAU 99-lab.conf theo ASCII: '99-lab-tls' < '99-lab.conf'
# (dau '-' 0x2D dung truoc dau '.' 0x2E), nen dung 99-z-tls.conf de no duoc doc
# CUOI CUNG va ghi de duoc 'ssl = no' o Giai doan 1.
if [ "$MODE" = "encrypt" ]; then
  cat > /etc/dovecot/conf.d/99-z-tls.conf <<'EOF'
# ==== D-02b encrypt: bat buoc TLS + cam AUTH ban ro ====
ssl = required
ssl_cert = </etc/ssl/certs/lab-mail.crt
ssl_key = </etc/ssl/private/lab-mail.key
ssl_min_protocol = TLSv1.2
disable_plaintext_auth = yes
EOF
  # Ghi de 2 dong yeu trong 99-lab.conf (Giai doan 1)
  sed -i -E 's/^disable_plaintext_auth = no/disable_plaintext_auth = yes/; s/^ssl = no/ssl = yes/' /etc/dovecot/conf.d/99-lab.conf
else
  cat > /etc/dovecot/conf.d/99-z-tls.conf <<'EOF'
# ==== D-02b may: co TLS nhung van cho AUTH ban ro (de AT-06 chung minh downgrade) ====
ssl = yes
ssl_cert = </etc/ssl/certs/lab-mail.crt
ssl_key = </etc/ssl/private/lab-mail.key
ssl_min_protocol = TLSv1.2
EOF
fi
rm -f /etc/dovecot/conf.d/99-lab-tls.conf   # ten cu: xep TRUOC 99-lab.conf nen khong hieu luc
systemctl restart dovecot

echo
echo "=== [4] XAC MINH ==="
{
  echo "# time $(date -u '+%F %T') UTC - $HOST - mode $MODE"
  echo "--- postconf ---"
  postconf -n | grep -E '^smtpd?_(tls|TLS)' | grep -E 'security_level|protocols|cert_file|key_file|CAfile|auth_only|loglevel'
  echo "--- dovecot (dung -a: 'ssl = yes' trung gia tri mac dinh cua goi nen -n an no) ---"
  doveconf -a | grep -E '^(ssl|ssl_min_protocol|disable_plaintext_auth|mail_location|protocols) *='
  echo "--- cong nghe TLS ---"
  ss -ltn | grep -E ':(25|587|993)[[:space:]]'
  echo "--- EHLO cua $HOST co xuat hien STARTTLS? ---"
  # Khong dung ncat (chi o vai atk): doc socket bang /dev/tcp cua bash.
  exec 3<>/dev/tcp/127.0.0.1/25
  printf 'EHLO verifier.%s\r\nQUIT\r\n' "$DOMAIN" >&3
  timeout 5 cat <&3 | tr -d '\r' | grep -E '^(220|250)' || true
  exec 3<&- 3>&-
  echo "--- Bat tay TLS voi chinh no (openssl s_client) ---"
  openssl s_client -starttls smtp -connect "127.0.0.1:25" -CAfile /etc/ssl/certs/lab-ca.crt </dev/null 2>/dev/null \
    | grep -E '^New, |Protocol\s*:|Cipher\s*:|Verify return code:|subject=|issuer=' | sed 's/^/  /'
} | tee "$EVID/d02b-tls-$MODE.txt"

# (huong dan dan cho thanh vien nam trong docs/01-runbook-chay-lab.md)
# 
# Doc ket qua:
#   - 'Verify return code: 0 (ok)' + 'issuer= ... Lab Mail Root CA'  -> chu chung hop le.
#   - 'Protocol: TLSv1.3' -> kenh da duoc ma hoa (khong ai doc duoc noi dung).
#   - Sau 'sudo bash defense/d02b-tls.sh encrypt' thi chay lai AT-06:
#       vm-client:  sudo bash attacks/at06-starttls-strip.sh
#     -> swaks --tls-optional bi mail1 TU CHOI (khong cho phep phien khong TLS),
#        swaks --tls thi proxy khong con duoc trong duong dan. Ghi nguyen van ma 5xx.
# NHANXET
