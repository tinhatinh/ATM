#!/usr/bin/env bash
# AT-01  May mail co OPEN RELAY khong?  (chay tren vm-atk - 10.30.0.40)
#   bash attacks/at01-open-relay.sh                -> ca 2 MTA (mail1 + mail2)
#   bash attacks/at01-open-relay.sh 10.30.0.20     -> chi mail1 (mot luot in ra)
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

if [ "$#" -gt 0 ]; then TARGETS=("$@"); else TARGETS=("10.30.0.20" "10.30.0.30"); fi
for T in "${TARGETS[@]}"; do
  case "$T" in
    10.30.0.*) ;;
    *) echo "TU CHOI: '$T' ngoai dai lab 10.30.0.0/24."; exit 1 ;;
  esac
done
NT=${#TARGETS[@]}
EVID=/root/evidence/atk; mkdir -p "$EVID"
OUT="$EVID/at01-open-relay.txt"
: > "$OUT"

I=0
for T in "${TARGETS[@]}"; do
  I=$((I + 1))
  {
    echo "##################################################################"
    echo "# AT-01  $I/$NT  $T  $(date -u '+%F %T') UTC"
    echo "##################################################################"

    echo "--- [1] Quet cong + banner + thu tuyen lenh SMTP ---"
    echo "# nmap -Pn -p 25,587 --script smtp-commands $T"
    nmap -Pn -p 25,587 --script smtp-commands "$T" 2>&1

    echo
    echo "--- [2] Doan script chuyen dung phat hien open relay ---"
    echo "# nmap -Pn -p 25 --script smtp-open-relay $T"
    nmap -Pn -p 25 --script smtp-open-relay "$T" 2>&1

    echo
    echo "--- [3] Chung minh thu cong: xin relay toi domain NGOAI 2 domain cua lab ---"
    echo "# swaks --server $T --from attacker@darkside.test --to nguoidung@khong-phai-domain-lab.test --quit-after RCPT"
    swaks --server "$T" --port 25 \
          --from "attacker@darkside.test" \
          --to   "nguoidung@khong-phai-domain-lab.test" \
          --quit-after RCPT 2>&1

    echo
    echo "--- [4] Lam dung VRFY de liet ke user (recon) ---"
    printf 'EHLO atk.darkside.test\r\nVRFY root\r\nVRFY giamdoc\r\nQUIT\r\n' \
      | ncat -w 5 "$T" 25 2>&1 | sed 's/^/  /'
  } 2>&1 | tee -a "$OUT"
done

echo
echo "Bang chung: $OUT"
