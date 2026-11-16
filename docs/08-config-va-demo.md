# 08 · Cấu hình chi tiết + kịch bản demo (bản để nghiên cứu và phát triển)

> Tài liệu này liệt kê **giá trị cấu hình thật đang chạy trong lab** (trích từ `postconf -n`,
> `doveconf`, `opendkim.conf`, `opendmarc.conf`, `policyd-spf.conf` và `evidence/`), kèm ý nghĩa,
> cách kiểm chứng và kịch bản demo 15 phút. Khác với `01-runbook-chay-lab.md` (hướng dẫn *gõ gì*),
> ở đây giải thích *vì sao đặt như vậy* và *sửa chỗ nào nếu muốn phát triển thêm*.

Ký hiệu máy: `D`=vm-dns(.10) · `M1`=vm-mail1(.20) · `M2`=vm-mail2(.30) · `A`=vm-atk(.40) · `C`=vm-client(.50).

---

## 1. Nền tảng

| Hạng mục | Giá trị thật | Cách kiểm |
|---|---|---|
| Hypervisor | VMware Workstation, 5 VM guest `ubuntu-64` | `vmrun list` trên Windows |
| Mạng | **VMnet2 host-only**, `10.30.0.0/24`, **tắt DHCP**, host giữ `10.30.0.1` | Virtual Network Editor |
| HĐH | Ubuntu Server **24.04.5 LTS** (cả 5 máy) | `lsb_release -d` |
| Tài nguyên | D/A/C: 2 vCPU · 2048 MB · 20 GB — M1/M2: 1 vCPU · 1024 MB · 20 GB | `.vmx`: `memsize`, `numvcpus` |
| Interface | `ens33`, IP tĩnh qua **`/etc/netplan/60-lab.yaml`** (file `50-cloud-init.yaml` để nguyên) | `ip -br addr show ens33` |
| Resolver | `/etc/resolv.conf` → `nameserver 10.30.0.10`, `search congtyA.test congtyB.test`, `options timeout:1 attempts:2` | `cat /etc/resolv.conf` |
| Phiên bản | postfix **3.8.6**, dovecot **2.3.21**, bind9 **9.18.39**, opendkim **2.11.0~beta2**, opendmarc **1.4.2**, postfix-policyd-spf-python **3.0.4**, swaks **20240103.0**, nmap **7.94**, openssl **3.0.13** | `dpkg-query -W -f='${Version}' <gói>` |
| Snapshot | `G1-mail-tran` → `G2-ket-qua-tan-cong` → `G3-phong-thu` (đủ 5 máy) | `vmrun listSnapshots <vmx>` |
| User trong lab | M1: `giamdoc`, `admin` — M2: `ketoan`, `admin` — mật khẩu chung `Lab@2026`, hộp thư `~/Maildir` | `ls ~/Maildir/new` |

**Tên miền**: `congtyA.test`, `congtyB.test`, `darkside.test` — dùng TLD `.test` theo **RFC 6761**
(dành riêng cho thử nghiệm, Internet thật không bao giờ phân giải được). Đây là lý do mục 6.6 tồn tại.

---

## 2. DNS — BIND 9.18 (vm-dns)

Vùng đặt ở **`/var/lib/bind`** (không phải `/etc/bind`) vì AppArmor của bản phân phối chỉ cho phép
BIND ghi/đọc ở đó. Mỗi vùng có file *identity* riêng để `$INCLUDE`, nhờ đó script `d03b/d04b/d05a`
chỉ cần nối thêm dòng vào một file rồi tăng serial.

```
zone "congtyA.test"          type master   file "/var/lib/bind/db.congtyA.test"
zone "congtyB.test"          type master   file "/var/lib/bind/db.congtyB.test"
zone "darkside.test"         type master   file "/var/lib/bind/db.darkside.test"
zone "0.30.10.in-addr.arpa"  type master   file "/var/lib/bind/db.10.30.0"     # PTR
```

Bản ghi định danh **đã công bố và đã đo** (`verify/v01-dns-records.sh` → 6/6 PASS):

| Tên | Loại | Giá trị |
|---|---|---|
| `mail1.congtyA.test` | A | `10.30.0.20` |
| `congtyA.test` | MX | `10 mail1.congtyA.test.` |
| `congtyB.test` | MX | `10 mail2.congtyB.test.` |
| `20.0.30.10.in-addr.arpa` | PTR | `mail1.congtyA.test.` |
| `30.0.30.10.in-addr.arpa` | PTR | `mail2.congtyB.test.` |
| `congtyA.test` | TXT | `"v=spf1 ip4:10.30.0.20 mx -all"` |
| `congtyB.test` | TXT | `"v=spf1 ip4:10.30.0.30 mx -all"` |
| `mail._domainkey.congtyA.test` | TXT | `"v=DKIM1; h=sha256; k=rsa; s=email; " "p=MIIBIjAN…"` (392 ký tự base64) |
| `mail._domainkey.congtyB.test` | TXT | như trên, khoá của Beta |
| `_dmarc.congtyA.test` | TXT | `"v=DMARC1; p=reject; sp=none; adkim=r; aspf=r; pct=100; fo=1; rua=mailto:dmarc-reports@congtyA.test"` |
| `_dmarc.congtyB.test` | TXT | tương tự, `rua` về congtyB |

Cấu hình named (`/etc/bind/named.conf.options`):

```
recursion         no;
allow-recursion   { none; };
dnssec-validation no;
listen-on port 53     { 127.0.0.1; 10.30.0.10; };
listen-on-v6 port 53  { none; };
```

**Kiểm**: `named-checkconf`; `named-checkzone <tên> <file>` (4 vùng đều `OK`); `rndc reload`;
phép thử phủ định `dig @10.30.0.10 www.google.com` → **`status: REFUSED`** (chứng minh không phải
resolver công cộng).

**Phát triển**: nếu bật `recursion yes; allow-recursion { 10.30.0.0/24; };` thì BIND vừa uy quyền vừa
đệ quy nội bộ — đây là mấu chốt để OpenDKIM tự lấy được khoá (xem 6.6 và mục 7).

---

## 3. Postfix — trạng thái TRẦN (Giai đoạn 1) so với PHÒNG THỦ (Giai đoạn 3)

| Tham số | TRẦN (để tấn công thành công) | PHÒNG THỦ (đã ban hành) | Tác dụng của việc đổi |
|---|---|---|---|
| `mynetworks` | `127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 10.30.0.0/24` | `127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128` | Bỏ `/24` là đóng open relay |
| `smtpd_relay_restrictions` | `permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination` | `permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination` | `defer` → `reject`: thư ngoài phạm vi bị từ chối ngay tại `RCPT` (mã `554`) thay vì nhận rồi trả về người gửi |
| `smtpd_recipient_restrictions` | `permit_mynetworks` | `reject_non_fqdn_recipient, permit_sasl_authenticated, reject_unauth_destination, check_policy_service unix:private/policyd-spf` | Thêm SPF vào chuỗi |
| `smtpd_sender_restrictions` | (mặc định) | `reject_non_fqdn_sender, reject_unknown_sender_domain, permit_sasl_authenticated` | Chặn domain giả mạo không phân giải được |
| `smtpd_helo_required` | `no` | `yes` | Buộc EHLO đúng, có cơ sở dùng PTR |
| `disable_vrfy_command` | `no` | `yes` | Tắt oracle dò mailbox (rủi ro R7) |
| `smtpd_tls_security_level` | `none` (Giai đoạn 1) → `may` (Giai đoạn 2) | **`encrypt`** | `none` để nghe lén; `may` để demo hạ cấp; `encrypt` mới chặn được hạ cấp |
| `smtpd_tls_auth_only` | `no` | `yes` | Không quảng bá AUTH ngoài TLS → hết đánh cắp credential |
| `smtp_tls_security_level` | `may` | **`verify`** | Chiều gửi kiểm chứng chứng chỉ theo CA lab |
| `smtpd_tls_cert_file` / `key_file` | snakeoil mặc định | `/etc/ssl/certs/lab-mail.crt` / `/etc/ssl/private/lab-mail.key` | Chứng chỉ do CA lab cấp, có SAN |
| `smtpd_tls_protocols` | mặc định | `!SSLv2,!SSLv3,!TLSv1,!TLSv1.1` | Chỉ TLS 1.2/1.3 |
| `smtpd_milters` | (rỗng) | `inet:localhost:8891, inet:localhost:8893` | DKIM trước, DMARC sau |
| `non_smtpd_milters` | (rỗng) | `inet:localhost:8891, inet:localhost:8893` | Ký cả thư phát sinh nội bộ |
| `milter_default_action` | `tempfail` | `tempfail` | Lỗi milter → tạm từ chối, không âm thầm cho qua |
| `smtpd_error_sleep_time` / `smtpd_soft_error_limit` / `smtpd_hard_error_limit` | mặc định | `1s` / `10` / `20` (đặt trong `d01-close-relay.sh`) | Giới hạn hành vi gõ cửa liên tục |

**Bẫy thứ tự (phải nhớ khi sửa)**: `permit_mynetworks` đứng trước `reject_unauth_destination` và
trước `check_policy_service`. Nếu `mynetworks` còn chứa dải lab thì **SPF không bao giờ được gọi** —
máy vẫn "chạy bình thường" nhưng lớp SPF vô hình. Chạy lại `d01-close-relay.sh` sau `d03` sẽ xoá mất
`check_policy_service` (trong script đã ghi chú cảnh báo này).

**master.cf** — hai chỗ phải có:

```
policyd-spf  unix  -  n  n  -  0  spawn
    user=policyd-spf argv=/usr/bin/policyd-spf

submission inet n  -  y  -  -  smtpd
  -o smtpd_milters=inet:localhost:8891        # chi ky, KHONG thu dem DMARC o cong day thu
```

Dòng override `submission` là phát hiện của bước kiểm chứng: nếu `RejectFailures true` áp cho cả
cổng 587, người dùng hợp lệ gửi từ `10.30.0.50` sẽ bị **chính MTA của tổ chức mình** chặn
(`550 5.7.1 rejected by DMARC policy`) vì IP máy trạm không nằm trong `v=spf1 ip4:10.30.0.20 mx -all`.

---

## 4. Dovecot — MDA + IMAP + SASL

```
mail_location            = maildir:~/Maildir
ssl                      = required
ssl_cert                 = </etc/ssl/certs/lab-mail.crt
ssl_key                  = </etc/ssl/private/lab-mail.key
ssl_min_protocol         = TLSv1.2
disable_plaintext_auth   = yes
# socket SASL cho Postfix cong 587:
unix_listener /var/spool/postfix/private/auth { mode = 0660 user = postfix group = postfix }
```

**Drop-in đặt tên `99-z-tls.conf`**, không phải `99-lab-tls.conf`: `conf.d` được nạp theo thứ tự ASCII
và `.` (0x2E) > `-` (0x2D), nên tên cũ bị `99-lab.conf` ghi đè ngược. Đây là lỗi làm `ssl = required`
không có hiệu lực suốt một vòng debug.

**Kiểm**: phải dùng `doveconf -a` (toàn bộ cấu hình đang chạy), **không dùng `doveconf -n`** — vì
`ssl = yes` trùng giá trị mặc định của gói nên `-n` ẩn đi, dễ kết luận sai là "chưa bật".

---

## 5. Bộ ba xác thực

### 5.1 SPF — `postfix-policyd-spf-python` (`/etc/postfix-policyd-spf-python/policyd-spf.conf`)

```
TestOnly            = 1     # 1 = THUC THI (chan thu); 0 = chi ghi header — NGUOC ten goi
Mail_From_reject    = Fail
HELO_reject         = Fail
PermError_reject    = False
TempError_Defer     = False
skip_addresses      = 127.0.0.0/8,::ffff:127.0.0.0/104,::1
debugLevel          = 1
```

`TestOnly` là tham số dễ sai nhất toàn bộ đề tài: trang man ghi *"set TestOnly = 0. If you want test
operation with no header added"* → **`1` mới là chế độ chặn**. Mã từ chối khi fail: `550 5.7.23`.

### 5.2 DKIM — OpenDKIM (`/etc/opendkim.conf`)

```
Mode                sv
Socket              inet:8891@localhost
Domain              congtyA.test
Selector            mail
KeyFile             /etc/dkimkeys/mail.private
Canonicalization    relaxed/simple
OversignHeaders     From
InternalHosts       /etc/opendkim/InternalHosts
Syslog yes / SyslogSuccess yes / UMask 007 / UserID opendkim
```

Sinh khoá: `opendkim-genkey -b 2048 -d congtyA.test -s mail -D /etc/dkimkeys -r -a`
→ `mail.private` (chỉ `opendkim` đọc) + `mail.txt` (nối vào vùng DNS).

Hai chỗ hay sai:
- Tên khoá là **`InternalHosts`**, không phải `TrustedHosts` (`TrustedHosts` không tồn tại trong OpenDKIM).
- Dòng `Socket` trong file gói **dùng TAB**, nên `sed` theo khoảng trắng âm thầm không khớp →
  opendkim vẫn listen unix socket, postfix connecting vô ích. Script `d04a` dùng
  `sed -E 's|^Socket[[:space:]]+.*|Socket  inet:8891@localhost|'` kèm nhánh `grep -q || printf >>`.

`InternalHosts` gồm: loopback, chính MTA, và `10.30.0.50/32` (máy client hợp lệ).

### 5.3 DMARC — OpenDMARC (`/etc/opendmarc.conf`)

```
Socket              inet:8893@localhost
AuthservID          mail1.congtyA.test        (M2: mail2.congtyB.test)
TrustedAuthservIDs  mail1.congtyA.test
RejectFailures      true                      # mac dinh cua goi = false
Syslog true / UMask 0002 / UserID opendmarc
PidFile /run/opendmarc/opendmarc.pid
PublicSuffixList /usr/share/publicsuffix/public_suffix_list.dat
```

`opendmarc.conf` **không có sẵn dòng `Socket`** → phải `printf >>` chứ `sed` một mình không thêm được.

**Thứ tự milter là bắt buộc**: 8891 (DKIM) trước 8893 (DMARC). Đảo vị trí thì `dmarc=` vĩnh viễn
`none`, vì OpenDMARC đọc kết quả DKIM từ private context của cùng message.

---

## 6. Kịch bản demo 15 phút (6 cảnh)

Chuẩn bị: bật 5 VM ở snapshot **`G3-phong-thu`**, mở 3 cửa sổ terminal (`M2`, `A`, `C`) + 1 cửa sổ
Windows. Mỗi cảnh nói trước 1 câu, gõ lệnh, chỉ vào kết quả, rồi chuyển cảnh.

| # | Cảnh | Máy · Lệnh | Phải thấy | Câu nói |
|---|---|---|---|---|
| 0 | Giới thiệu topo | Windows · `vmrun list` | 5 VM đang chạy | "Hai tổ chức email độc lập, một DNS, một máy tấn công, tất cả trong VMnet2 host-only." |
| 1 | Danh tính đã công bố | `M2` · `bash /root/lab/verify/v01-dns-records.sh` | `6/6 PASS` + 2 dòng `REFUSED` | "SPF, DKIM, DMARC của cả hai miền đều đã publish; DNS từ chối đệ quy nên không có đường ra ngoài." |
| 2 | Chặn relay | `A` · `nmap -p25 --script smtp-open-relay 10.30.0.20 10.30.0.30` | `Server isn't an open relay, authentication needed` | "Trước đây dòng này là `open relay (16/16 tests)`. Chỉ cần thu hẹp `mynetworks`." |
| 3 | Chặn giả mạo | `A` · `bash /root/lab/verify/v03-replay-attacks.sh` | bảng `BANG TOM TAT`: T1 `554`, T2/T3/T4 `550`, T5 `250` → `5/5 KHOP` | "Đây là đúng 5 tấn công đã đánh thành công ở Giai đoạn 2. T2/T3 chết vì SPF, T4 chết vì DMARC alignment dù SPF của darkside.test hợp lệ — đó là lý do cần DMARC." |
| 4 | Không chặn nhầm | `C` · `bash /root/lab/verify/v02-happy-path.sh` | `235 Authentication successful` → `250 2.0.0 Ok: queued as …` | "Người dùng thật vẫn gửi được ở cả hai chiều. Chính sách chặn đúng đối tượng, không chặn bừa." |
| 5 | Đọc header xác thực | `M2` · `bash /root/lab/verify/v05-auth-results.sh ketoan` | `Received-SPF: Pass … client-ip=10.30.0.20` + `dmarc=pass (p=reject dis=none)` | "Máy chủ nhận tự ghi verdict vào header. DMARC pass ở đây nhờ SPF alignment." |
| 6 | Chống hạ cấp | `C` · `bash /root/lab/verify/v04-tls-and-downgrade.sh` | `Verify return code: 0 (ok)`, `530 Must issue a STARTTLS command first`, downgrade `exit code = 28` | "AUTH ngoài TLS bị từ chối; khi proxy ẩn STARTTLS thì phiên **chết** thay vì âm thầm gửi bản rõ như ở AT-06." |

**Điểm nhấn nên nói** (giáo viên hay hỏi):
- So sánh cạnh nhau: `evidence/atk/at04-spoof.log` (trước: `queued as 745AE103489`) và T2 sau: `550 5.7.23`.
- Ba bộ đếm `Authentication-Results` / `Received-SPF` / `DKIM-Signature` **= 0** trong thư giả mạo ở Giai đoạn 2.
- Proxy MitM log: `[STRIP]` + `[AUTH-THIEP] PASSWORD = 'Lab@2026'` + `[TAMPER] … 608 byte` → nạn nhân nhận số tài khoản đã bị đổi.

**Nếu demo bị lỗi giữa chừng**: `vmrun revertToSnapshot <vmx> "G3-phong-thu"` cho máy liên quan rồi
`vmrun start <vmx> nogui` — nhanh hơn nhiều so với chạy lại script.

---

## 7. Lỗi thực tế đã gặp → nguyên nhân → cách sửa (đọc trước khi đổi cấu hình)

| # | Hiện tượng | Nguyên nhân thật | Cách sửa |
|---|---|---|---|
| 1 | `curl: (22) 404` khi tải chứng chỉ CA | `hostname -f` trả `vm-mail1` (không có domain) nên URL sai | lấy tên từ `postconf -h myhostname`, kèm guard `case "$HOST" in *.*.test)` |
| 2 | `ssl = required` không có hiệu lực | tên drop-in `99-lab-tls.conf` bị `99-lab.conf` nạp **sau** ghi đè (ASCII `.` > `-`) | đổi tên thành `99-z-tls.conf` |
| 3 | Kiểm tra TLS báo "chưa bật" dù đã bật | dùng `doveconf -n` — nó ẩn tham số trùng mặc định của gói | dùng `doveconf -a` |
| 4 | `ncat: command not found` trên M1/M2/C | ncat chỉ có ở vm-atk | viết `verify/smtp-probe.py` (chỉ cần python3) |
| 5 | Evidence không có dòng `smtpd_tls_*` | regex `^smtp(_d)?_tls` không bao giờ khớp `smtpd_tls_` | sửa thành `^smtpd?_tls` |
| 6 | `policyd-spf --version` treo vô hạn | không có option `--version`; daemon đọc stdin và chờ | dùng `dpkg-query -W -f='...${Version}'` |
| 7 | OpenDKIM listen unix socket dù đã `sed` | dòng `Socket` dùng **TAB** | `sed -E 's|^Socket[[:space:]]+.*|…|'` + nhánh `grep -q … || printf >>` |
| 8 | `v03` trả toàn bộ `000` | swaks gắn lời hồi bằng TLS có prefix `<~` / `<~*`, regex cũ chỉ nhận `<-` | regex `'<[-~*]+[[:space:]]+[45][0-9]{2}'` + thêm `--tls-optional` cho T1–T4 |
| 9 | Thư hợp lệ bị `550 rejected by DMARC` | DMARC áp lên cả cổng submission 587 | override `-o smtpd_milters=inet:localhost:8891` cho `submission` |
| 10 | T3 thành `250` sau khi chụp ảnh | chạy lại `d01` làm mất `check_policy_service` | chạy lại `d03` trên cả hai MTA; thêm cảnh báo thứ tự vào đầu `d01` |
| 11 | `mutt` báo `Encrypted connection unavailable` | `ssl_force_tls` mặc định **yes** trong mutt 2.x | `mutt -e 'set ssl_force_tls=no' …`; biến đúng tên là `ssl_starttls` (không phải `ssl_start_tls`) |
| 12 | `mutt` ẩn `Reply-To` và `X-Lab-Mark` | `/etc/Muttrc` của Ubuntu có sẵn `ignore *` | thêm `-e 'unignore reply-to: x-lab-mark:'` |
| 13 | Script báo `set: pipefail: invalid option name` | file bị lưu CRLF từ Windows | chuẩn hoá toàn bộ repo sang LF |

---

## 8. Hướng phát triển tiếp (nếu muốn "nâng cấp đề tài")

1. **Làm `dkim=pass` thành thật** — hiện header ghi `dkim=fail reason="key not found in DNS"` vì
   OpenDKIM liên kết `libunbound.so.8` và tự phân giải **đệ quy lặp từ root**, không đọc
   `/etc/resolv.conf`; trong mạng host-only với TLD `.test` thì không có đường nào tới
   `10.30.0.10` (đã xác nhận bằng `tcpdump port 53`: **0 gói tin**). Cách sửa đúng:
   - bật `recursion yes; allow-recursion { 10.30.0.0/24; }; dnssec-validation no;` trên BIND, **hoặc**
   - cài `unbound` làm resolver đệ quy nội bộ ở `127.0.0.53` rồi trỏ `ResolverConfiguration` của
     OpenDKIM vào đó (kèm `val-permissive-mode: yes` vì `.test` không có DNSSEC).
   Sau đó chạy lại `verify/v05-auth-results.sh` để thấy `dkim=pass`.
2. **MTA-STS (RFC 8461)**: thêm `_mtasts` + host `mta-sts.congtyA.test` chạy HTTPS phục vụ
   `/.well-known/mta-sts.txt` (`mode = enforce`), rồi đo lại AT-06 — khi đó kể cả MTA chưa cấu hình
   `encrypt` cũng buộc phải TLS.
3. **DANE/TLSA (RFC 7672)**: cần bật DNSSEC thật cho vùng (`dnssec-signzone`) rồi thêm bản ghi
   `_25._tcp.mail1.congtyA.test TLSA …`.
4. **Khai thác báo cáo DMARC**: `rua` đã trỏ đúng và alias `dmarc-reports` đã tồn tại
   (`defense/d00-aliases.sh`); việc còn lại là viết script giải nén `rua.xml.gz` và dựng bảng
   "số thư bị chặn theo ngày/theo nguồn".
5. **Bổ sung lớp lọc**: `postgrey` (greylisting), `spamassassin` (chấm điểm nội dung), `clamav-milter`
   (quét tệp đính kèm) — thứ tự milter gợi ý: 8891 → 8893 → spamassassin → clamav.
6. **ARC** cho chuỗi forward, **BIMI** cho logo đã xác thực.
7. **CI hoá**: chạy `verify/v01…v05` tự động sau mỗi lần đổi cấu hình và so với `evidence/` chuẩn
   (đã có `evidence-checksums.txt` làm mốc).

---

## 9. Lệnh tra nhanh khi cần

```bash
# cau hinh dang thyc chay (khong phai dang trong file)
postconf -n                       ; doveconf -a | head -40
grep -vE '^\s*#|^\s*$' /etc/opendkim.conf
grep -vE '^\s*#|^\s*$' /etc/opendmarc.conf
grep -vE '^\s*#|^\s*$' /etc/postfix-policyd-spf-python/policyd-spf.conf

# dich vu + cong
systemctl is-active postfix dovecot opendkim opendmarc
ss -lntup | grep -E ':25|:587|:143|:993|:8891|:8893'

# kiem tra chu ky / khoa
opendkim-testkey -d congtyA.test -s mail -vvv
dig @10.30.0.10 mail._domainkey.congtyA.test TXT +short
python3 /root/lab/verify/dkim-check.py $(ls -t /home/ketoan/Maildir/new/* | head -1)

# log that khi bi chan
tail -n 200 /var/log/mail.log | grep -E 'policyd-spf|opendmarc|reject|TLS'
```

*Toàn bộ giá trị trong tài liệu này được trích từ máy ảo đang chạy và từ `evidence/` (SHA-256 trong
`evidence/evidence-checksums.txt`), không có giá trị nào ước lượng.*

---

## 10. Bản ghi hình đã quay (phiên 20/10/2026 UTC)

Ba file trong `video/`, quay 1920x1080, bố cục **5 cửa sổ SSH chia lưới cùng lúc**
(hàng trên: `vm-dns | vm-mail1 | vm-mail2`; hàng dưới: `vm-atk | vm-client`):

| File | Thời lượng | Nội dung |
|---|---|---|
| `Hoi1-tan-cong-h264.mp4` | 10,9 phút | at01 open relay (16/16) → at02 nghe lén (tcpdump trên mail1 + swaks trên client, `STARTTLS = 0`) → at03 cướp credential (`235 successful`) → at04 giả mạo (`queued as 5F2311033FB`, `delivered to maildir`, 3 bộ đếm header = 0) → d02b `may` → at06 hạ cấp (`exit 0`, `[STRIP]/[AUTH-THIEP]/[TAMPER] 608 byte`, nạn nhân chỉ còn `1029384756`) |
| `Hoi2-phong-thu-h264.mp4` | 14,9 phút | d01 alpha+beta → d02b encrypt trên cả hai → d03 alpha+beta → d03b publish SPF → d04a alpha+beta → d04b publish (dán bản ghi 393 ký tự cho cả hai miền) → d05a → d05b alpha+beta. Kết quả chốt: `tls=encrypt`, `auth_only=yes`, `milters=[8891, 8893]`, `RejectFailures true`, override `submission`, bốn dịch vụ `active` |
| `Hoi3-tan-cong-lai-h264.mp4` | 6,8 phút | **dùng lại đúng lệnh hồi 1**: at01 → `isn't an open relay`; at04 → `530 Must issue a STARTTLS command first`; at06 → `exit code = 28`; v03 → **5/5 KHOP**; v02 → `queued as 61714A1D4B`; v05 → `dmarc=pass (p=reject dis=none)` + `Received-SPF: Pass` + có `DKIM-Signature` |

Bản gốc `*.mp4` (mpeg-4 part 2, ~1,2 GB) vẫn nằm cạnh file H.264 nếu cần re-encode ở bitrate cao hơn.

**Vài điểm rút ra trong lúc quay, nên đọc trước khi quay lại:**

* OBS 32.2 trên máy này bị **màn hình đen** với `monitor_capture` (cần `monitor_id` dạng đường dẫn
  thiết bị, không đặt được qua obs-websocket). Bộ ghi `scratch/quay.py` (GDI `ImageGrab`, 12–15 fps)
  cho kết quả ổn định; `scratch/tile.ps1` xếp lại lưới cửa sổ, `scratch/term.ps1` mở từng terminal.
* Snapshot `G1-mail-tran` **lấy trước khi** nạp khoá SSH vào `/root/.ssh` và trước nhiều bản sửa lỗi
  script → phải cài lại khoá (qua `ubuntu` + `sudo`) và đồng bộ lại `/root/lab` từ repo trước khi quay.
* `at02-cleartext-sniff.sh` gọi `swaks` trên vm-mail1, nhưng `swaks` chỉ cài ở vm-atk/vm-client.
  Cảnh nghe lén trong video vì thế chạy tay: `tcpdump` ở mail1 + `swaks` ở client — trực quan hơn.
* Sau khi bật `smtpd_tls_security_level = encrypt`, kịch bản at04 chết **sớm hơn** SPF: server trả
  `530 Must issue a STARTTLS command first` ngay tại `MAIL FROM`. Muốn thấy mã `550 5.7.23` của SPF
  hoặc `550 5.7.1` của DMARC thì dùng `verify/v03-replay-attacks.sh` (lệnh có `--tls-optional`).
* Máy không có NTP (mạng cô lập) nên đồng hồ khách đóng băng theo snapshot — đã chỉnh tay bằng
  `date -u -s` ngay trên camera.
