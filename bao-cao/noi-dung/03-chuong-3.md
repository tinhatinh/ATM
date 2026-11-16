## MÔI TRƯỜNG THỰC NGHIỆM, TRIỂN KHAI VÀ KIỂM CHỨNG PHÒNG THỦ

### Thiết kế môi trường thực nghiệm

#### Yêu cầu thiết kế

Môi trường thực nghiệm phải đồng thời thoả bốn yêu cầu, có mâu thuẫn với nhau nếu thiết kế tuỳ
tiện:

* **Đầy đủ chức năng.** Phải có đủ MUA, MTA phía gửi, MTA phía nhận, MDA, DNS và một máy trạm tấn
  công; nếu thiếu một thành phần thì phải mô phỏng bằng thủ công và kết luận mất giá trị.
* **Hai tổ chức độc lập.** Giả mạo danh tính chỉ có ý nghĩa khi tồn tại hai tên miền khác nhau; nếu
  chỉ có một domain thì không thể kiểm chứng được khái niệm alignment của DMARC.
* **Cô lập tuyệt đối.** Toàn bộ lưu lượng tấn công phải nằm trong mạng ảo, không có đường ra
  Internet và không có đường vào mạng của Học viện, theo đúng quy định thực hành của học phần.
* **Tái lập được.** Mỗi trạng thái phải dựng lại được bằng script, để kết quả đo không phụ thuộc
  vào may mắn hay vào một người duy nhất.

Yêu cầu thứ ba và thứ nhất xung đột ở một điểm cụ thể: một hệ thống email "thật" luôn cần phân giải
tên miền công cộng. Giải pháp được chọn là dùng tên miền cấp cao giả lập `.test` theo RFC 6761 và
một máy chủ DNS authoritative-only nội bộ, chấp nhận rằng một số hành vi của resolver sẽ khác với
Internet thật — hệ quả này được phân tích đầy đủ ở mục 3.5.5.

#### Sơ đồ topo

[[HINH|h01-topo.png|Sơ đồ topo phòng thí nghiệm: mạng host-only VMnet2 10.30.0.0/24 với hai tổ chức thư điện tử độc lập, một máy chủ DNS và một máy trạm tấn công]]

Luồng thư trong mô hình đi theo bốn chặng, mỗi chặng là đối tượng của một phép đo riêng:

[[BANG|Bốn chặng truyền thư trong mô hình và cơ chế phòng thủ được kiểm chứng trên từng chặng]]
| Chặng | Hướng | Cổng | Cơ chế bảo vệ được kiểm chứng |
|---|---|---|---|
| C1 | MUA (vm-client) → MTA Alpha | 587 | SMTP AUTH, bắt buộc TLS, phạm vi áp dụng milter |
| C2 | Máy tấn công (vm-atk) → MTA | 25 | Chính sách relay, SPF, DMARC |
| C3 | MTA Alpha → MTA Beta | 25 | STARTTLS, kiểm chứng chứng chỉ, ký và kiểm DKIM |
| C4 | MUA → IMAP/IMAPS | 143 / 993 | Mã hoá truy cập hộp thư, tắt xác thực bản rõ |

#### Quy hoạch máy ảo và tài nguyên

Năm máy ảo Ubuntu Server 24.04.5 LTS chạy trên VMware Workstation, tất cả gắn vào cùng một mạng
host-only VMnet2 với dải 10.30.0.0/24; DHCP của VMware bị tắt trên dải này và địa chỉ được cấu
hình tĩnh qua netplan. Máy chủ Windows của vật chủ giữ địa chỉ 10.30.0.1 và không chạy dịch vụ
thư.

[[BANG|Quy hoạch máy ảo, tài nguyên và dịch vụ — giá trị đọc trực tiếp từ cấu hình máy ảo và từ hệ điều hành khách]]
|Máy ảo|Hostname|FQDN|Địa chỉ tĩnh|vCPU · RAM · đĩa|Dịch vụ chính|Vai trò|
|---|---|---|---|---|---|---|
|vm-dns|ns1|ns1.congtyA.test|10.30.0.10|2 · 2048 MB · 20 GB|BIND 9.18.39|DNS authoritative cho ba tên miền thuận và một zone ngược; nơi lưu CA của lab|
|vm-mail1|mail1|mail1.congtyA.test|10.30.0.20|1 · 1024 MB · 20 GB|Postfix 3.8.6, Dovecot 2.3.21, OpenDKIM 2.11.0|MTA của tổ chức Alpha: ký thư đi, nhận thư đến, kiểm tra DKIM/SPF/DMARC|
|vm-mail2|mail2|mail2.congtyB.test|10.30.0.30|1 · 1024 MB · 20 GB|Postfix, Dovecot, policyd-spf 3.0.4, OpenDMARC 1.4.2|MTA của tổ chức Beta: phía phòng thủ chính, thực thi `p=reject`|
|vm-atk|atk|atk.darkside.test|10.30.0.40|2 · 2048 MB · 20 GB|swaks, Nmap 7.94, tcpdump, proxy Python|Máy trạm tấn công và trung gian MitM|
|vm-client|client|client.congtyA.test|10.30.0.50|2 · 2048 MB · 20 GB|mutt 2.2.12, swaks, tshark 4.2|MUA của người dùng hợp lệ và máy đo|

[[HINH|h02-may-ao.png|Danh sách máy ảo đang chạy và ba mốc snapshot của phòng thí nghiệm, lấy từ công cụ điều khiển máy ảo trên vật chủ]]

[[HINH|h04-trithuc.png|Đọc trực tiếp tài nguyên và phiên bản phần mềm ngay trong hệ điều hành khách của máy chủ thư Alpha]]

[[HINH|h03-mang-tinh.png|Xác nhận địa chỉ tĩnh, cấu hình netplan và trỏ DNS của máy chủ thư Alpha]]

#### Quy hoạch cổng và luồng dịch vụ

[[BANG|Các cổng dịch vụ trong mô hình, hướng kết nối và giai đoạn tồn tại]]
|Cổng|Giao thức|Hướng kết nối|Chức năng|Giai đoạn|
|---|---|---|---|---|
|53|DNS/UDP+TCP|Mọi máy → vm-dns|Phân giải MX, A, PTR và truy vấn bản ghi SPF/DKIM/DMARC|1–4|
|25|SMTP|vm-atk → MTA; MTA → MTA|Chuyển thư giữa máy chủ; là kênh bị khai thác trong AT-01, AT-02, AT-04, AT-05 và các phép phát lại T1–T4|1–4|
|587|SMTP submission|vm-client → MTA|Đẩy thư đi có xác thực; kênh của AT-03, AT-06 và của đường thư hợp lệ|1–4|
|143|IMAP|vm-client → MTA|Truy cập hộp thư bản rõ, dùng để chứng minh lỗ hổng|1–2|
|993|IMAPS|vm-client → MTA|Truy cập hộp thư mã hoá sau khi ban hành D-02|3–4|
|2525|SMTP nội bộ|vm-client → vm-atk → MTA|Cổng lắng nghe của proxy MitM trong kịch bản hạ cấp|2|
|8891|SMTP milter|Postfix ↔ OpenDKIM (loopback)|Chuyển thông điệp cho bộ ký/kiểm DKIM|3–4|
|8893|SMTP milter|Postfix ↔ OpenDMARC (loopback)|Chuyển thông điệp cho bộ thẩm định DMARC|3–4|

#### Tính cô lập của môi trường

Ba lớp cách ly được áp dụng và đều được kiểm tra bằng phép đo phủ định:

* **Cách ly tầng hai.** VMnet2 là mạng host-only: không có NAT, không có bridge với card mạng vật
  lý, không có DHCP. Máy chủ Windows chỉ nhìn thấy các máy ảo trong cùng dải.
* **Cách ly tầng ứng dụng.** BIND được cấu hình `recursion no` và `allow-recursion { none; }`. Phép
  kiểm tra phủ định: truy vấn một tên miền bên ngoài bị trả về trạng thái `REFUSED`, chứng tỏ máy
  chủ DNS của lab không trở thành resolver công cộng và không có đường phân giải ra Internet.
* **Cách ly cấu hình máy trạm.** Toàn bộ máy khách trỏ `nameserver` về 10.30.0.10 và không có
  forwarder nào khác.

[[HINH|h07-quyhoach.png|Nội dung vùng quản trị của tên miền Alpha: bản ghi A, MX, NS và các bản ghi TXT định danh]]

[[HINH|h05-bind-zone.png|Kiểm tra cú pháp và nạp bốn vùng quản trị trên máy chủ DNS]]

[[HINH|h06-dns-records.png|Kết quả kiểm tra bộ bản ghi SPF, DKIM, DMARC của cả hai tên miền kèm hai phép thử phủ định]]

### Triển khai nền tảng

#### Máy chủ DNS

BIND được cấu hình authoritative-only, vùng quản trị đặt trong `/var/lib/bind` để phù hợp với
chính sách AppArmor của bản phân phối. Mỗi lần sửa vùng, serial được tăng và vùng được nạp lại bằng
`rndc reload` thay vì khởi động lại dịch vụ. Bốn vùng được quản trị gồm ba vùng thuận
(`congtyA.test`, `congtyB.test`, `darkside.test`) và một vùng ngược (`0.30.10.in-addr.arpa`), vùng
ngược phục vụ việc đối chiếu tên máy chủ gửi với địa chỉ IP.

#### Hai máy chủ thư và dịch vụ hộp thư

Postfix được cài ở chế độ "Internet Site" với `mydestination` gồm hostname, tên miền và hai alias
không đủ tên miền. Dovecot cung cấp ba vai trò: LMTP nhận thư từ Postfix, IMAP phục vụ máy trạm,
và socket SASL đặt trong không gian tên riêng của Postfix (`/var/spool/postfix/private/auth`) để
cổng 587 xác thực được người dùng hệ thống. Hộp thư theo dạng Maildir, cho phép kiểm tra trực tiếp
từng bức thư như một tệp tin.

Giai đoạn đầu tiên được cố tình cấu hình ở trạng thái chưa phòng thủ: `mynetworks` bao gồm cả dải
lab, `smtpd_tls_security_level = none`, danh sách milter để trống và `disable_plaintext_auth = no`.
Đây là trạng thái giả lập một máy chủ "cho tiện trong nội bộ" — tình huống phổ biến trong các sự cố
thực tế.

#### CA riêng và chứng chỉ TLS

Để việc kiểm chứng chứng chỉ là thật chứ không phải chấp nhận mù quáng, lab dựng một CA nội bộ
("Lab Mail Root CA", RSA 2048 bit, hiệu lực 825 ngày) và cấp chứng chỉ cho từng máy chủ thư với
`subjectAltName` chứa cả tên DNS lẫn địa chỉ IP. Máy chủ gửi được cấu hình `smtp_tls_security_level
= verify` cùng `smtp_tls_CAfile` trỏ về chứng chỉ CA, nên chuỗi tin cậy được đóng kín trong lab mà
không phải dùng chứng chỉ thương mại.

[[HINH|h08-ca-chungchi.png|Chuỗi chứng chỉ của lab: chủ thể, cơ quan phát hành, thời hạn, subjectAltName và kết quả xác minh theo CA nội bộ]]

### Thực nghiệm tấn công trước khi phòng thủ

Sáu kịch bản được thực hiện trong phiên ngày 18/10/2026 từ 08:52 đến 09:10 UTC, riêng kịch bản hạ
cấp chạy ở 09:52 UTC. Mỗi kịch bản lưu một file bằng chứng riêng trong `/root/evidence`.

#### AT-01 — Xác nhận chuyển tiếp mở

Kịch bản dùng hai phép đo độc lập để tránh phụ thuộc vào một công cụ: script chuyên dụng của Nmap
(`smtp-open-relay`, gồm 16 phép thử kết hợp nhiều cặp người gửi/người nhận khác nhau) và một kiểm
tra thủ công bằng swaks với người nhận thuộc tên miền ngoài lab. Kết quả:

[[HINH|h31-open-relay-truoc.png|Kết quả quét chuyển tiếp mở trên cả hai máy chủ thư ở giai đoạn chưa phòng thủ]]

Cả hai MTA đều được kết luận là open relay; phép kiểm tra thủ công xác nhận bằng mã `250 2.1.5 Ok`
cho một địa chỉ không thuộc bất kỳ tên miền nào của lab. Phép thử thứ ba — `VRFY giamdoc` trả về
`252 2.0.0 giamdoc` — cho thấy máy chủ còn đóng vai trò một oracle cho phép kẻ tấn công liệt kê
tài khoản hợp lệ, phục vụ việc soạn thư lừa đảo trúng đích.

#### AT-02 — Nghe lén nội dung thư trên kênh bản rõ

Máy chủ được đặt ở `smtpd_tls_security_level = none`, một bức thư chứa số tài khoản ngân hàng được
gửi đi trong khi máy tấn công thu gói ở cổng 25. Toàn bộ hội thoại xuất hiện nguyên văn, bao gồm cả
phần thân thư:

[[HINH|h16-pcap-clear.png|Trích nội dung gói tin bắt được ở cổng 25: envelope, tiêu đề và số tài khoản ngân hàng đọc được trực tiếp]]

Điểm đáng chú ý trong cùng phép đo: bộ đếm số dòng chứa từ khóa `STARTTLS` trong toàn bộ capture
bằng **0**, tức không có bất kỳ nỗ lực mã hoá nào diễn ra — khác với trường hợp hạ cấp ở AT-06, nơi
nỗ lực mã hoá có tồn tại nhưng bị chặn mất.

#### AT-03 — Đánh cắp thông tin xác thực SMTP

Ở cổng 587 khi chưa bật `smtpd_tls_auth_only`, máy chủ quảng bá `250-AUTH PLAIN LOGIN` ngay trên
kênh bản rõ. Kẻ tấn công thu được hai chuỗi Base64 trong phiên và giải mã bằng một lệnh:

[[HINH|h17-credential.png|Hai chuỗi Base64 thu được từ phiên AUTH LOGIN và kết quả giải mã tương ứng]]

Máy chủ xác nhận `235 2.7.0 Authentication successful` rồi chấp nhận thư. Ở thời điểm này, kẻ tấn
công không còn là người ngoài: họ có quyền gửi đúng danh tính của nạn nhân từ chính hạ tầng được uỷ
quyền, tức là vượt qua mọi kiểm tra dựa trên nguồn gửi.

#### AT-04 và AT-05 — Giả mạo Header From và BEC trong cùng tên miền

Không tài khoản, không mật khẩu, không TLS; kẻ tấn công chỉ cần khai báo `EHLO mail1.congtyA.test`
(giả danh máy chủ hợp lệ) và `MAIL FROM:<admin@congtyA.test>`:

[[HINH|h18-spoof-queued.png|Phiên SMTP giả mạo người gửi: máy chủ chấp nhận và xếp hàng đợi thư mạo danh]]

Bức thư xuất hiện trong hộp thư của kế toán với ba dấu vết, trong đó hai dấu vết đầu bị giao diện
MUA che khuất:

```
From:     Admin <admin@congtyA.test>
Reply-To: "Admin" <attacker@darkside.test>
Received: from mail1.congtyA.test (atk.darkside.test [10.30.0.40])
```

Dòng `Received` cho thấy máy chủ đã *tin vào* chuỗi `EHLO` giả: tên máy chủ là giả, chỉ địa chỉ IP
nguồn là thật. Ba bộ đếm header xác thực trong tệp thư đều bằng 0 — hệ thống không hề thực hiện bất
kỳ kiểm tra định danh nào trước khi phát thư.

[[HINH|h19-inbox-0.png|Hộp thư nạn nhân sau AT-04: ba bộ đếm Authentication-Results, Received-SPF và DKIM-Signature đều bằng 0]]

AT-05 lặp lại đúng kỹ thuật với hai địa chỉ *trong cùng tên miền Alpha* (`postmaster@` và
`giamdoc@`) và cả hai đều được chấp nhận, mô phỏng đúng kịch bản BEC nội bộ — kịch bản mà người dùng
được đào tạo nhận biết "người lạ" sẽ không phát hiện ra.

#### AT-06 — Hạ cấp STARTTLS kết hợp sửa nội dung trên đường truyền

Đây là kịch bản phức tạp nhất và đòi hỏi viết một proxy trung gian riêng (`attacks/strip_starttls.py`)
hoạt động ở cổng 2525 trên vm-atk: nhận kết nối từ máy trạm, tự kết nối tới MTA, chuyển tiếp hai
chiều nhưng loại bỏ dòng `250-STARTTLS` trong phản hồi `EHLO`, ghi lại cặp thông tin đăng nhập và
thay số tài khoản trong thân thư.

Để loại trừ nghi vấn "kết quả có được là do cấu hình sai", phép đo được tổ chức thành một cặp có đối
chứng:

[[BANG|Cặp phép đo có đối chứng của kịch bản hạ cấp STARTTLS (AT-06)]]
| Bước | Phép đo | Kết quả thực tế |
|---|---|---|
| [0] | `EHLO` trực tiếp cổng 587, không qua proxy | Phản hồi **có** `250-STARTTLS` — điều kiện cần được xác lập |
| [1] | swaks yêu cầu TLS đi thẳng | `235 2.7.0 Authentication successful`, thư được xếp hàng đợi — kênh TLS thật hoạt động |
| [2] | swaks tuỳ chọn TLS **qua proxy** | swaks in `*** Host did not advertise STARTTLS`, nhưng vẫn xác thực thành công và thư vẫn được xếp hàng đợi, mã thoát 0 |
| [3] | Phân tích gói ở cổng 2525 | Số dòng chứa `STARTTLS` = **0**; xuất hiện `334 VXNlcm5hbWU6`, `334 UGFzc3dvcmQ6`, tiêu đề và số tài khoản |
| [4] | Nhật ký proxy | Ba nhóm hành vi: `[STRIP]`, `[AUTH-THIEP]`, `[TAMPER]` với số byte bị thay đổi |
| [5] | Hộp thư nạn nhân | Tệp thư **chỉ còn** số tài khoản giả; chuỗi số gốc không tồn tại trong tệp |

[[HINH|h20-strip-proxy.png|Nhật ký proxy trung gian: ẩn dòng quảng bá STARTTLS, ghi lại cặp thông tin đăng nhập và thay số tài khoản trong thân thư]]

Chuỗi `Received` của bức thư bị sửa là một bản vẽ hoàn chỉnh của tấn công: chặng đầu tiên được ghi
`with ESMTPA` trên kênh bản rõ (bị hạ cấp), trong khi chặng MTA–MTA phía sau vẫn `using TLSv1.3`.
Nói cách khác, mã hoá *một phần* đường truyền không bảo vệ được gì nếu điểm yếu nằm ở đoạn được mặc
định coi là "tin cậy nội bộ".

### Triển khai bốn lớp phòng thủ

Toàn bộ biện pháp được ban hành bằng script, chạy trên cả hai MTA, và được xác nhận lại bằng
`postconf -n` ngay trong script để tránh tình trạng "sửa file nhưng chưa nạp lại".

#### D-01 — Đóng chuyển tiếp mở và siết chính sách truy cập

[[HINH|h11-relay-dong.png|Chuỗi restriction sau khi ban hành: mynetworks chỉ còn loopback, bổ sung kiểm tra recipient và policy service]]

Ba điểm kỹ thuật đáng lưu ý. Thứ nhất, `mynetworks` được thu về đúng ba dải loopback; mọi quyết định
chấp nhận thư từ nay dựa trên xác thực hoặc trên chính sách người nhận, không dựa vào vị trí mạng.
Thứ hai, `smtpd_helo_required = yes` và `disable_vrfy_command = yes` loại bỏ cả hai kênh thu thập
thông tin của rủi ro R7. Thứ ba — và là điểm sư phạm quan trọng nhất — **thứ tự** trong chuỗi
restriction quyết định hiệu lực của các lớp sau: `permit_mynetworks` đứng trước
`reject_unauth_destination` và trước `check_policy_service`, nên chỉ cần `mynetworks` còn chứa dải
lab thì bộ lọc SPF *không bao giờ được gọi*. Đây là lỗi cấu hình kinh điển và lab đo được nó một
cách tường minh.

#### D-02 — Bắt buộc TLS và ngắt khả năng xác thực ngoài mã hoá

[[HINH|h09-tls-batbuoc.png|Trạng thái tham số TLS của Postfix và Dovecot sau khi ban hành chính sách bắt buộc mã hoá]]

Cấu hình được đặt ở ba mức khác nhau cho ba vai trò: phía nhận dùng `encrypt` (buộc phiên vào TLS),
phía gửi dùng `verify` (buộc và kiểm chứng chứng chỉ theo CA nội bộ), và `smtpd_tls_auth_only = yes`
khiến máy chủ *chỉ quảng bá* khả năng xác thực khi phiên đã nằm trong TLS. Ở tầng giao thức,
SSLv2/SSLv3/TLSv1/TLSv1.1 bị loại bỏ; phía Dovecot đặt `ssl = required` và
`disable_plaintext_auth = yes`.

Hai tác dụng quan sát được ngay sau khi nạp cấu hình, rất thuận lợi cho trình diễn: danh sách tính
năng trả về từ `EHLO` trên kênh bản rõ **không còn** dòng `250-AUTH`, và cũng mất luôn `VRFY`.

#### D-03 — Bộ lọc SPF và công tắc thực thi

[[HINH|h12-spf-bo-loc.png|Cấu hình bộ lọc SPF: công tắc thực thi, chính sách từ chối và vị trí trong chuỗi restriction]]

Ba thành phần phải khớp nhau: bản ghi TXT được công bố trên DNS, dòng khai báo service trong
`master.cf`, và `check_policy_service unix:private/policyd-spf` trong chuỗi restriction của phía
nhận. Bộ lọc được đặt **sau** `reject_unauth_destination` để không biến máy chủ thành relay mở cho
thư được policy cho phép.

Điểm dễ gây nhầm lẫn nhất trong toàn bộ đề tài nằm ở tham số `TestOnly`. Trang man của gói
`postfix-policyd-spf-python` định nghĩa: *"set TestOnly = 0. If you want test operation with no
header added"* — tức giá trị `0` mới là chế độ thử không tác động, còn **`TestOnly = 1` là chế độ
thực thi**. Rất nhiều tài liệu hướng dẫn trên mạng diễn đạt ngược điều này. Nhóm phải đọc trực tiếp
trang man của gói đang cài để quyết định giá trị cấu hình.

[[HINH|h13-spf-dns.png|Hai bản ghi SPF được công bố và trạng thái bốn dịch vụ trên máy chủ phòng thủ]]

#### D-04 — Sinh khoá RSA, công bố bản ghi và kích hoạt bộ lọc DKIM

[[HINH|h10-dkim-key.png|Cấu hình OpenDKIM phía ký: cặp khoá 2048 bit, selector, chế độ sv và danh sách máy nội bộ]]

Khoá được sinh bằng `opendkim-genkey -b 2048 -s mail`, khoá riêng đặt tại `/etc/dkimkeys` với quyền
chỉ người dùng `opendkim` đọc được, khoá công khai được chuyển thành bản ghi TXT tại
`mail._domainkey.<domain>` và nạp vào vùng quản trị. Hai chi tiết dễ sai: tên khoá trong
`opendkim.conf` là `InternalHosts` chứ **không phải** `TrustedHosts` (một khoá không tồn tại trong
OpenDKIM), và dòng `Socket` trong tệp cấu hình gói dùng ký tự tab nên các phép biến đổi văn bản dựa
vào khoảng trắng sẽ âm thầm không khớp.

#### D-05 — Chính sách DMARC p=reject và phạm vi áp dụng

[[HINH|h14-dmarc-chain.png|Cấu hình OpenDMARC: cổng milter, AuthservID tin cậy, công tắc RejectFailures và override cho cổng submission]]

Ba bản ghi DMARC được công bố cho hai tên miền cần bảo vệ và một tên miền bên thứ ba, với
`p=reject`, `pct=100`, `fo=1` và `rua` trỏ về hộp thư báo cáo. Trên máy chủ nhận, `RejectFailures
true` là công tắc biến *đánh giá* thành *hành động*: theo cấu hình mặc định của OpenDMARC, bộ lọc
chỉ ghi kết quả vào header mà vẫn cho thư đi qua.

Thứ tự trong chuỗi milter là bắt buộc: OpenDKIM (8891) phải đứng trước OpenDMARC (8893), vì bộ thẩm
định DMARC đọc kết quả DKIM từ ngữ cảnh riêng của cùng thông điệp. Nếu đảo vị trí, `dmarc=` sẽ vĩnh
viễn nhận giá trị `none`.

[[HINH|h15-dns-3record.png|Nguyên văn ba bản ghi định danh được truy vấn từ máy chủ phòng thủ]]

**Phạm vi áp dụng.** DMARC là cơ chế thẩm định *thư đến*. Khi `RejectFailures` được áp cho mọi dịch
vụ SMTP, chính sách chặn nhầm cả người dùng hợp lệ: thư của một kế toán gửi từ máy trạm nội bộ qua
cổng 587 bị chính MTA của tổ chức mình từ chối, vì địa chỉ IP của máy trạm không nằm trong bản ghi
SPF của tên miền và bức thư chưa được ký. Cách xử lý đúng chuẩn vận hành là giới hạn phạm vi milter
theo từng dịch vụ: giữ chuỗi đầy đủ cho cổng 25 và đặt override `-o smtpd_milters=inet:localhost:8891`
cho dịch vụ `submission`, để cổng đẩy thư chỉ ký mà không thẩm định. Sau khi điều chỉnh, thư hợp lệ
đi qua bình thường trong khi các kịch bản giả mạo vẫn bị chặn — hai mục tiêu đạt được đồng thời.

### Kiểm chứng hiệu lực phòng thủ

#### Phát lại toàn bộ tấn công

Năm tình huống được gửi lại bằng đúng công cụ và đúng tham số đã dùng ở giai đoạn tấn công, chỉ khác
trạng thái máy chủ. Kết quả **5/5 khớp kỳ vọng**:

[[HINH|h26-replay5.png|Bảng tổng hợp của script phát lại: năm tình huống, mã phản hồi thực tế và kết luận khớp]]

[[BANG|Đối chiếu kết quả trước và sau phòng thủ trên cùng một lệnh]]
|Test|Tình huống|Mã trước phòng thủ|Mã sau phòng thủ|Cơ chế đã chặn|
|---|---|---|---|---|
|T1|Xin chuyển tiếp tới tên miền ngoài lab|`250 2.1.5 Ok`|`554 5.7.1 Relay access denied`|`reject_unauth_destination` + `mynetworks` thu hẹp|
|T2|Giả mạo `admin@congtyA.test` gửi sang Beta|`250 2.0.0 Ok: queued`|`550 5.7.23 … SPF fail - not authorized`|SPF thực thi tại `RCPT`|
|T3|Giả mạo `postmaster@congtyA.test` gửi nội bộ Alpha|`250 2.0.0 Ok: queued`|`550 5.7.23 … SPF fail - not authorized`|SPF thực thi, không phân biệt trong/ngoài|
|T4|SPF đúng của tên miền bên thứ ba, `Header From` thuộc Alpha|`250 2.0.0 Ok: queued`|`550 5.7.1 rejected by DMARC policy for congtyA.test`|DMARC alignment|
|T5|Thư hợp lệ: đúng tài khoản, có TLS, qua cổng 587|`250 2.0.0 Ok: queued`|`250 2.0.0 Ok: queued`|Không chặn — điều kiện phủ định|

Cặp kết quả T4 và T5 là phần trả lời trực tiếp cho luận điểm trung tâm của đề tài. T4 chứng minh
DMARC chặn được trường hợp mà SPF *không* phát hiện: người gửi dùng tên miền của chính mình nên SPF
`pass`, nhưng `Header From` lại thuộc tên miền cần bảo vệ, và alignment đã phát hiện sự lệch này.
T5 chứng minh điều ngược lại: cơ chế chặn không lan sang thư hợp lệ.

#### Quét lại trạng thái chuyển tiếp

Cùng một lệnh, cùng một công cụ, cùng một máy quét, kết luận đảo ngược:

[[HINH|h21-relay-sau.png|Quét lại chuyển tiếp mở sau khi phòng thủ trên cả hai máy chủ thư]]

#### Đường đi của một bức thư hợp lệ

Bức thư hợp lệ được gửi từ máy trạm qua cổng 587 với xác thực và TLS, tới máy chủ Alpha, chuyển sang
Beta qua cổng 25 với TLS được kiểm chứng, rồi được phát vào Maildir của người nhận:

[[HINH|h27-happy-path.png|Phiên gửi hợp lệ qua cổng submission: xác thực thành công trong TLS và thư được xếp hàng đợi]]

Máy chủ nhận ghi lại toàn bộ kết quả thẩm định vào header của thư đến:

[[HINH|h22-auth-mail2.png|Header xác thực trên thư đến máy chủ Beta: Received-SPF pass, dòng verdict DMARC và chữ ký DKIM]]

Ở chiều ngược lại (Beta ký và gửi sang Alpha), máy chủ Alpha ghi cả dòng verdict DMARC đầy đủ nhất,
cho thấy thiết kế đối xứng hai chiều hoạt động:

[[HINH|h23-auth-mail1.png|Header xác thực trên thư đến máy chủ Alpha kèm dòng verdict dmarc=pass với p=reject]]

Bảng tổng hợp trạng thái xác thực theo từng kịch bản:

[[BANG|Trạng thái ba lớp xác thực và kết quả phát thư theo bốn kịch bản đo được]]
|Kịch bản|SPF|DKIM|DMARC|Thư được phát?|
|---|---|---|---|---|
|Alpha → Beta, thư hợp lệ|`pass`|`fail` — milter không lấy được khoá (mục 3.5.5)|`pass`|Có|
|Beta → Alpha, thư hợp lệ|`pass`|`fail` — như trên|`pass (p=reject dis=none)`|Có|
|Giả mạo từ máy ngoài lab|`fail`|không có chữ ký|`fail`|Không — `550 5.7.23`|
|Tên miền bên thứ ba, Header From lệch|`pass` cho `darkside.test`|không có chữ ký|`fail` do alignment|Không — `550 5.7.1`|

Hai dòng đầu cho thấy đúng tính chất "đủ một cơ chế là qua" của DMARC: `dmarc=pass` đạt được nhờ
SPF alignment, còn DKIM chưa đóng góp được trong môi trường lab. Đây là điểm cần được nói rõ thay vì
chỉ trình bày kết quả `pass`.

#### Kiểm tra mã hoá và khả năng chống hạ cấp

[[HINH|h28-tls-rates.png|Kiểm tra chứng chỉ, thương lượng TLS và phản ứng của máy chủ khi bị hạ cấp]]

Ba kết quả trong phép đo này. Thứ nhất, xác minh chứng chỉ bằng đúng CA của lab trả
`Verify return code: 0 (ok)` và phiên thương lượng ở TLSv1.3 trên cả cổng 25, 587 và 993. Thứ hai,
thử gửi thông tin đăng nhập trên kênh chưa mã hoá bị từ chối bằng mã `530 Must issue a STARTTLS
command first`. Thứ ba — phép đo quan trọng nhất — khi buộc phiên đi qua proxy ẩn `250-STARTTLS`
như ở AT-06, swaks in `*** Host did not advertise STARTTLS` và kết thúc với mã thoát 28: phiên bị
huỷ thay vì âm thầm hạ cấp. Cùng lệnh này ở giai đoạn 2 từng trả `250 queued`.

[[HINH|h29-imaps.png|Truy cập hộp thư qua IMAPS với chứng chỉ được xác minh và phản ứng của cổng IMAP bản rõ]]

#### Kiểm chứng độc lập chữ ký DKIM và giới hạn của môi trường

Mội bức thư hợp lệ đều mang header `DKIM-Signature` đầy đủ và máy chủ nhận ghi
`dkim=fail reason="key not found in DNS"`. Để xác định chữ ký có vấn đề hay chỉ có bước truy vấn
khoá bị vấn đề, nhóm viết một công cụ kiểm chứng độc lập cài đặt đúng trình tự mục 3.5 của RFC 6376,
trong đó khoá công khai được lấy bằng `dig` (đi qua stub resolver của hệ thống):

[[HINH|h24-dkim-verify.png|Kết quả kiểm chứng chữ ký DKIM bằng công cụ độc lập: giá trị băm thân thư khớp và openssl trả Verified OK]]

Kết quả xác nhận ba điều: giá trị `bh=` tính lại khớp tuyệt đối với giá trị trong header; khoá công
khai truy vấn từ DNS có độ dài 392 ký tự Base64 tương ứng 294 byte cấu trúc SPKI của RSA-2048; và
`openssl dgst -sha256 -verify` trả `Verified OK`. Chuỗi khoá riêng — chữ ký — khoá công khai là hợp
lệ.

Nguyên nhân milter không tự kiểm tra được được xác định bằng ba phép loại trừ:

[[HINH|h25-dkim-testkey.png|Đối chiếu: công cụ kiểm khoá của OpenDKIM báo not found trong khi cùng truy vấn qua dig trả về đủ bản ghi]]

* `ldd /usr/sbin/opendkim` cho thấy tiến trình liên kết với `libunbound.so.8`. Khác với `dig` và
  Postfix, OpenDKIM tự thực hiện phân giải **đệ quy lặp** từ nhóm máy chủ gốc và không dùng
  `/etc/resolv.conf`.
* Đặt máy chủ DNS của lab trong chế độ thu gói ở cổng 53 trong khi kiểm chứng: số truy vấn mang
  `_domainkey` quan sát được bằng **0**. Máy chủ DNS của lab thậm chí không được hỏi tới.
* Bốn cách dẫn đường qua `ResolverConfiguration` (forward-zone, stub-zone, root-hints trỏ về máy
  chủ DNS của lab, và local-data thuần cục bộ) đều không thay đổi kết quả, trong khi tệp cấu hình
  được chứng minh là có nạp thật: cố tình viết sai cú pháp thì OpenDKIM báo lỗi không nạp được cấu
  hình, và đổi nội dung thì mã lỗi thay đổi.

Kết luận: OpenDKIM 2.11.0 cùng libunbound trên bản phân phối 24.04, trong mạng host-only không có
đường ra Internet và dùng tên miền cấp cao giả lập theo RFC 6761, không có đường nào để tự lấy khoá
công khai. Đây là giới hạn của hạ tầng phân giải trong môi trường cô lập, không phải lỗi của định
dạng bản ghi hay của thuật toán chữ ký. Hướng khắc phục được nêu trong phần Kết luận: bổ sung một resolver đệ
quy nội bộ để mọi thành phần — kể cả libunbound — có cùng một điểm hỏi.

### Kết quả định lượng tổng hợp

[[BANG|Tổng hợp kết quả đo theo từng lớp phòng thủ, đối chiếu trước và sau]]
|Lớp phòng thủ|Biện pháp ban hành|Phép đo|Trước|Sau|
|---|---|---|---|---|
|Chuyển tiếp|`mynetworks` loopback + `reject_unauth_destination`|Kết luận của công cụ quét dịch vụ|Open relay (16/16 phép thử)|Không phải open relay, cần xác thực|
|Chuyển tiếp|Như trên|`RCPT TO:` tên miền ngoài|`250 2.1.5 Ok`|`554 5.7.1 Relay access denied`|
|Kênh truyền|`smtpd_tls_security_level = encrypt`|Xác minh chứng chỉ theo CA lab|Không có TLS|`Verify return code: 0 (ok)`, TLSv1.3|
|Xác thực|`smtpd_tls_auth_only = yes`|`AUTH` trên kênh bản rõ|`235 Authentication successful`|`530 Must issue a STARTTLS command first`|
|Chống hạ cấp|`encrypt` ở cả hai đầu|swaks qua proxy ẩn STARTTLS|`250 queued`, exit 0|Kết thúc với mã thoát 28|
|Người gửi|SPF `-all` + `TestOnly = 1`|Giả mạo envelope sender|`250 queued`|`550 5.7.23 SPF fail - not authorized`|
|Toàn vẹn|DKIM `c=relaxed/simple`, RSA-2048|Kiểm chứng chữ ký độc lập|Không có chữ ký|`bh=` khớp, `Verified OK`|
|Danh tính|DMARC `p=reject` + `RejectFailures true`|Thư có Header From lệch|`250 queued`|`550 5.7.1 rejected by DMARC policy`|
|Tính sẵn dùng|Override milter cho `submission`|Thư hợp lệ qua cổng 587|`250 queued`|`250 queued` (không đổi)|

Chín phép đo ở bảng trên cho thấy mỗi lớp phòng thủ được kiểm chứng bằng một đại lượng độc lập, và
lớp cuối cùng — không chặn nhầm người dùng hợp lệ — là lớp thường bị bỏ qua nhất trong các tài liệu
hướng dẫn triển khai.

### Kết chương

Chương 3 đã hoàn thành cả hai vế của phương pháp thực nghiệm. Ở vế tấn công, sáu kịch bản chứng minh
tính khả thi của bốn nhóm lỗ hổng bằng số liệu nguyên văn: hai máy chủ đều open relay, nội dung thư
và cặp thông tin đăng nhập đọc được từ gói tin, ba bức thư giả mạo được phát vào hộp thư nạn nhân
với toàn bộ bộ đếm xác thực bằng 0, và một cuộc tấn công hạ cấp vừa lấy được credential vừa sửa được
số tài khoản trong thân thư. Ở vế phòng thủ, bốn lớp được ban hành bằng script và được kiểm chứng
bằng cách phát lại đúng các tấn công cũ: năm trên năm tình huống cho kết quả khớp kỳ vọng, trong đó
tình huống T4 chứng minh vai trò không thể thay thế của DMARC alignment và tình huống T5 chứng minh
hệ thống không chặn nhầm. Hai phát hiện giá nhất của toàn bộ đề tài — công tắc `TestOnly` mang ngữ
nghĩa ngược với tên gọi, và phạm vi áp dụng milter theo từng dịch vụ — đều chỉ xuất hiện ở bước kiểm
chứng, không xuất hiện ở bước cấu hình.
