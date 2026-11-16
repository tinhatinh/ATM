# 06 · Ngân hàng câu hỏi vấn đáp (10–15 phút, 20% điểm)

Mỗi câu có **câu trả lời ngắn** (đúng điều nhóm đã làm — nói được bằng lời của mình, không học vẹt)
và **bằng chứng trong lab** để viện dẫn khi thầy phản hỏi.

## A. CLO1 — Kiến trúc & giao thức (cả nhóm phải trả lời được)

**1. Phân biệt MUA / MTA / MDA và giao thức ở từng chặng?**
MUA là chương trình người dùng dùng (mutt/Thunderbird) — nói chuyện với MTA bằng SMTP port 587 và
lấy thư bằng IMAP 143/993. MTA (Postfix) vận chuyển thư giữa các máy chủ, nhận ở 25, truy vấn DNS để tìm MX.
MDA (Dovecot LMTP/local) đặt thư vào hộp (`~/Maildir`). Trong lab: client→mail1 là 587, mail1→mail2 là 25,
client→mail2 đọc thư là 143/993. *(Bằng chứng: `docs/00-thiet-ke-lab.md` bảng cổng; `ss -ltnp` trong `20-mail.sh`.)*

**2. Vì sao Envelope Sender khác Header From, và đó là gốc của spoofing?**
`MAIL FROM:` thuộc SMTP (RFC 5321, dùng cho SPF và bounce), `From:` thuộc nội dung (RFC 5322, MUA hiển thị).
SMTP không buộc chứng minh quyền sở hữu địa chỉ → kẻ gửi đặt hai cái khác nhau tuỳ ý.
*(Bằng chứng: AT-04 — swaks đặt `--from admin@congtyA.test` nhưng `--header 'From: Admin <admin@congtyA.test>'`, mail2 vẫn trả 250.)*

**3. SMTP trả lời theo mã nào, ý nghĩa 250/354/451/550/554?**
2xx hoàn thành, 3xx chờ tiếp (354 = vào DATA), 4xx lỗi tạm (451 defer), 5xx lỗi vĩnh viễn.
Postfix: 554 thường là relay từ chối, 550 thường là mailbox/_policy_ từ chối (SPF trả `550 5.7.23`).

**4. DMARC "alignment" là gì, relaxed khác strict?**
So sánh domain của `Header From` với domain đã xác thực: SPF so với domain của envelope (5321.From),
DKIM so với `d=`. `aspf/adkim = r` (relaxed) chỉ cần cùng domain tổ chức (eTLD+1); `s` (strict) phải trùng tuyệt đối.
Lab dùng `adkim=r; aspf=r`. *(Bằng chứng: AT-07 — spf=pass cho darkside.test nhưng Header From là congtyA.test → dmarc=fail.)*

**5. DKIM canonicalization relaxed/simple nghĩa là gì?**
`relaxed` chuẩn hoá nhẹ phần header (bỏ khoảng trắng dư, hạ cỡ tên header) khi tính `h=`, `simple` dùng
body nguyên vẹn để tính `bh=`. Vì `bh=` là SHA-256 của body → chỉ cần sửa một ký tự trong nội dung,
`dkim` sẽ `fail`. *(Bằng chứng: `grep '^Canonicalization' /etc/opendkim.conf`; AT-06/TC14 là trường hợp CHƯA có DKIM.)*

**6. Port 25 / 465 / 587 khác nhau chỗ nào?**
25 = MTA→MTA (và bị nhiều ISP chặn với subscriber). 465 = SMTPS (wrapper TLS, deprecated rồi khôi phục
ở RFC 8314). 587 = submission cho MUA, bắt đầu bằng plaintext rồi nâng cấp STARTTLS, thường buộc SASL.
Lab dùng 587 cho client, 25 giữa hai MTA. Trong Ubuntu master.cf, 465 tên dịch vụ là `submissions` chứ không phải `smtps`.

**7. Vai trò của DNS trong định tuyến thư?**
`MX` chọn máy nhận theo preference, `A` phân giải MX host, `PTR` dùng cho kiểm tra reverse/`ptr` của SPF,
`TXT` mang SPF/DKIM/DMARC. Lab dựng BIND authoritative-only (`recursion no`) cho đúng 4 zone.

## B. CLO2 — Lỗ hổng & tấn công

**8. Open Relay là gì, hệ quả?**
MTA nhận thư có RCPT ở domain lạ và chuyển tiếp vi xem client là "trusted" (`mynetworks` quá rộng).
Hệ quả: phát tán spam, IP vào DNSBL (Spamhaus), domain bị từ chối bởi đối tác. Lab cố tình đặt
`mynetworks = 10.30.0.0/24` ở GĐ1 để nmap `smtp-open-relay` báo OPEN (TC06).

**9. Vì sao `permit_mynetworks` đặt trước `check_policy_service` làm SPF vô hiệu?**
Postfix dừng xét danh sách restrictions ngay khi gặp một điều khoản `permit`. Client trong
`mynetworks` được `permit_mynetworks` cho qua → các điều khoản sau (kể cả SPF) không chạy.
Lab sửa bằng cách siết `mynetworks` về loopback (D-01) và xếp `check_policy_service` sau
`reject_unauth_destination` (README.Debian của policyd-spf ghi rõ thứ tự này).

**10. Opportunistic TLS là gì, tại sao vẫn bị downgrade?**
`smtpd_tls_security_level = may`: server *có advertise* STARTTLS nhưng không bắt buộc. Kẻ trung gian
chỉ cần xoá dòng `250-STARTTLS` trong EHLO thì client "tốt bụng" im lặng quay về bản rõ — không có cảnh báo.
Lab tái hiện bằng proxy `strip_starttls.py` (TC13) và chế ngự bằng `encrypt` + `smtp_tls_security_level=verify` (TC19).

**11. MTA-STS và DANE giải quyết phần còn lại nào?**
Cả hai cho bên gửi biết *bên nhận yêu cầu TLS* trước khi kịp bị hạ cấp: MTA-STS qua `sts.nddm: enforce` +
well-known, DANE qua bản ghi TLSA trong zone DNSSEC. Lab nêu ở hướng mở rộng (Phần 4) vi không có DNSSEC/Internet.

**12. BEC là gì và khác phishing thông thường thế nào?**
BEC giả mạo đúng người có thẩm quyền (giám đốc, kế toán nhà) để chỉ thị chuyển khoản, không cần malware/attachment.
Trong lab AT-04/AT-05 dựng đúng kịch bản đó và đo bằng số thư lọt vào `Maildir/new` của `ketoan`.

**13. Tại sao "SPF pass" chưa đủ để an toàn?**
SPF chỉ validates *envelope* domain; kẻ tấn công dùng domain của chính mình (có SPF đúng) rồi đặt
`Header From` của nạn nhân → spf=pass nhưng hoàn toàn là thư giả. DMARC alignment mới chặn được (AT-07, R9).

**14. SPF có giới hạn nào trong thực tế?**
Forwarding làm đổi IP kết nối → fail; tối đa 10 lần tra vấn DNS (`lookup limit`); không áp dụng cho
`Header From`. Vì vậy chuẩn ngành là SPF `-all` **và** DKIM **và** DMARC.

## C. CLO3 — Cấu hình & tham số đã triển khai (thầy hay hỏi "giải thích tham số")

**15. `smtpd_relay_restrictions` khác `smtpd_recipient_restrictions`?**
Từ Postfix 2.10, quyết định relay nằm ở `smtpd_relay_restrictions` (`permit_mynetworks, permit_sasl_authenticated,
reject_unauth_destination`). `smtpd_recipient_restrictions` bổ sung xét theo người nhận và là nơi ta gắn
`check_policy_service`. Nếu khai báo relay restrictions mà không có `reject_unauth_destination` sẽ thành open relay.

**16. `mynetworks` của em là gì sau phòng thủ, vi sao?**
`127.0.0.0/8` + loopback IPv6. Không có IP máy client/attacker, vi đó là "trusted = free pass" cho mọi kiểm tra phía sau.
Đây chính là lỗi làm báo cáo mẫu không thể cho ra kết quả 550.

**17. DKIM: selector là gì, key đặt ở đâu, công khai thế nào?**
Selector `mail` → bản ghi `mail._domainkey.congtyA.test`. Private key ở `/etc/dkimkeys/mail.private`
(chmod 600, owner `opendkim`), public key do `opendkim-genkey -b 2048 -d … -s mail -D /etc/dkimkeys -r -a`
xuất ra `mail.txt`, được dán vào zone DNS (`d04b`). Kiểm tra lại bằng `opendkim-testkey -d … -s mail -vvv`.

**18. Vì dùng `inet:8891@localhost` thay vi socket local mặc định?**
Mặc định Ubuntu là `Socket local:/run/opendkim/opendkim.sock` với `UMask 007`, Postfix phải cùng nhóm
mới đọc được. Lab đổi sang `inet:8891@localhost` (đúng như comment ví dụ trong `/etc/opendkim.conf`)
cho đơn giản và để `postconf -n` in ra được chuỗi milter ai cũng đọc hiểu: `smtpd_milters=inet:localhost:8891`.

**19. Thứ tự milter: `8891` rồi `8893` — vi sao bắt buộc?**
`README.opendmarc`: "must come after filters that do DKIM and SPF evaluation" — OpenDMARC đọc kết quả
`Authentication-Results` do OpenDKIM/policyd-spf viết, nếu chạy trước thì không còn gì để xét.

**20. Công tắc nào khiến OpenDMARC thực sự từ chối thư?**
`RejectFailures true` (mặc định là `false` — chỉ đánh dấu). Không có nó thì `dmarc=fail` vẫn được phát.
Đây là điểm dễ sai nhất của toàn bài, nhóm em xác minh bằng `grep '^RejectFailures' /etc/opendmarc.conf`.

**21. `TestOnly` trong policyd-spf: 0 hay 1 mới chặn?**
`TestOnly = 1` là chế độ **thực thi** (đúng như file cấu hình mặc định của package). Đặt `TestOnly = 0`
mới là "chỉ ghi header, không chặn" — man 5 policyd-spf.conf và mã nguồn `policyd_spf.py`
(`if TestOnly == 0 and checkerValue != 'prepend': checkerValue = None`) đều nói vậy. Nhiều hướng dẫn trên
mạng bảo "đổi 0 để chặn" là ngược.

**22. Từ chối SPF trả mã gì và log ở đâu?**
`550 5.7.23` (enhanced status code, `SPF_Enhanced_Status_Codes = Yes` mặc định) — in ra ở RCPT;
`/var/log/mail.log` có dòng `policyd-spf[...]` kèm `identity=mailfrom`, `client-ip=10.30.0.40`.

**23. Start TLS ở chiều MTA→MTA: vi sao đặt `smtp_tls_security_level=verify`?**
`encrypt` phía nhận buộc phiên có TLS; `verify` phía gửi buộc chứng chỉ của bên nhận phải hợp lệ theo CA
và trùng tên. Chỉ `may` thì vẫn bị strip; `encrypt`+`verify` làm downgrade thất bại có thể chụp ảnh được (TC19).
Cần CA lab vi chứng chỉ tự ký không nằm trong bundle công cộng.

**24. Dovecot: vi sao `ssl = required` + `disable_plaintext_auth = yes`?**
Ngăn mật khẩu IMAP/SMTP AUTH đi bản rõ. Sau D-02b encrypt, thử AUTH trên port 25/143 sẽ nhận `538`/
`plaintext authentication prohibited` — nhóm em chụp ở CHỤP 38 (TC18).

## D. Câu hỏi theo từng thành viên

**Phạm Minh Thiện (MTA/MDA, Postfix+Dovecot, user/hop thu)**
1. Maildir khác mbox ở điểm nào, vi sao chọn Maildir? → ba thư mục `new/cur/tmp`, atomic rename, không khoá
   toàn hộp, `home_mailbox = Maildir/` và `mail_location = maildir:~/Maildir`.
2. Vì sao ở GĐ1 thư vẫn vào được hộp dù `mailbox_command` rỗng? → Postfix `local(8)` tự tạo Maildir theo
   `home_mailbox`; `mailbox_command` rỗng để tránh procmail chen vào.
3. SASL của Postfix lấy từ đâu? → `smtpd_sasl_type=dovecot`, `smtpd_sasl_path=private/auth`, Dovecot mở
   `unix_listener /var/spool/postfix/private/auth` (mode 0660, postfix:postfix). Không cần libsasl2-modules.
4. Muốn người dùng đổi mật khẩu/ xoá tài khoản thì làm gì? → `passwd <user>`, `userdel -r <user>`; kiểm tra
   `doveadm user <name>` và `postmap -q` với alias.

**Đỗ Hà Quân (lỗ hổng, threat model, ma trận rủi ro)**
1. Điểm L/I của em lấy từ đâu? → từ chính kết quả TC: TC06/08/09/10 thành công ở GĐ2 → L=5; sau TC20–23
   bị chặn → L giảm còn 1–2; ghi "Căn cứ đo được" từng dòng.
2. Vì sao R3 (credential theft) điểm cao nhất? → độ phức tạp khai thác gần 0 (1 lệnh tcpdump + base64 -d),
   hậu quả là chiếm mailbox + mạo danh tiếp.
3. Rủi ro nào còn lại sau phòng thủ và tại sao không thể về 0? → R4/R8 còn 8–10: DKIM/SPF không ràng buộc
   Header From (chỉ DMARC làm), forwarding làm hỏng SPF, chưa có MTA-STS/DANE, chưa có blocklist/rate-limit.
4. Nếu attacker có domain riêng và DKIM đúng của nó thì phòng tuyến nào chặn? → DMARC alignment (AT-07/TC23).

**Nghiêm Xuân Hoàng Tùng (topology + DNS)**
1. Vì sao dùng `.test` mà không phải `.lab.local`? → `.local` là vùng mDNS (RFC 6762) dễ xung đột Avahi;
   `.test` được RFC 6761 dành cho thử nghiệm, không bao giờ phân giải ra Internet.
2. BIND của em là recursive hay authoritative? → authoritative-only (`recursion no`), `allow-query 10.30.0.0/24`,
   `dnssec-validation no`; hỏi tên ngoài zone trả REFUSED — có chứng minh bằng `dig`.
3. Sửa zone xong cần làm gì để có hiệu lực? → tang serial (YYMMNN+đếm) rồi `rndc reload <zone>`; script
   `dns-add-record.sh` làm hộ cả hai bước và chạy `named-checkzone` trước.
4. Vì sao zone file để ở `/var/lib/bind`? → AppArmor của bind9 chỉ cho ghi ở đó; `/etc/bind` chỉ đọc,
   journal `.jnl` không tạo được → zone load fail.

**Phan Thành Danh (tấn công + bằng chứng)**
1. `swaks` đặt `--from` và `--header 'From:'` khác nhau chỗ nào? → `--from` là envelope MAIL FROM (SPF, bounce),
   `--header 'From: …'` là header hiển thị; lab đặt hai cái khác nhau để chứng minh.
2. Vì sao bắt gói ngay trên MTA mà không cần ARP spoof? → trong host-only, switch ảo không nhân bản traffic;
   capture ở endpoint (mail1) cho bằng chứng deterministic, còn vị trí MitM thật sự ta dựng bằng proxy 2525.
3. Proxy của em làm gì và đã kiểm chứng chưa? → ẩn `250-STARTTLS`, log AUTH (decode base64), đổi chuỗi trong body;
   đã chạy `selftest-strip-proxy.py` trên loopback, 5/5 PASS (log đính kèm).
4. Làm sao phân biệt TLS "không hoạt động" với "bị hạ cấp"? → trước phòng thủ: server không advertise (GĐ1,
   `security_level=none`); sau `may`: advertise nhưng client qua proxy không thấy → vẫn gửi được bản rõ;
   sau `encrypt`: client bị từ chối — ba trạng thái đều có pcap/log riêng.

**Trần Văn Trung (TLS/SPF/DKIM/DMARC)**
1. Sinh key DKIM bằng lệnh nào, key nằm đâu, quyền ra sao? → `opendkim-genkey -b 2048 -d congtyA.test -s mail
   -D /etc/dkimkeys -r -a`; `chown opendkim:opendkim`, `chmod 600` private, 644 public txt.
2. Vì sao `Mode sv` và `InternalHosts`? → `s` ký, `v` kiểm tra. `InternalHosts` quyết định kết nối nào được ký
   (client 10.30.0.50, MTA của lab) — không phải `TrustedHosts` (tên đó không tồn tại trong opendkim 2.11).
3. Vì sao thứ tự restrictions của SPF quan trọng hơn bản thân bản ghi SPF? → bản ghi chỉ là "luật"; nếu
   restrictions cho `permit_mynetworks` đứng trước thì luật không được thi hành. Lab cố ý dựng lỗi này ở GĐ1.
4. Kiểm tra DMARC đã thực thi ở đâu? → `grep '^RejectFailures' /etc/opendmarc.conf`, `ss -ltn | grep 8893`,
   `postconf -n | grep milters`, và đặc biệt TC23 trả `550 … DMARC policy`.

## E. Ba câu "bẫy" hay bị trừ điểm

1. **"Email của bạn vượt Gmail/Outlook không?"** → Không kiểm chứng với dịch vụ công cộng vi lab cô lập và
   domain `.test` không lên Internet; kết luận chỉ đúng trong môi trường lab. Nói rõ giới hạn này là cộng điểm.
2. **"SPF `-all` rồi thì cần DKIM không?"** → Cần: `-all` chỉ chặn người gửi từ IP lạ của *chính domain*;
   không bảo vệ toàn vẹn nội dung (DKIM `bh=`) và không xử lý `Header From` (DMARC).
3. **"Bật STARTTLS là hết nghe lén?"** → Không, nếu chỉ `may`: AT-06 chứng minh vẫn bị strip. Phải `encrypt`
   (server) + `verify` (client) và tốt nhất thêm MTA-STS/DANE.
