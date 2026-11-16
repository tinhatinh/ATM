# 09 · Làm lab từng bước: tấn công → vá → tấn công lại

> **Trạng thái hiện tại của phòng thí nghiệm** (đã kiểm tra ngày 20/10/2026 20:49 UTC):
> 5 máy đang chạy ở snapshot `G1-mail-tran`; `mynetworks` cả hai MTA còn chứa `10.30.0.0/24`;
> `smtpd_tls_security_level = none`; `smtpd_milters` rỗng; DNS **chưa** có bản ghi SPF/DKIM/DMARC.
> Khoá SSH của máy Windows đã được nạp vào `/root/.ssh/authorized_keys` trên cả 5 máy, và
> `/root/lab` đã được đồng bộ lại bằng bản script đã sửa (md5 khớp repository).

Mỗi lab dưới đây gồm **3 bước cố định**: (1) tấn công và ghi lại kết quả, (2) vá đúng lỗ hổng đó,
(3) chạy lại **đúng lệnh cũ** và chỉ ra sự khác biệt. Đừng bỏ bước 3 — đó là phần được chấm.

---

## 0. Chuẩn bị màn hình

Mở 5 cửa sổ SSH, mỗi cửa sổ một máy (mặc định đăng nhập thẳng root bằng khoá):

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\term.ps1 -Ip 10.30.0.10 -Label D
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\term.ps1 -Ip 10.30.0.20 -Label M1
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\term.ps1 -Ip 10.30.0.30 -Label M2
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\term.ps1 -Ip 10.30.0.40 -Label A
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\term.ps1 -Ip 10.30.0.50 -Label C
powershell -NoProfile -ExecutionPolicy Bypass -File scratch\tile.ps1 -Mode 5
```

Quy ước viết tắt trong tài liệu này: **D** = vm-dns, **M1** = vm-mail1 (Alpha), **M2** = vm-mail2
(Beta), **A** = vm-atk (tấn công), **C** = vm-client (nạn nhân). Mỗi máy ảo cũng có console riêng
trong VMware nếu bạn muốn gõ trực tiếp: đăng nhập `ubuntu` / mật khẩu `123`, rồi `sudo -i`.

Kiểm tra nhanh trước khi bắt đầu (chạy ở **C**):

```bash
bash /root/lab/verify/v00-preflight.sh
```

Phải thấy: 5 IP sống; cổng 53 ở D; 25/587/143 ở M1 và M2; `SPF/DMARC/DKIM : (khong co)`.

**Bốn điều đã biết trước, đừng mất thời gian debug:**

1. `swaks` chỉ cài ở **A** và **C**, không có ở M1/M2.
2. Sau khi revert, đồng hồ máy khách có thể lệch vài ngày (mạng cô lập, không NTP). Chỉnh bằng
   `date -u -s 'YYYY-MM-DD HH:MM:SS'` — lệch nhiều làm chứng chỉ TLS bị báo *not yet valid*.
3. **Thứ tự vá là bắt buộc**: `d01` đặt lại toàn bộ danh sách restriction, nên chạy `d01` **sau**
   `d03` sẽ xoá mất `check_policy_service` và SPF tê liệt. Tài liệu này đi theo đúng thứ tự an toàn.
4. **Mã `530` che lấp các verdict phía sau.** Khi `smtpd_tls_security_level = encrypt`, mọi phiên
   bản rõ bị từ chối ngay tại `MAIL FROM` bằng `530 Must issue a STARTTLS command first`, nên không
   bao giờ tới bước đánh giá SPF/DMARC. Muốn thấy `550 5.7.23` (SPF) hay
   `550 5.7.1 rejected by DMARC policy`, lệnh gửi phải có `--tls-optional` —
   `verify/v03-replay-attacks.sh` đã làm sẵn việc này, còn một số script trong `attacks/` thì không.

---

## LAB 1 — Open relay: máy chủ biến thành trạm phát thư rác

### 1.1 Tấn công (A)

```bash
bash /root/lab/attacks/at01-open-relay.sh
```

**Phải thấy** (mất ~40 giây):

```
|_smtp-open-relay: Server is an open relay (16/16 tests)
...
<-  250 2.1.5 Ok          <- RCPT TO:<nguoidung@khong-phai-domain-lab.test>
<-  252 2.0.0 giamdoc     <- VRFY giamdoc
```

Ba thông tin rút ra: máy chủ nhận chuyển tiếp thư cho tên miền thứ ba; `VRFY` bật cho phép liệt kê
tài khoản; chuỗi chào `220 ... ESMTP Postfix (Ubuntu)` lộ cả tên và phiên bản phần mềm.

### 1.2 Vá (M1 rồi M2)

```bash
bash /root/lab/defense/d01-close-relay.sh alpha     # trên M1
bash /root/lab/defense/d01-close-relay.sh beta      # trên M2
```

Kiểm tra trên **M1** hoặc **M2**:

```bash
postconf -n | grep -E 'mynetworks|relay_restrictions|recipient_restrictions|helo_required|vrfy'
```

Phải thấy `mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128` (**không còn** `10.30.0.0/24`),
`smtpd_helo_required = yes`, `disable_vrfy_command = yes`.

### 1.3 Tấn công lại (A)

```bash
bash /root/lab/attacks/at01-open-relay.sh
```

**Kết quả mới**: `Server isn't an open relay, authentication needed` và `RCPT TO:` bị
`554 5.7.1 <...>: Relay access denied`. Cùng một lệnh, kết luận đảo ngược.

> **Giải thích để trình bày**: `smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated,
> reject_unauth_destination`. Trước khi vá, mọi máy trong `10.30.0.0/24` khớp `permit_mynetworks`
> nên chuỗi dừng ở "cho phép". Sau khi thu hẹp `mynetworks` về loopback, lời gọi từ A rơi tới
> `reject_unauth_destination` và bị chặn ngay tại `RCPT` — thư không bao giờ vào hàng đợi.

---

## LAB 2 — Giả mạo người gửi (spoofing) và BEC

Làm lab này **trước khi bật TLS bắt buộc**, để nhìn thấy rõ mã từ chối của SPF trên cổng 25.

### 2.1 Tấn công (A)

```bash
bash /root/lab/attacks/at04-spoof-header.sh     # gia mao admin@congtyA.test -> ketoan@congtyB.test
bash /root/lab/attacks/at05-spoof-own-domain.sh # gia mao ngay trong cung mien Alpha
```

**Phải thấy**: `250 2.0.0 Ok: queued as <ID>` cho cả hai.

Xem góc nhìn nạn nhân (M2):

```bash
bash /root/lab/attacks/at04-check-inbox.sh ketoan
```

Ba bộ đếm `Authentication-Results`, `Received-SPF`, `DKIM-Signature` đều **0**, kèm dòng:

```
From:     Admin <admin@congtyA.test>
Reply-To: "Admin" <attacker@darkside.test>
Received: from mail1.congtyA.test (atk.darkside.test [10.30.0.40])
```

Tên máy chủ gửi là **giả** (kẻ tấn công khai `EHLO mail1.congtyA.test`), chỉ địa chỉ IP là thật.

### 2.2 Vá bằng SPF (M1, M2 rồi D)

```bash
bash /root/lab/defense/d03-spf-enforce.sh alpha    # M1
bash /root/lab/defense/d03-spf-enforce.sh beta     # M2
bash /root/lab/defense/d03b-spf-publish.sh         # D  (cong bo ban ghi TXT)
```

Trên **D** kiểm tra:

```bash
dig @10.30.0.10 congtyA.test TXT +short
dig @10.30.0.10 congtyB.test TXT +short
```

Phải thấy `"v=spf1 ip4:10.30.0.20 mx -all"` và `"v=spf1 ip4:10.30.0.30 mx -all"`.

Trên **M2** kiểm tra bộ lọc đã nằm trong chuỗi:

```bash
postconf -h smtpd_recipient_restrictions | tr ',' '\n' | grep -n .
grep -vE '^\s*#|^\s*$' /etc/postfix-policyd-spf-python/policyd-spf.conf
```

`check_policy_service unix:private/policyd-spf` phải xuất hiện **sau** `reject_unauth_destination`,
và `TestOnly = 1` (**1 mới là chế độ chặn** — tên dễ gây hiểu ngược).

### 2.3 Tấn công lại (A)

```bash
bash /root/lab/attacks/at04-spoof-header.sh
bash /root/lab/attacks/at05-spoof-own-domain.sh
```

**Kết quả mới**: `550 5.7.23 <ketoan@congtyB.test>: Recipient address rejected: Message rejected
due to: SPF fail - not authorized`. Chạy lại `at04-check-inbox.sh ketoan` trên M2: **không có** thư
mới trong hộp thư — bị chặn ngay tại `RCPT`, trước khi bức thư kịp vào hàng đợi.

> **Caveat để trả lời vấn đáp**: SPF chỉ kiểm tra *envelope sender*. Nếu đối thủ gửi từ một tên
> miền **khác** có SPF đúng của chính nó rồi đặt `Header From` là `congtyA.test`, SPF không phát
> hiện được. Đó là nội dung LAB 7.

---

## LAB 3 — Nghe lén nội dung thư trên kênh bản rõ

### 3.1 Tấn công (hai cửa sổ phối hợp)

Ở **M1**, bật bắt gói trước:

```bash
tcpdump -i any -nn -s0 -A tcp port 25 > /root/evidence/mail1/at02-cleartext.txt 2>/dev/null &
```

Ở **C**, gửi một bức thư có nội dung nhạy cảm:

```bash
swaks --to ketoan@congtyB.test --from giamdoc@congtyA.test --server mail1.congtyA.test \
      --header 'Subject: Hop ban so luat - tai lieu kem theo' \
      --body 'Ket noi ho so va tai khoan ngan hang: 1029384756 - AlphaBank.'
```

Ở **M1**, dừng bắt gói và đọc:

```bash
sleep 2; pkill -f 'tcpdump -i any'; sleep 1
grep -aE 'MAIL FROM|RCPT TO|Subject:|1029384756' /root/evidence/mail1/at02-cleartext.txt | head -6
echo -n 'so dong chua STARTTLS = '; grep -ac STARTTLS /root/evidence/mail1/at02-cleartext.txt
```

**Phải thấy** nội dung đọc được bằng mắt thường và `so dong chua STARTTLS = 0`.

### 3.2 Vá: dựng CA riêng rồi bật STARTTLS (D rồi M1, M2)

```bash
bash /root/lab/defense/d02a-ca.sh                 # D   (mo HTTP :8080 phat chung chi)
bash /root/lab/defense/d02b-tls.sh may            # M1
bash /root/lab/defense/d02b-tls.sh may            # M2
```

Trên **M1** kiểm tra:

```bash
postconf -h smtpd_tls_security_level     # -> may
openssl x509 -in /etc/ssl/certs/lab-mail.crt -noout -subject -issuer -ext subjectAltName
```

### 3.3 Tấn công lại (lặp lại 3.1)

Bắt gói lại ở M1, gửi lại thư ở C, rồi:

```bash
grep -ac 'Application data\|TLS\|handshake' /root/evidence/mail1/at02-cleartext.txt
grep -a 'Subject:' /root/evidence/mail1/at02-cleartext.txt || echo "KHONG CON DOC DUOC Subject"
```

**Kết quả mới**: không còn dòng `Subject:`/`MAIL FROM` nào đọc được; chỉ còn dữ liệu TLS đã mã hoá.

> **Nhưng chưa an toàn tuyệt đối**: `may` là *opportunistic* — máy chủ **có** quảng bá STARTTLS
> nhưng nếu quảng bá đó bị chặn mất trên đường truyền, client vẫn gửi bản rõ. LAB 5 chứng minh.

---

## LAB 4 — Đánh cắp thông tin đăng nhập

### 4.1 Tấn công (C)

```bash
bash /root/lab/attacks/at03-credential-theft.sh
```

**Phải thấy**: `250-AUTH PLAIN LOGIN` trên kênh chưa mã hoá; hai chuỗi `Z2lhbWRvYw==` và
`TGFiQDIwMjY=` giải mã ra `giamdoc` / `Lab@2026`; máy chủ đáp `235 2.7.0 Authentication successful`.

### 4.2 Vá: bắt buộc TLS và tắt AUTH ngoài TLS (M1, M2)

```bash
bash /root/lab/defense/d02b-tls.sh encrypt        # M1
bash /root/lab/defense/d02b-tls.sh encrypt        # M2
```

Kiểm tra trên **M2**:

```bash
postconf -h smtpd_tls_security_level smtpd_tls_auth_only smtp_tls_security_level
printf 'EHLO test\nQUIT\n' | python3 /root/lab/verify/smtp-probe.py 127.0.0.1 25 | grep -E 'AUTH|STARTTLS'
```

Phải thấy `encrypt`, `yes`, `verify`; và danh sách `EHLO` **mất dòng `250-AUTH`**, còn `250-STARTTLS`.

### 4.3 Tấn công lại (C)

```bash
bash /root/lab/attacks/at03-credential-theft.sh
```

**Kết quả mới**: `530 5.7.0 Must issue a STARTTLS command first` — không còn cơ hội lấy credential.

---

## LAB 5 — Hạ cấp STARTTLS và sửa nội dung trên đường truyền

Đây là lab chứng minh `may` **không đủ**. Máy chủ đang ở chế độ `encrypt` từ LAB 4, nên trước tiên
hạ về `may` để tái hiện đúng điều kiện tấn công:

```bash
bash /root/lab/defense/d02b-tls.sh may            # M1  (tam thoi de dien tai xuong)
```

### 5.1 Tấn công

Ở **A**, dựng proxy người ở giữa:

```bash
bash /root/lab/attacks/atk-run-strip-proxy.sh start
```

Ở **C**, gửi thư qua proxy:

```bash
bash /root/lab/attacks/at06-starttls-strip.sh
```

Ở **A**, xem nhật ký proxy:

```bash
bash /root/lab/attacks/atk-run-strip-proxy.sh show
```

**Phải thấy** ba nhóm hành vi:

```
[STRIP] AN DONG NAY KHONG cho khach thay: 250-STARTTLS
[AUTH-THIEP] USERNAME = 'giamdoc'  (base64: Z2lhbWRvYw==)
[AUTH-THIEP] PASSWORD = 'Lab@2026'  (base64: TGFiQDIwMjY=)
[TAMPER] da thay '9999999999' -> '1029384756' trong than thu (608 byte)
```

và ở **C**: `swaks exit code = 0` (phiên vẫn thành công!). Ở **M2**:
`bash /root/lab/attacks/at04-check-inbox.sh ketoan` → bức thư `X-Lab-Mark: AT-06-STRIPPED` **chỉ còn**
số tài khoản của kẻ tấn công.

### 5.2 Vá

```bash
bash /root/lab/attacks/atk-run-strip-proxy.sh stop        # A
bash /root/lab/defense/d02b-tls.sh encrypt                # M1
bash /root/lab/defense/d02b-tls.sh encrypt                # M2
```

### 5.3 Tấn công lại

Bật proxy ở A, chạy lại `at06-starttls-strip.sh` ở C.

**Kết quả mới**: `swaks exit code = 28` — client không thấy STARTTLS, và vì máy chủ **bắt buộc**
TLS nên phiên bị huỷ thay vì âm thầm hạ cấp. Không có thư nào vào hộp nạn nhân.

> **Giới hạn cần nói thẳng**: cách này chỉ buộc được các MTA mà ta đã cấu hình. Trên Internet thật,
> chuẩn đóng lỗ hổng này là **MTA-STS (RFC 8461)** và **DANE/TLSA (RFC 7672)**.

---

## LAB 6 — DKIM: ký và kiểm tra toàn vẹn nội dung

### 6.1 Sinh khoá và bật bộ ký (M1)

```bash
bash /root/lab/defense/d04a-dkim.sh alpha
grep -vE '^\s*#|^\s*$' /etc/opendkim.conf
ls -l /etc/dkimkeys/
cat /etc/dkimkeys/mail.txt          # giu lai noi dung nay de dan len DNS
```

### 6.2 Công bố khoá công khai lên DNS (D)

```bash
bash /root/lab/defense/d04b-dkim-publish.sh alpha
```

Script sẽ chờ bạn **dán toàn bộ nội dung `mail.txt`** lấy ở bước 6.1, nhấn Enter rồi **Ctrl-D**.
Kiểm tra:

```bash
dig @10.30.0.10 mail._domainkey.congtyA.test TXT +short
```

Lặp lại cho Beta: `d04a-dkim.sh beta` trên **M2** rồi `d04b-dkim-publish.sh beta` trên **D**.

### 6.3 Chứng minh chữ ký có tác dụng

Gửi một bức thư hợp lệ (C):

```bash
bash /root/lab/verify/v02-happy-path.sh
```

Ở **M2**, lấy bức thư mới nhất và kiểm chữ ký bằng công cụ độc lập:

```bash
F=$(ls -t /home/ketoan/Maildir/new/* | head -1)
grep -aE '^DKIM-Signature|^bh=' "$F" | cut -c1-140
python3 /root/lab/verify/dkim-check.py "$F"
```

**Phải thấy**: `bh` tính lại khớp tuyệt đối với `bh` trong header, và `openssl verify: Verified OK`.
Chỉ cần tự tay sửa một ký tự trong thân thư rồi chạy lại `dkim-check.py` → chữ ký **fail**, đó là
toàn vẹn nội dung.

> **Giới hạn của môi trường cô lập**: header máy nhận ghi `dkim=fail reason="key not found in DNS"`.
> Nguyên nhân không phải chữ ký sai, mà vì OpenDKIM liên kết `libunbound` và tự phân giải **đệ quy
> lặp từ root server**, không dùng `/etc/resolv.conf`; mạng host-only không có đường ra Internet và
> `.test` là TLD dự phòng theo RFC 6761. Kiểm chứng bằng `dig @10.30.0.10 ... TXT` vẫn trả đủ bản ghi.
> Muốn `dkim=pass` thật sự: bật `recursion yes; allow-recursion { 10.30.0.0/24; };` trên BIND hoặc
> chạy một resolver đệ quy nội bộ, rồi trỏ `ResolverConfiguration` của OpenDKIM vào đó.

---

## LAB 7 — DMARC: chặn trường hợp SPF qua mặt được

### 7.1 Công bố chính sách và bật thực thi

```bash
bash /root/lab/defense/d05a-dmarc-publish.sh          # D
bash /root/lab/defense/d05b-dmarc-enforce.sh alpha    # M1
bash /root/lab/defense/d05b-dmarc-enforce.sh beta     # M2
```

Kiểm tra trên **M2**:

```bash
dig @10.30.0.10 _dmarc.congtyA.test TXT +short
postconf -h smtpd_milters                                  # -> inet:localhost:8891, inet:localhost:8893
grep -A2 '^submission' /etc/postfix/master.cf              # -> -o smtpd_milters=inet:localhost:8891
grep -E 'RejectFailures' /etc/opendmarc.conf               # -> true
```

Ba điểm phải đúng: **thứ tự milter** (8891 trước 8893), `RejectFailures true` (mặc định của gói là
`false` — chỉ đánh giá mà không chặn), và **override cho cổng submission** (nếu thiếu, DMARC chặn
nhầm cả người dùng hợp lệ gửi ở cổng 587).

### 7.2 Tấn công: SPF đúng nhưng mạo danh tên miền khác (A)

```bash
bash /root/lab/attacks/at07-spf-pass-dmarc-fail.sh
```

**Chú ý thật, không phải lỗi cấu hình**: script `at07` gửi ở cổng 25 **không kèm** `--tls-optional`.
Vì từ LAB 5 máy chủ đã đặt `smtpd_tls_security_level = encrypt`, phiên bản rõ sẽ bị chặn rất sớm
bằng `530 Must issue a STARTTLS command first` — **trước cả** bước đánh giá DMARC. Muốn thấy verdict
của DMARC thì phải cho phiên đi qua TLS trước. Hai cách:

```bash
# CACH 1 (khuyen dung): dung T4 trong bo phat lai, da co --tls-optional
bash /root/lab/verify/v03-replay-attacks.sh

# CACH 2: chay tay dung lenh cua at07 nhung them --tls-optional
swaks --server mail2.congtyB.test --port 25 --tls-optional \
      --from 'thongbao@darkside.test' --to 'ketoan@congtyB.test' --helo 'mail.darkside.test' \
      --header 'From: Giam doc Alpha <giamdoc@congtyA.test>' \
      --header 'Subject: [AT-07] SPF pass, DMARC fail' \
      --body 'SPF pass cho darkside, khong align voi Header From cua congtyA.'
```

**Kết quả phải thấy**: `550 5.7.1 rejected by DMARC policy for congtyA.test`.

Đây là bằng chứng DMARC không thể bị thay bằng SPF: kẻ tấn công gửi từ `darkside.test` với SPF đúng
của chính nó nên SPF `pass`, nhưng `Header From` là `congtyA.test` → **alignment** fail.

### 7.3 Chứng minh không chặn nhầm (C)

```bash
bash /root/lab/verify/v02-happy-path.sh
bash /root/lab/verify/v05-auth-results.sh ketoan     # chay o M2
```

**Phải thấy**: `250 2.0.0 Ok: queued as <ID>` và trong header có
`Received-SPF: Pass (mailfrom) ... client-ip=10.30.0.20` cùng
`Authentication-Results: mail2.congtyB.test; dmarc=pass (p=reject dis=none) header.from=congtyA.test`.

---

## LAB 8 — Tổng kết: phát lại toàn bộ tấn công một lượt

```bash
bash /root/lab/verify/v01-dns-records.sh        # D   -> 6/6 PASS + 2 phep thu phu dinh REFUSED
bash /root/lab/verify/v03-replay-attacks.sh     # A   -> 5/5 KHOP
bash /root/lab/verify/v04-tls-and-downgrade.sh  # C   -> Verify return code: 0 (ok) + 530 + exit 28
```

Bảng kỳ vọng của `v03`:

| Test | Tình huống | Mã phải thấy | Lớp nào chặn |
|---|---|---|---|
| T1 | Xin relay tới tên miền ngoài lab | `554 5.7.1 Relay access denied` | `reject_unauth_destination` |
| T2 | Giả `admin@congtyA.test` gửi sang Beta | `550 5.7.23 … SPF fail - not authorized` | SPF |
| T3 | Giả `postmaster@congtyA.test` gửi nội bộ | `550 5.7.23 …` | SPF |
| T4 | SPF đúng của `darkside.test`, `Header From` là Alpha | `550 5.7.1 rejected by DMARC policy` | DMARC alignment |
| T5 | **Thư hợp lệ** (đúng tài khoản + TLS, cổng 587) | `250 2.0.0 Ok: queued` | không chặn |

T5 quan trọng không kém T1–T4: nó chứng minh hệ thống chặn đúng đối tượng.

---

## Phụ lục: lệnh dọn dẹp và làm lại từ đầu

```bash
# Tat dich vu tam thoi sau khi lam xong lab
bash /root/lab/attacks/atk-run-strip-proxy.sh stop        # A
bash /root/lab/defense/d02a-ca.sh stop                    # D

# Dong toan bo bang VMware
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun" list
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun" stop "<duong-dan>\<ten>\<ten>.vmx" soft

# Quay lai diem bat dau (trang thai chua phong thu)
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun" revertToSnapshot "<duong-dan>\<ten>\<ten>.vmx" "G1-mail-tran"
```

Sau khi revert về `G1`, nếu cần dùng lại các công cụ trong repository thì phải **nạp lại khoá SSH**
và **đồng bộ lại `/root/lab`** (snapshot G1 lấy trước hai việc này):

```bash
python scratch/caikhoi-key.py                       # tai ubuntu/123, sudo -S, nap khoa vao /root/.ssh
# roi dong bo: tar lab-sync.tar.gz -> scp -> tar xzf tai /root/lab  (xem scratch/chup.sh lam mau)
```
