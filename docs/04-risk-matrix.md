# 04 · Ma trận đánh giá rủi ro an toàn dịch vụ thư điện tử (Risk Matrix)

## 1. Phương pháp

Thang 5×5 theo hướng tiếp cận ISO/IEC 27005: `Risk = Likelihood (L) × Impact (I)`,
trong đó **L đánh giá theo độ phức tạp khai thác quan sát được trong lab** (một lệnh swaks
một bước là L rất cao; cần chiếm quyền host là L thấp), **I đánh giá theo CIA + tuân thủ**.
Mỗi dòng có cột **Căn cứ đo được** trỏ đúng file bằng chứng, không cho điểm cảm tính.

```
                Impact →   1      2       3        4         5
   Likelihood 5        5     10     15     20    25(CAO)
   4                    4      8    12     16    20(CAO)
   3                    3      6     9     12    15(TRUNG BÌNH CAO)
   2                    2      4     6      8    10(TRUNG BÌNH)
   1                    1      2     3      4     5(TRUNG BÌNH)
   Ngưỡng chấp nhận: ≤ 6 (thấp). 7–14: cần xử lý trong quý. ≥15: xử lý ngay.
```

## 2. Bảng rủi ro TRƯỚC phòng thủ (điểm cơ sở)

| Mã | Rủi ro | Tác nhân (threat) | Điểm yếu | L | I | R | Xếp loại | Căn cứ đo được (lab) |
|---|---|---|---|---|---|---|---|---|
| R1 | Server bị lạm dụng phát thư rác toàn cầu | Người ngoài mạng, script tự động | `mynetworks = 10.30.0.0/24`, `defer_unauth_destination` | 5 | 4 | **20** | CAO | ĐO 18/10 08:54 UTC: `Server is an open relay (16/16 tests)` trên **cả hai** MTA; `RCPT TO:<nguoidung@khong-phai-domain-lab.test>` → `250 2.1.5 Ok` (`evidence/atk/at01-open-relay.txt`) |
| R2 | Lộ lọt nội dung thư khi truyền | Kẻ cùng L2 / thiết bị trung gian | SMTP 25 không TLS (`smtpd_tls_security_level=none`) | 5 | 4 | **20** | CAO | ĐO 18/10 08:57 UTC: một lệnh `tcpdump -A -r` trên pcap của mail1 cho ra toàn bộ `MAIL FROM`, `RCPT TO`, `Subject` và số tài khoản `1029384756`; số lần STARTTLS trong capture = **0** (`evidence/mail1/at02-cleartext.txt`) |
| R3 | Đánh cắp credential người dùng | Như trên | AUTH PLAIN/LOGIN quảng bá trên kênh không mã hóa | 5 | 5 | **25** | CAO | ĐO 18/10 09:03 UTC: `tcpdump` trên client ghi lại trọn phiên `AUTH LOGIN` ở 587; hai chuỗi `Z2lhbWRvYw==` / `TGFiQDIwMjY=` suy ra `giamdoc` / `Lab@2026` bằng đúng một lệnh `base64 -d`; server còn xác nhận `235 2.7.0 Authentication successful` (`evidence/client/at03-credentials.txt`) |
| R4 | Giả mạo người gửi (BEC/phishing) | Kẻ tấn công từ host bất kỳ | SMTP không xác thực `MAIL FROM`; Envelope ≠ Header From; không SPF/DKIM/DMARC | 5 | 5 | **25** | CAO | ĐO 18/10 09:07 UTC: `MAIL FROM:<admin@congtyA.test>` từ 10.30.0.40 → `250 2.0.0 Ok: queued as 745AE103489`; thư nằm trong `Maildir/new` của `ketoan` với `From: Admin <admin@congtyA.test>` + `Reply-To: attacker@darkside.test`; `Authentication-Results/Received-SPF/DKIM-Signature` đều = 0; `mail.log` ghi `status=sent (delivered to maildir)` |
| R5 | Sửa nội dung thư trên đường truyền | Kẻ ở vị trí trung gian | Không bắt buộc TLS, không kiểm tra chữ ký DKIM | 4 | 5 | **20** | CAO | ĐO 18/10 09:52–09:53 UTC: log proxy `[TAMPER] da thay '9999999999' -> '1029384756' trong than thu (608 byte)`; thư đến hộp `ketoan` (queue `2A38C10349C`) **chỉ còn** số của kẻ tấn công, chuỗi gốc không xuất hiện (`grep -oE … \| uniq -c` = `1 1029384756`) (`evidence/mail2/chup20-inbox-sau-at06.txt`) |
| R6 | Hạ cấp STARTTLS (strip) | Như R5 | Opportunistic TLS: client tự fallback khi mất capability | 4 | 4 | **16** | CAO | ĐO 18/10 09:52 UTC: `[STRIP] AN DONG NAY KHONG cho khach thay: 250-STARTTLS`; pcap phía client có `so dong chua STARTTLS = 0` nhưng swaks vẫn `235 Authentication successful` + `250 2.0.0 Ok: queued as 1D492A1AA4` (exit code 0); chính phiên đó lộ `334 VXNlcm5hbWU6` / `334 UGFzc3dvcmQ6` |
| R7 | Thu thập thông tin để tiền tấn công | Scanner tự động | `disable_vrfy_command = no`, `smtpd_helo_required = no`, banner lộ version | 5 | 2 | **10** | TB | ĐO ĐƯỢC: `VRFY root` → `252 2.0.0 root`, `VRFY giamdoc` → `252 2.0.0 giamdoc` (mail1) và `550 5.1.1 User unknown` (mail2) = oracle dò mailbox; `smtp-commands` liệt kê full capability, không có STARTTLS |
| R8 | Domain bị giả mạo trên Internet thật | Kẻ mạo danh gửi từ hạ tầng ngoài | Không công bố SPF/DMARC → thế giới không có căn cứ từ chối | 4 | 5 | **20** | CAO | TC05 + `dig _dmarc` rỗng trước D-03/D-05 |
| R9 | Chữ ký DKIM hợp lệ của domain khác qua mặt được | Kẻ có hạ tầng email riêng | Chỉ dựa SPF/DKIM rời rạc, chưa kiểm tra alignment | 3 | 4 | **12** | TB | TC23/AT-07: `spf=pass` (darkside) + Header From Alpha |

## 3. Sau phòng thủ – rủi ro còn lại (residual)

| Mã | Kiểm soát đã áp dụng | Cấu hình/bản ghi cụ thể | L' | I' | R' | Căn cứ xác minh |
|---|---|---|---|---|---|---|
| R1 | Đóng relay | `smtpd_relay_restrictions=permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination`; `mynetworks=127.0.0.0/8 …` (D-01) | 1 | 4 | **4** | **ĐO 11:08 UTC**: `Server isn't an open relay, authentication needed` + `554 5.7.1 Relay access denied` |
| R2, R3 | Bắt buộc TLS cả hai phía | `smtpd_tls_security_level=encrypt`, `smtpd_tls_auth_only=yes`, `smtp_tls_security_level=verify`, CA lab (D-02a/b) | 2 | 3 | **6** | **ĐO 11:07 UTC**: `Verify return code: 0 (ok)` + `New, TLSv1.3` trên 25/25/993; AUTH kenh ro → `530 5.7.0 Must issue a STARTTLS command first` |
| R4 | SPF | `v=spf1 ip4:10.30.0.20 mx -all` + `check_policy_service unix:private/policyd-spf` đặt **sau** `reject_unauth_destination`, `TestOnly = 1` (D-03) | 2 | 4 | **8** | **ĐO 11:01 UTC**: `550 5.7.23 … SPF fail - not authorized` (T2 va T3), mail.log day du dong `policyd-spf[…]` |
| R4, R8 | DKIM | `Mode sv`, selector `mail`, RSA-2048, `Canonicalization relaxed/simple`, `OversignHeaders From`, milter 8891 (D-04) | 2 | 4 | **8** | **DO 11:03–11:05 UTC**: thu hop le co `DKIM-Signature: a=rsa-sha256; d=congtya.test; s=mail`; milter khong lay duoc khoa nen `dkim=fail reason="key not found in DNS"`; **kiem chung doc lap** `verify/dkim-check.py` → `openssl verify: Verified OK` (xem 3.6.4 bao cao) |
| R4, R8, R9 | DMARC | `_dmarc` `p=reject; adkim=r; aspf=r; pct=100; rua=…`, `RejectFailures true`, milter 8893 xếp **sau** 8891 (D-05) | 2 | 5 | **10** | **ĐO 11:01 UTC**: `550 5.7.1 rejected by DMARC policy for congtyA.test` (T4) va `opendmarc: congtyA.test pass` cho thu hop le |
| R5 | TLS bắt buộc + DKIM body hash | `smtp_tls_security_level=verify` + DKIM `bh=` trên body (D-02/D-04) | 1 | 5 | **5** | **ĐO 11:07 UTC**: cung lenh AT-06 bi `swaks exit code = 28`, khong con `250 queued` |
| R6 | TLS bắt buộc, không fallback | `encrypt` ở both `smtpd_` và `smtp_` (D-02b encrypt) | 2 | 3 | **6** | **ĐO**: TC13 `queued as 1D492A1AA4` → TC19 `exit code = 28` (cung lenh, dao nguoc ket qua) |
| R7 | Cứng hóa tham số mặc định | `disable_vrfy_command=yes`, `smtpd_helo_required=yes`, banner rút gọn, `smtpd_error_sleep_time/soft/hard_error_limit` (D-01) | 3 | 1 | **3** | **ĐO 11:08 UTC**: `smtp-commands` khong con liet ke `VRFY` cung `AUTH` tren kenh ro |

Nhận xét: R4/R8 sau kiểm soát vẫn 8–10 chứ không về 0, vi **giới hạn cố hữu của bộ ba**:
- SPF fail khi chuyển tiếp (forwarding) và khi gửi từ alias domain; giới hạn 10 lần tra vấn DNS.
- DKIM không ràng buộc `Header From`, chỉ DMARC (alignment) mới làm việc đó.
- DMARC chỉ bảo vệ domain *bị* giả mạo; kẻ tấn công đổi sang domain la → cần blocklist + rate limit.
- Chưa triển khai MTA-STS (RFC 8461)/DANE (RFC 7672) nên chống hạ cấp vẫn phụ thuộc cấu hình 2 đầu.
Những dòng này là nội dung chính của mục 4.2–4.3 trong báo cáo.

## 4. Bảng xếp hạng ưu tiên xử lý (dùng cho Phần 2 của báo cáo)

| Ưu tiên | Rủi ro | Thời gian xử lý | Lý do |
|---|---|---|---|
| 1 | R3 credential theft | Ngay | Độ phức tạp khai thác = 0 bước trung gian, hậu quả chiếm mailbox |
| 2 | R4 impersonation | Ngay | Thiệt hại tài chính trực tiếp (BEC); SPF+DKIM+DMARC là chuẩn ngành |
| 3 | R2 nội dung lộ | Ngay | Vi phạm confidentiality hàng loạt, dễ kiểm soát bằng TLS |
| 4 | R1 open relay | Tuần | Ảnh hưởng reputational + blacklisting |
| 5 | R5/R6 toàn vẹn & hạ cấp | Tháng | Cần mandatory TLS + verify, kèm MTA-STS/DANE để mở rộng |
| 6 | R7 recon | học kỳ | Giảm bề mặt thông tin, chi phí thấp |
