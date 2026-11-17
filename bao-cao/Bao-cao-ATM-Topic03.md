# BÁO CÁO HỌC PHẦN AN TOÀN MẠNG (INT1482)

**ĐỀ TÀI:** An toàn dịch vụ thư điện tử – xây dựng và kiểm chứng hệ thống phòng thủ nhiều lớp dựa
trên STARTTLS, SPF, DKIM và DMARC

**Mã lớp học phần:** [điền] · **Số thứ tự nhóm:** 03 · **Giảng viên hướng dẫn:** [điền]

**Thành viên:** Phạm Minh Thiện (B23DCAT285) · Đỗ Hà Quân (B23DCAT245) · Nghiêm Xuân Hoàng Tùng
(B23DCAT326) · Phan Thành Danh (B23DCAT040) · Trần Văn Trung (B23DCAT305)

**Môi trường:** 5 máy ảo Ubuntu Server 24.04.5 LTS trên VMware Workstation, mạng host-only VMnet2
10.30.0.0/24, cô lập hoàn toàn với Internet và hạ tầng của Học viện.

*Bản Word theo mẫu chuẩn của Học viện: `Bao cao ATM - Topic 03 - nhom 3.docx` (mục lục, danh mục
hình và bảng do Word tự sinh, mở trong Word rồi chọn Update Field nếu cần).*

---



# MỞ ĐẦU

Dịch vụ thư điện tử là hạ tầng lâu đời nhất nhưng cũng quan trọng nhất của mạng Internet.
Khác với các giao thức sinh sau, SMTP được thiết kế năm 1982 trong một môi trường gồm vài chục
nghiên cứu viện tin cậy lẫn nhau, nơi việc khai báo sai tên người gửi chưa từng được coi là vấn
đề bảo mật. Khi thư điện tử trở thành phương tiện giao dịch chính của toàn bộ nền kinh tế số, ba
giả thiết nền tảng của thiết kế gốc đều đã vỡ: không có cơ chế xác thực người gửi, không có mã
hoá kênh truyền, và máy chủ nhận thư đồng thời là máy chủ chuyển tiếp tự do. Hệ quả là bốn nhóm
sự cố vẫn tiếp tục xảy ra hằng ngày trên diện rộng: giả mạo danh tính người gửi, nghe lén nội
dung thư trên đường truyền, lạm dụng máy chủ làm trạm phát thư rác, và đánh cắp thông tin xác
thực của người dùng.

Bốn cơ chế chuẩn hoá do IETF ban hành, STARTTLS (RFC 3207), SPF (RFC 7208), DKIM (RFC 6376) và
DMARC (RFC 7489), được thiết kế để bịt đúng bốn khe hở nói trên, nhưng mỗi cơ chế chỉ trả lời
một câu hỏi xác định và chỉ có hiệu lực khi được cấu hình đúng. Trên thực tế, phần lớn sự cố email
của doanh nghiệp không đến từ việc thiếu công nghệ, mà đến từ việc cấu hình sai thứ tự, sai phạm
vi hoặc hiểu nhầm ngữ nghĩa của tham số. Vì vậy đề tài được chọn không dừng ở mức mô tả lý
thuyết, mà dựng một hệ thống thư điện tử hoàn chỉnh để **đo** hành vi của từng lớp phòng thủ
trước và sau khi kích hoạt.

**Mục tiêu của đề tài** gồm bốn nội dung:

* Làm rõ kiến trúc và nguyên lý hoạt động của hệ thống thư điện tử theo chuẩn Internet: vai trò
  của MUA, MTA, MDA; trình tự hội thoại SMTP; quan hệ phụ thuộc giữa định tuyến thư và hệ thống
  DNS.
* Phân tích các lỗ hổng cố hữu của giao thức, bao gồm cả nhóm lỗ hổng ở tầng chính sách
  (open relay, giả mạo người gửi, truyền dạng rõ) và nhóm lỗ hổng ở tầng giao thức
  (hạ cấp STARTTLS), kèm bảng đánh giá rủi ro theo thang 5×5.
* Xây dựng môi trường thực nghiệm cô lập gồm năm máy ảo Ubuntu Server, trong đó có hai tổ chức
  thư điện tử độc lập giao tiếp với nhau qua hai tên miền giả lập, có máy chủ DNS riêng và máy
  trạm tấn công riêng.
* Chứng minh tính khả thi của từng cuộc tấn công bằng số liệu đo được, sau đó triển khai đồng bộ
  bốn lớp phòng thủ và kiểm chứng lại bằng cách phát hành đúng các cuộc tấn công đã dùng.

**Đối tượng nghiên cứu** là giao thức SMTP ở tầng ứng dụng, hai khái niệm định danh trong email
(envelope sender và header sender), và bốn chuẩn xác thực STARTTLS, SPF, DKIM, DMARC cùng cách
các chuẩn này tương tác với DNS. **Phạm vi** giới hạn ở kênh truyền giữa các máy chủ và giữa máy
trạm với máy chủ; đề tài không xem lọc nội dung theo ngữ nghĩa (chống thư rác dựa trên nội dung),
không triển khai chữ ký S/MIME hay PGP ở phía người dùng, và không đánh giá các tấn công từ chối
dịch vụ ở tầng mạng.

**Phương pháp thực hiện** là thực nghiệm có đối chứng. Mỗi kết luận trong báo cáo đều gắn với một
lệnh cụ thể, một đầu ra cụ thể và một file bằng chứng được lưu lại kèm dấu thời gian. Toàn bộ
kịch bản được đóng gói thành 21 script shell chạy lại được; ba mốc quan trọng của phòng thí
nghiệm được đóng snapshot để bảo đảm tính tái lập.

**Quy tắc an toàn của môi trường thực nghiệm.** Toàn bộ tấn công, quét cổng và nghe lén chỉ diễn
ra trong mạng ảo host-only VMnet2 (dải 10.30.0.0/24) của VMware Workstation. Mạng này không có
đường ra Internet, không được cấp DHCP, và máy chủ DNS của lab được cấu hình *authoritative-only*
(từ chối truy vấn đệ quy), nên không một gói tin tấn công nào có thể rời khỏi môi trường ảo hoá.
Không có bất kỳ hành động nào hướng vào mạng của Học viện hoặc vào hệ thống công cộng bên ngoài,
theo đúng quy định thực hành của học phần.

Báo cáo gồm ba chương và phần kết luận. Chương 1 trình bày cơ sở lý thuyết về kiến trúc thư điện
tử, giao thức SMTP, vai trò của DNS và nguyên lý của bốn cơ chế xác thực. Chương 2 phân tích các
lỗ hổng cố hữu, đi sâu vào tấn công hạ cấp STARTTLS, và lượng hoá rủi ro bằng ma trận đánh giá.
Chương 3 mô tả môi trường thực nghiệm, các kịch bản tấn công đã thực hiện trước khi phòng thủ,
quy trình triển khai bốn lớp bảo vệ và kết quả kiểm chứng định lượng sau khi phòng thủ.


## CƠ SỞ LÝ THUYẾT VỀ DỊCH VỤ THƯ ĐIỆN TỬ VÀ CÁC CƠ CHẾ XÁC THỰC

### Kiến trúc hệ thống thư điện tử hiện đại

Một hệ thống thư điện tử tuân thủ chuẩn Internet gồm ba nhóm thành phần chức năng độc lập, giao
tiếp với nhau qua giao thức có đặc tả mở. Cách phân chia này cho phép mỗi thành phần tiến hoá
riêng: người dùng đổi chương trình đọc thư không ảnh hưởng máy chủ, đổi máy chủ không ảnh hưởng
cách lưu trữ hộp thư.

#### Mail User Agent (MUA)

MUA là ứng dụng cài trên thiết bị của người dùng hoặc chạy dưới dạng webmail, chịu trách nhiệm
soạn, hiển thị và tổ chức thư. MUA không bao giờ trực tiếp chuyển thư cho MTA của người nhận; nó
chỉ nói chuyện với hạ tầng của chính tổ chức mình theo hai hướng:

* **Chiều gửi đi (submission):** MUA kết nối tới MTA nội bộ trên cổng 587 (hoặc 465 cho SMTP
  wrapped-TLS) và bắt buộc phải xác thực bằng tài khoản người dùng. Cơ chế xác thực này gọi là
  SMTP AUTH, thường dùng cơ chế PLAIN hoặc LOGIN đóng gói trong phiên TLS.
* **Chiều nhận vào:** MUA truy vấn hộp thư qua IMAP (cổng 143 không mã hoá, 993 qua TLS) hoặc
  POP3 (110/995).

Trong lab của đề tài, MUA được dùng là `mutt 2.2.12` truy cập `imap://ketoan@mail2.congtyB.test`.
Lựa chọn này có chủ đích: MUA chỉ hiển thị trường `Header From` của bức thư và không đưa ra bất
kỳ chỉ báo nào về việc thư đã được xác thực hay chưa, đúng như hạn chế nhận thức của người dùng
cuối trong các sự cố giả mạo thực tế.

#### Mail Transfer Agent (MTA)

MTA là thành phần server chịu trách nhiệm tiếp nhận thư từ MUA hoặc từ MTA khác, áp dụng chính
sách truy cập, định tuyến và chuyển thư tới đúng máy chủ của tên miền người nhận. Bốn nhiệm vụ
cốt lõi của MTA:

* **Kiểm soát truy cập và chuyển tiếp.** MTA phải quyết định ba câu hỏi độc lập: có chấp nhận thư
  từ địa chỉ này không (chính sách relay), có chấp nhận người gửi này không (chính sách sender),
  và có chấp nhận người nhận này không (chính sách recipient). Sai một trong ba là mở đường cho
  lạm dụng.
* **Tra cứu DNS.** MTA phân giải bản ghi MX của tên miền người nhận, rồi phân giải A của máy chủ
  MX đó để lấy địa chỉ IP đích.
* **Đàm phán SMTP và STARTTLS** với MTA nhận trên cổng 25, bao gồm cả việc quyết định có mã hoá
  hay không.
* **Chuyển giao cho các bộ lọc.** Thông qua giao diện Milter, MTA chuyển nội dung thư cho các
  tiến trình bên ngoài để kiểm tra chữ ký số, chính sách người gửi và danh tính.

Đề tài dùng Postfix 3.8.6. Postfix được chọn vì kiến trúc phân quyền theo tiến trình và vì cơ chế
danh sách restriction cho phép quan sát trực tiếp *thứ tự* đánh giá, một yếu tố quyết định hiệu
lực bảo mật, được phân tích ở mục 3.4.

#### Mail Delivery Agent (MDA)

MDA nhận bức thư sau khi MTA đã hoàn tất kiểm tra bảo mật và đưa vào không gian lưu trữ của hộp
thư người nhận, đồng thời phục vụ các giao thức truy cập hộp thư. Trong mô hình của đề tài,
Dovecot 2.3.21 đảm nhiệm cả ba vai trò: MDA (qua LMTP), server IMAP, và cung cấp socket SASL
`/var/spool/postfix/private/auth` cho Postfix dùng ở cổng 587. Việc gộp ba vai trò vào một tiến
 trình là lựa chọn có ý thức nhằm giảm số biến số khi phân tích nguyên nhân sự cố.

#### Cấu trúc lưu trữ hộp thư: Maildir và mbox

Có hai cách tổ chức lưu trữ hộp thư trên hệ thống tệp Linux.

* **mbox** ghi toàn bộ thư của một tài khoản vào một tệp duy nhất. Nhược điểm căn bản là cơ chế
  khoá tệp: một tiến trình đọc có thể khoá cả hộp thư, và một lỗi ghi giữa chừng có thể làm hỏng
  toàn bộ lịch sử thư.
* **Maildir** lưu mỗi bức thư là một tệp độc lập trong ba thư mục `tmp`, `new`, `cur`. Không có
  khoá tệp; một tệp thư hỏng chỉ ảnh hưởng đúng bức thư đó. Việc chuyển thư từ `new` sang `cur`
  chỉ là một phép đổi tên nguyên tử.

Đề tài dùng Maildir (`/home/<user>/Maildir/new/`) vì cấu trúc này cho phép kiểm chứng trực tiếp
bằng chứng: bức thư mà một kịch bản tấn công chèn được vào hộp thư người nhận hiện ra đúng là một
tệp tin, có thể đọc nguyên văn header và đếm số dòng xác thực bằng các công cụ chuẩn.

### Cơ chế hoạt động của các giao thức cốt lõi

#### Giao thức truyền thư tín SMTP (RFC 5321)

SMTP hoạt động trên nền TCP, dùng cổng 25 cho quan hệ server-to-server và cổng 587 cho việc đẩy
thư từ máy khách. Hội thoại SMTP là một chuỗi lệnh, đáp mã số theo trình tự xác định:

1. **Khởi tạo kết nối.** Client mở socket tới cổng 25. Server chủ động gửi dòng chào:
   `220 mail1.congtyA.test ESMTP Postfix (Ubuntu)`.
2. **Chào hỏi và đàm phán tính năng.** Client gửi `EHLO <tên-máy>`. Server đáp `250-` kèm danh
   sách phần mở rộng được hỗ trợ: `STARTTLS`, `AUTH PLAIN LOGIN`, `8BITMIME`, `PIPELINING`,
   `DSN`, `SMTPUTF8`, `CHUNKING`. Danh sách này là cơ sở để client quyết định có mã hoá và có xác
   thực hay không.
3. **Khai báo người gửi.** `MAIL FROM:<address>`. Server đáp `250 2.1.0 Ok`.
4. **Khai báo người nhận.** `RCPT TO:<address>`. Server kiểm tra chính sách relay/recipient rồi
   đáp `250 2.1.5 Ok` hoặc mã từ chối 5xx.
5. **Truyền nội dung.** Client gửi `DATA`; server đáp `354 End data with <CR><LF>.<CR><LF>`;
   client truyền khối header và body rồi kết thúc bằng một dòng chứa dấu chấm đơn. Server đáp
   `250 2.0.0 Ok: queued as <message-id>`, thời điểm bức thư được ghi vào hàng đợi.
6. **Đóng phiên.** `QUIT` → `221 2.0.0 Bye`.

Nhóm mã phản hồi mang ý nghĩa pháp lý rõ ràng: `2xx` là chấp nhận, `4xx` là tạm thời (gửi lại
sau), `5xx` là từ chối dứt điểm. Một bức thư bị chặn bằng mã `5xx` ngay tại lệnh `RCPT` sẽ không
bao giờ được xếp vào hàng đợi, do đó không bao giờ xuất hiện trong hộp thư người nhận, đây là
điểm khác biệt căn bản so với các biện pháp hậu kiểm (đánh dấu spam, lọc sau khi giao).

#### Sự khác biệt giữa Envelope Sender và Header From

Đây là nguồn gốc của toàn bộ nhóm lỗ hổng giả mạo danh tính. SMTP (RFC 5321) và định dạng thông
điệp (RFC 5322) là hai đặc tả độc lập, và mỗi cái có một trường "người gửi":

* **Envelope sender** xuất hiện trong lệnh `MAIL FROM:<...>` của hội thoại SMTP. Địa chỉ này được
  dùng để định tuyến thông báo hoàn trả và được ghi vào trường `Return-Path` khi thư tới nơi. Đây
  là giá trị mà SPF kiểm tra.
* **Header From** nằm trong khối dữ liệu gửi bằng lệnh `DATA`, ví dụ
  `From: Admin <admin@congtyA.test>`. Đây là giá trị duy nhất người đọc nhìn thấy trên giao diện
  MUA, và là giá trị mà DMARC yêu cầu phải khớp với một trong hai cơ chế xác thực.

Giao thức SMTP nguyên thủy không đặt ra bất kỳ nghĩa vụ nào bắt hai giá trị này trùng khớp. Lệnh
`MAIL FROM` không được ký, không được xác thực, và server nhận thư chỉ ghi lại địa chỉ IP của bạn
kết nối chứ không kiểm chứng danh tính mà bên kia tự khai. Hệ quả trực tiếp: bất kỳ ai có khả
năng thiết lập kết nối TCP tới cổng 25 đều có thể phát đi thư mang bất kỳ địa chỉ hiển thị nào.

#### Giao thức truy cập hộp thư: IMAP và POP3

* **POP3 (RFC 1939, cổng 110/995)** hoạt động theo mô hình tải về và xoá: client nhận bản sao rồi
  xóa bản gốc trên server. Đơn giản nhưng không phù hợp với làm việc đa thiết bị và không giữ cấu
  trúc thư mục.
* **IMAP4rev1 (RFC 3501, cổng 143/993)** là mô hình đồng bộ hai chiều: hộp thư và cây thư mục nằm
  trên server, client thao tác trên bản chỉ mục. IMAP cho phép tìm kiếm phía server và đánh dấu
  đã đọc, nhưng cũng khiến server trở thành nơi lưu tập trung toàn bộ nội dung thư, làm tăng giá
  trị của một cặp credential bị đánh cắp.

Cả hai giao thức đều có chế độ bản rõ và chế độ mã hoá. Điểm cần lưu ý về mặt an toàn: IMAP cổng
143 cho phép truyền `LOGIN` dưới dạng văn bản rõ nếu server không bắt buộc TLS, tức là cùng một
lỗ hổng nghe lén với SMTP nhưng hậu quả lớn hơn nhiều vì nó cấp quyền đọc toàn bộ hộp thư.

### Vai trò của hệ thống DNS trong định tuyến và xác thực thư

DNS không phải dịch vụ phụ trợ mà là một phần của biên phòng thủ email, vì ba lý do.

* **Định tuyến.** Bản ghi MX quyết định thư của một tên miền sẽ được gửi tới máy chủ nào, kèm độ
  ưu tiên. Sai một bản ghi MX, thư của cả tổ chức đi vào khoảng trống.
* **Công bố chính sách.** Toàn bộ ba cơ chế xác thực đều dựa trên bản ghi TXT: SPF nằm ở root
  domain, DKIM nằm ở `<selector>._domainkey.<domain>`, DMARC nằm ở `_dmarc.<domain>`. Tính khả
  dụng của phòng thủ email do đó phụ thuộc trực tiếp vào tính đúng đắn của vùng DNS.
* **Đối chiếu danh tính ngược.** Bản ghi PTR (zone ngược) cho phép máy chủ nhận kiểm tra xem địa
  chỉ IP gửi thư có thực sự thuộc về tên miền mà nó tự khai trong `EHLO` hay không; Postfix dùng
  cơ chế `reject_unknown_client_hostname` và `reject_unknown_hostname` cho việc này.

Trong môi trường thực nghiệm, tên miền cấp cao `.test` được dùng theo RFC 6761, tên miền cấp cao
dành riêng cho thử nghiệm và không bao giờ được phân phối trên Internet thật. Cách chọn này bảo
đảm tuyệt đối rằng không có suy đoán định tuyến nào hướng ra ngoài, đồng thời lý giải một hệ quả
kỹ thuật được phân tích ở mục 3.5.5: các resolver đệ quy chuẩn sẽ không bao giờ phân giải được
`.test`.

### Cơ sở lý thuyết của bốn cơ chế phòng vệ chủ đạo

#### Cơ chế mã hoá kênh truyền STARTTLS (RFC 3207)

STARTTLS là phần mở rộng cho phép nâng cấp một kết nối SMTP đang ở dạng bản rõ lên TLS trong cùng
một kênh TCP, thay vì dùng một cổng riêng. Trình tự như sau:

1. Client gửi `EHLO`; server đáp danh sách tính năng, trong đó có dòng `250-STARTTLS`.
2. Client gửi `STARTTLS`; server đáp `220 2.0.0 Ready to start TLS`.
3. Hai bên tạm dừng SMTP và thực hiện bắt tay TLS: trao đổi chứng thư số X.509, thương lượng bộ
   thuật toán, sinh khoá phiên.
4. Client gửi lại `EHLO` trên kênh đã mã hoá và tiếp tục phiên SMTP. Toàn bộ nội dung sau điểm
   này, kể cả thông tin xác thực, đi qua đường hầm mã hoá.

Đặc điểm thiết kế quan trọng nhất, và cũng là gốc của lỗ hổng hạ cấp, là cơ chế **opportunistic
TLS**: nếu phía kia không quảng bá `STARTTLS`, phía gửi được phép tiếp tục bằng bản rõ thay vì
ngắt kết nối. Thiết kế này sinh ra để bảo đảm tương thích ngược với hạ tầng cũ, nhưng nó chuyển
toàn bộ quyết định an toàn sang một thông điệp không được bảo vệ.

Trong Postfix, hành vi được điều khiển bằng ba mức của tham số `smtpd_tls_security_level` (phía
nhận) và `smtp_tls_security_level` (phía gửi):

[[BANG|Ba mức cấu hình an toàn TLS trong Postfix và hệ quả lên chiều nhận, chiều gửi]]
| Giá trị | Hành vi phía nhận (`smtpd_`) | Hành vi phía gửi (`smtp_`) |
|---|---|---|
| `none` | Không cung cấp TLS | Không dùng TLS |
| `may` | Quảng bá STARTTLS, nhưng chấp nhận phiên bản rõ | Mã hoá nếu bên kia hỗ trợ, không thì gửi bản rõ |
| `encrypt` | Bắt buộc phiên phải vào TLS trước khi nhận thư | Bắt buộc; không thương lượng được TLS thì huỷ gửi |
| `verify` |, | Bắt buộc và kiểm chứng chứng chỉ của bên kia theo danh sách CA tin cậy |

Hai tham số bổ trợ quan trọng: `smtpd_tls_auth_only = yes` khiến server chỉ quảng bá `AUTH` khi
phiên đã nằm trong TLS, loại bỏ khả năng đánh cắp credential trên kênh rõ; và
`smtpd_tls_received_header = yes` ghi lại thông tin phiên mã hoá vào header của thư đến, tạo bằng
chứng truy vết.

#### Khung chính sách người gửi SPF (RFC 7208)

SPF giải quyết vấn đề giả mạo *envelope sender*. Chủ tên miền công bố một bản ghi TXT liệt kê
những máy chủ được phép phát thư mang tên miền đó:

```
congtyA.test.  IN  TXT  "v=spf1 ip4:10.30.0.20 mx -all"
```

Khi máy chủ nhận chấp nhận một kết nối, nó lấy địa chỉ IP của máy gửi và phần domain của
`MAIL FROM`, truy vấn bản ghi SPF của domain đó, rồi trả về một trong bảy kết quả: `pass`,
`fail`, `softfail`, `neutral`, `none`, `temperror`, `permerror`. Các tiền tố định danh có ý
nghĩa: `+` cho phép (mặc định), `-` cấm tuyệt đối và khuyến nghị từ chối, `~` cấm nhưng khuyến
nghị nhận kèm gắn nhãn, `?` trung lập. Chỉ thị `-all` ở cuối bản ghi khẳng định mọi máy chủ không
được liệt kê đều là giả mạo.

Hai giới hạn của SPF phải được phát biểu rõ. Thứ nhất, SPF chỉ nhìn envelope sender, hoàn toàn
không liên hệ với `Header From`; kẻ tấn công có thể dùng một envelope sender hợp lệ của tên miền
khác và đặt `Header From` tuỳ ý. Thứ hai, kết quả SPF hỏng theo thiết kế khi thư được chuyển tiếp
(forward), vì IP gửi lại là IP của máy chủ trung gian. Do đó SPF là một điều kiện cần, không phải
điều kiện đủ, và chỉ thực sự mạnh khi có DMARC đặt lên trên.

Một điểm ngữ nghĩa dễ gây nhầm lẫn, và đã gây nhầm lẫn ngay trong lab: bộ lọc
`postfix-policyd-spf-python` dùng biến `TestOnly`, trong đó **`TestOnly = 1` là chế độ thực thi**
(chặn thư) còn `0` mới là chế độ thử không tác động. Tên biến ngược với trực giác này buộc phải
kiểm chứng bằng trang man của gói đang cài thay vì bằng tài liệu thứ cấp.

#### Chữ ký số xác thực nguồn gốc DKIM (RFC 6376)

DKIM dùng mật mã khoá công khai để bảo đảm hai tính chất: xác thực nguồn gốc và toàn vẹn nội dung.

**Phía ký.** MTA gửi giữ một khoá riêng tư RSA (đề tài dùng 2048 bit). Với mỗi bức thư đi qua, bộ
lọc ký thư thực hiện: chuẩn hoá (canonicalise) phần header và body theo thuật toán đã khai báo;
tính hàm băm SHA-256 của body đã chuẩn hoá, ghi thành thẻ `bh=`; tính chữ ký số trên tổng hợp các
trường header đã ký cùng giá trị `bh=`, ghi thành thẻ `b=`; chèn kết quả vào header
`DKIM-Signature`.

**Phía kiểm tra.** Máy chủ nhận đọc `DKIM-Signature`, lấy tên miền `d=` và selector `s=`, truy vấn
bản ghi TXT tại `<s>._domainkey.<d>` để lấy khoá công khai, tự tính lại các giá trị băm và xác
minh chữ ký. Một bức thư hợp lệ có dạng:

```
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/simple; d=congtya.test; s=mail;
    t=1792321439; bh=QUQDHZuOy+yQb0u9VQbRnsgzww026mKrJU2+5fm4sms=;
    h=Date:To:From:Subject:From;
    b=MDHu9ZD50KtNlnyYoZuKF0ggdLxZHWVghXH7Jau+iHDtI/Vt88Nmgqy3esSfEDTM7...
```

Các thẻ đáng chú ý: `a=` là bộ thuật toán chữ ký; `c=relaxed/simple` mô tả cách chuẩn hoá ,
header được "làm gọn" (gom khoảng trắng, chuẩn hoá chữ hoa tên trường) còn body giữ nguyên trừ
các dòng trống ở cuối; `h=` liệt kê trường nào được ký; `t=` là dấu thời gian ký, cho phép từ chối
chữ ký quá cũ; `l=` (nếu có) giới hạn số byte body được băm; `z=` giữ bản gốc các trường đã ký để
phục vụ đối chiếu. Selector `s=` cho phép xoay khoá mà không đổi tên miền, và một domain có thể
công bố nhiều selector cùng lúc.

Giới hạn căn bản của DKIM: chữ ký chứng minh *nội dung không bị sửa kể từ khi rời khỏi miền `d=`*,
nhưng không chứng minh miền `d=` có quan hệ gì với `Header From`. Một tên miền bất kỳ có thể ký
cho một bức thư mang `Header From` của tên miền khác, và chữ ký vẫn hợp lệ. Đây chính là khe hở
mà DMARC đóng lại.

#### Cơ chế xác thực và thực thi chính sách DMARC (RFC 7489)

DMARC không phải một cơ chế xác thực độc lập; nó là lớp chính sách nằm trên SPF và DKIM, trả lời
câu hỏi mà hai cơ chế kia bỏ ngỏ: *ai được quyền nhân danh tên miền trong `Header From`*. Chủ tên
miền công bố bản ghi TXT tại `_dmarc.<domain>`:

```
_dmarc.congtyA.test.  IN  TXT  "v=DMARC1; p=reject; sp=none; adkim=r; aspf=r;
                               pct=100; fo=1; rua=mailto:dmarc-reports@congtyA.test"
```

Nguyên tắc cốt lõi là **căn chỉnh định danh** (identifier alignment): một cơ chế chỉ được tính là
chứng minh được danh tính khi nó vừa cho kết quả `pass` vừa có tên miền trùng với tên miền trong
`Header From`. Chế độ `r` (relaxed) cho phép khớp theo domain tổ chức, tức `mail1.congtyA.test`
được coi là cùng tổ chức với `congtyA.test`; chế độ `s` (strict) yêu cầu trùng khớp tuyệt đối.
Điều kiện để `dmarc=pass` là **ít nhất một** trong hai cơ chế SPF hoặc DKIM thoả mãn cả pass lẫn
alignment.

Ba mức chính sách `p=`: `none` chỉ theo dõi và báo cáo; `quarantine` đề nghị coi thư vi phạm là
thư rác; `reject` yêu cầu từ chối ngay trong phiên SMTP bằng mã 5xx. Tham số `pct=` cho phép áp
d dụng chính sách trên một tỷ lệ phần trăm lưu lượng, là công cụ thiết yếu để triển khai dần dần
trên hệ thống thật. Tham số `sp=` đặt chính sách riêng cho domain con. Tham số `fo=1` quy định
cách tạo báo cáo khi cả hai cơ chế cùng fail. Hai loại báo cáo được định nghĩa: báo cáo tổng hợp
qua `rua` (định kỳ, dạng XML nén, cho biết ai đang gửi thư mang tên miền của mình và kết quả xác
thực) và báo cáo pháp y qua `ruf` (chi tiết từng thư vi phạm).

Cần phân biệt rõ hai vai trò dễ bị nhầm lẫn: **đánh giá** và **hành động**. Một bộ thẩm định DMARC
có thể tính ra `dmarc=fail` mà vẫn cho thư đi qua, nếu tham số thực thi bị tắt. Trong Postfix,
hành động chặn chỉ xảy ra khi bộ lọc milter được đặt vào đúng danh sách restriction của đúng dịch
vụ SMTP đang chạy.

#### Các mở rộng chuẩn hoá ở tầng cao hơn

Ba chuẩn sau không được triển khai trong đề tài nhưng thuộc bức tranh toàn cảnh và được nêu ở
hướng phát triển:

* **MTA-STS (RFC 8461)** cho phép chủ tên miền công bố chính sách "bắt buộc TLS" qua một tệp đặt
  trên HTTPS kèm bản ghi `_mtasts` trong DNS. Vì chính sách được lấy qua HTTPS có chứng chỉ hợp
  lệ, kẻ ở giữa không thể âm thầm bỏ qua nó, từ đó triệt tiêu được tấn công hạ cấp giữa hai tổ
  chức.
* **DANE for SMTP (RFC 7672)** neo giá trị băm chứng chỉ TLS vào bản ghi TLSA trong DNSSEC, biến
  DNS đã ký thành nguồn xác thực danh tính máy chủ.
* **SMTP TLS Reporting (RFC 8460)** cho phép chủ tên miền nhận báo cáo định kỳ về các phiên TLS
  thất bại, là công cụ giám sát cần thiết sau khi bật chế độ bắt buộc.

Riêng với tấn công hạ cấp, cần lưu ý một hệ quả logic: MTA-STS và DANE bảo vệ *chính sách*, còn
việc *thực thi* chính sách đó vẫn phụ thuộc vào việc cả hai đầu có hỗ trợ. Với các tên miền chưa
công bố chính sách, opportunistic TLS vẫn là mặc định của Internet.

### Lựa chọn bộ giải pháp công nghệ mã nguồn mở

[[BANG|Bộ công cụ mã nguồn mở sử dụng trong đề tài kèm phiên bản cài đặt thực tế]]
| Thành phần | Công cụ và phiên bản cài đặt | Vai trò | Lý do lựa chọn |
|---|---|---|---|
| Hệ điều hành | Ubuntu Server 24.04.5 LTS | Nền tảng cả năm máy ảo | Bản hỗ trợ dài hạn, kho gói chuẩn, có sẵn tài liệu cấu hình Postfix/Dovecot |
| DNS | BIND 9.18.39 | Máy chủ authoritative cho ba tên miền và một zone ngược | Chuẩn mực của Internet, cho phép tách rõ vai trò uy quyền và đệ quy |
| MTA | Postfix 3.8.6 | Chuyển thư giữa hai tổ chức, nhận thư từ máy trạm | Danh sách restriction minh bạch, đo được thứ tự đánh giá |
| MDA / IMAP / SASL | Dovecot 2.3.21 | Giao thư vào Maildir, phục vụ IMAP, cấp SASL cho Postfix | Một tiến trình đảm nhiệm ba vai trò, giảm biến số khi chẩn đoán |
| Lọc SPF | postfix-policyd-spf-python 3.0.4 | Thẩm định kết quả SPF và quyết định chặn | Có công tắc thực thi riêng, cho phép so sánh "chỉ ghi header" và "chặn" |
| Ký / kiểm DKIM | OpenDKIM 2.11.0 | Ký thư đi và kiểm chữ ký thư đến | Triển khai tham chiếu của RFC 6376, tách hai chế độ theo `Mode sv` |
| Thẩm định DMARC | OpenDMARC 1.4.2 | Tính alignment và thực thi `p=reject` | Hỗ trợ `RejectFailures`, minh hoạ phân biệt đánh giá và hành động |
| Mã hoá | OpenSSL 3.0.13 | CA riêng của lab và chứng chỉ TLS cho hai MTA | Cho phép dựng chuỗi tin cậy khép kín trong mạng cô lập |
| Tạo thư / giả lập tấn công | swaks 20240103.0 | Phát các phiên SMTP tuỳ biến từng trường | Can thiệp được cả envelope lẫn header, cần thiết cho kịch bản giả mạo |
| Quét dịch vụ | Nmap 7.94 kèm NSE `smtp-open-relay` | Kiểm định trạng thái relay | 16 phép thử chuẩn hoá, cho kết luận nhị phân trước và sau phòng thủ |
| Bắt gói tin | tcpdump 4.99, tshark 4.2 | Thu và phân tích lưu lượng cổng 25/587/2525 | Đọc được nguyên văn hội thoại, kể cả sau khi đã mã hoá |
| Trung gian tấn công | Python 3.12 (proxy tự viết) | Mô phỏng kẻ ở giữa xoá chỉ thị STARTTLS | Cho phép kiểm soát chính xác từng byte đi qua |
| MUA | mutt 2.2.12 | Đọc hộp thư người nhận qua IMAP | Hiển thị đúng những gì người dùng cuối nhìn thấy |

Toàn bộ công cụ đều là phần mềm mã nguồn mở, không phụ thuộc nhà cung cấp thương mại, và mọi phiên
bản ở cột hai là phiên bản thực sự được cài trong phòng thí nghiệm, kiểm tra bằng
`dpkg-query -W -f='${Version}'`.

### Kết chương

Chương 1 đã xác lập ba luận điểm làm nền cho phần thực nghiệm. Thứ nhất, hai khái niệm "người gửi"
trong email là độc lập về mặt giao thức, và SMTP không có nghĩa vụ liên kết chúng; đây là gốc rễ
của nhóm tấn công giả mạo. Thứ hai, bốn cơ chế phòng vệ không trùng lặp chức năng: STARTTLS bảo
vệ *đường truyền*, SPF trả lời *máy chủ này có được gửi thay mặt tên miền kia không*, DKIM trả
lời *nội dung có bị sửa sau khi ký không*, DMARC trả lời *ai được quyền nhân danh tên miền trong
Header From*. Thứ ba, hiệu lực của cả bốn cơ chế phụ thuộc vào DNS và vào thứ tự cấu hình, tức là
vào hai yếu tố quản trị chứ không phải vào bản thân thuật toán. Ba luận điểm này sẽ được kiểm
chứng bằng số liệu ở Chương 3.


## PHÂN TÍCH LỖ HỔNG VÀ ĐÁNH GIÁ RỦI RO CỦA DỊCH VỤ THƯ ĐIỆN TỬ

### Các lỗ hổng cố hữu của giao thức thư điện tử nguyên thủy

Bốn nhóm lỗ hổng dưới đây không phải là lỗi cài đặt của một sản phẩm cụ thể. Chúng là hệ quả trực
tiếp của các quyết định thiết kế năm 1982, khi SMTP được xây dựng cho một cộng đồng nhỏ các tổ
chức nghiên cứu và chưa có khái niệm về mô hình quan hệ đối thủ (adversary model).

#### Lỗ hổng chuyển tiếp mở (Open Relay)

**Cơ chế kỹ thuật.** Một MTA được gọi là "open relay" khi nó chấp nhận chuyển tiếp thư có người
nh nhận thuộc tên miền thứ ba, từ một máy gửi không thuộc phạm vi quản lý của mình. Điều kiện xảy
ra là cấu hình cho phép chuyển tiếp quá rộng: hoặc danh sách mạng tin cậy gồm cả một dải địa chỉ
mà kẻ tấn công có thể xuất hiện trong đó, hoặc thiếu điều kiện `reject_unauth_destination` trong
chính sách relay.

**Hệ quả.** Máy chủ bị biến thành trạm trung chuyển thư rác với chi phí tài nguyên thuộc về nạn
nhân. Ba hậu quả dây chuyền: cạn kiệt băng thông và nghẽn hàng đợi; địa chỉ IP và dải mạng bị các
tổ chức chặn thư (DNSBL như Spamhaus, Barracuda) đưa vào danh sách đen chỉ trong vài giờ; và
nghiêm trọng nhất về mặt nghiệp vụ, *toàn bộ* thư hợp lệ của tổ chức bị các hệ thống khác nghi ngờ
hoặc từ chối, do uy tín của dải IP đã bị huỷ hoại. Đây là rủi ro thuộc về uy tín và tính liên tục
của dịch vụ, không chỉ là rủi ro kỹ thuật thuần tuý.

**Biểu hiện trong thực nghiệm.** Trong giai đoạn cấu hình ban đầu, cả hai máy chủ thư của lab đều
được công cụ quét dịch vụ kết luận là open relay, và phép kiểm tra thủ công xác nhận: một yêu cầu
`RCPT TO:` hướng tới địa chỉ ngoài hai tên miền của lab được chấp nhận với mã `250 2.1.5 Ok`. Chi
tiết số đo được trình bày ở mục 3.3.1.

#### Giả mạo định danh người gửi (Email Spoofing)

**Cơ chế kỹ thuật.** Xuất phát trực tiếp từ sự bất đối xứng giữa envelope sender và header sender
đã phân tích ở mục 1.2.2. Máy chủ nhận không có nghĩa vụ, và trong SMTP nguyên thủy là không có
khả năng, kiểm tra xem địa chỉ hiển thị trong `From:` có thuộc quyền sử dụng của bên đang gửi hay
không.

**Hệ quả.** Phá vỡ hoàn toàn cơ sở niềm tin của giao tiếp điện tử. Người nhận không còn công cụ kỹ
thuật nào để phân biệt một bức thư thực sự do đối tác, lãnh đạo hay cơ quan chức năng gửi với một
bức thư được tạo bởi bất kỳ ai có kết nối TCP tới cổng 25. Các chỉ báo mà giao diện thư điện tử
đưa ra (cờ xác nhận, hình đại diện, chữ ký) đều có thể bị làm giả hoặc bị kẻ tấn công khai thác
qua các trường header khác như `Reply-To`.

#### Truyền dạng rõ và đánh cắp thông tin xác thực

**Cơ chế kỹ thuật.** Trước khi có TLS, toàn bộ hội thoại SMTP và nội dung thông điệp được truyền
dưới dạng ký tự ASCII thuần tuý. Kẻ tấn công ở cùng phân đoạn mạng, hoặc ở một điểm trung gian mà
họ kiểm soát, chỉ cần thu thập gói tin là đọc được toàn bộ.

**Đối tượng bị lộ.**

* Nội dung thư và tệp đính kèm, bao gồm hợp đồng, hồ sơ tài chính, thông tin khách hàng.
* Danh tính người gửi, người nhận, tiêu đề và thời gian gửi, đủ để dựng lại sơ đồ quan hệ của một
  tổ chức (metadata analysis).
* Thông tin đăng nhập khi MUA xác thực với MTA qua kênh chưa mã hoá. Trường hợp này nghiêm trọng
  hơn hai trường hợp trên, vì cơ chế `AUTH PLAIN` và `AUTH LOGIN` chỉ là mã hoá Base64, một phép
  biến đổi mã hoá không khoá, giải mã được bằng một lệnh duy nhất.

**Hệ quả dây chuyền của việc mất credential.** Khác với các lỗ hổng còn lại, đánh cắp credential
không chỉ cho phép *đọc* mà cho phép *gửi đúng danh tính thật*. Khi kẻ tấn công có tài khoản hợp lệ
và gửi từ chính hạ tầng được uỷ quyền, cả ba cơ chế SPF, DKIM và DMARC đều trả kết quả `pass` một
cách chính đáng. Đây là lý do nhóm xếp rủi ro này ở mức cao nhất trong ma trận ở mục 2.3.

#### Tấn công lừa đảo có chủ đích và xâm nhập email doanh nghiệp (BEC)

Giả mạo danh tính là viên gạch nền cho hai lớp tấn công nghiệp vụ:

* **Business Email Compromise (BEC).** Kẻ tấn công mạo danh lãnh đạo hoặc đối tác, gửi yêu cầu
  chuyển tiền khẩn cấp tới bộ phận kế toán, bộ phận có động cơ tâm lý để tuân thủ và ít có thói
  quen xác minh chéo. Hiệu quả của tấn công không đến từ khai thác kỹ thuật mà từ việc khai thác
  khoảng trống giữa "thứ máy chủ tin" và "thứ người đọc tin".
* **Thu thập thông tin đăng nhập (credential harvesting).** Thư mạo danh thông báo tài khoản sắp
  hết hạn, dẫn người dùng tới một trang đăng nhập giả mạo. Trang giả mạo này thường được đặt tên
  gần giống tên thật (look-alike domain), một kỹ thuật mà SPF/DKIM/DMARC không bảo vệ, như bàn ở
  phần Kết luận.

Một biến thể tinh vi hơn được sử dụng trong thực nghiệm của nhóm là kết hợp `Header From` giả mạo
với `Reply-To` trỏ về hộp thư của kẻ tấn công: nạn nhân nhìn thấy tên người gửi đáng tin, nhưng mọi
phản hồi lại rơi vào tay kẻ mạo danh mà không có cảnh báo nào ở phía giao diện.

### Phân tích chuyên sâu: tấn công hạ cấp STARTTLS

Mặc dù STARTTLS được sinh ra để khắc phục lỗ hổng truyền dạng rõ, bản thân cơ chế này chứa một yếu
tố thiết kế có thể bị khai thác, và đây là nhóm tấn công mà tài liệu phổ thông về an toàn email mô
t tả ít nhất.

#### Bản chất của cơ chế opportunistic TLS

Để bảo đảm tương thích ngược với hạ tầng cũ, chuẩn SMTP quy định rằng việc mã hoá là *tùy cơ hội*:
bên gửi hỏi xem bên nhận có hỗ trợ TLS hay không; nếu có thì thiết lập kênh mã hoá; nếu không thì
**tiếp tục gửi dưới dạng bản rõ** thay vì ngắt kết nối. Hệ quả là "không mã hoá" trở thành một
trạng thái hợp lệ và im lặng, không có tín hiệu lỗi nào phát sinh cho người dùng hay cho quản trị
viên.

#### Nguyên lý kẻ đứng giữa bóc tách chỉ thị STARTTLS

Kẻ tấn công ở vị trí trung gian (đầu độc ARP, chiếm quyền định tuyến, hoặc kiểm soát một cổng trung
chuyển) thực hiện đúng một thao tác: chặn phản hồi `EHLO` của máy chủ nhận và loại bỏ dòng
`250-STARTTLS` trước khi chuyển tiếp cho bên gửi.

1. Client gửi `EHLO`.
2. Server đáp danh sách tính năng, trong đó có `250-STARTTLS`.
3. Kẻ trung gian xoá dòng đó (hoặc thay bằng một dòng vô nghĩa mà client bỏ qua).
4. Client kết luận server đích không hỗ trợ TLS.
5. Theo quy tắc opportunistic, client hạ cấp và truyền toàn bộ nội dung, kể cả thông tin đăng nhập
  , dưới dạng bản rõ.

Cuộc tấn công thành công trọn vẹn trong điều kiện *cả hai đầu đều đã cài đặt TLS đầy đủ*. Không có
cảnh báo nào được hiển thị, không có mã lỗi nào được ghi vào nhật ký, và bằng chứng duy nhất tồn
tại là sự vắng mặt của một dòng trong gói tin. Đây là điểm phân biệt căn bản giữa tấn công hạ cấp
và các tấn công ở trên: nó tấn công vào *quá trình thương lượng* chứ không tấn công vào *dữ liệu*.

Ở mức độ tinh vi hơn, kẻ trung gian có thể sửa cả nội dung thông điệp đang truyền, chẳng hạn đổi
số tài khoản thụ hưởng trong một yêu cầu chuyển tiền. Khi đó tính toàn vẹn bị vi phạm ngay cả trong
trường hợp thư được giao thành công và người nhận không nhận thấy dấu hiệu bất thường nào.

#### Giải pháp đối phó: bắt buộc TLS, MTA-STS và DANE

Ba giải pháp được chuẩn hoá để triệt tiêu tấn công hạ cấp, xếp theo mức độ khả dụng triển khai:

* **Bắt buộc TLS ở tầng cấu hình.** Chuyển `smtpd_tls_security_level` sang `encrypt` ở phía nhận và
  `smtp_tls_security_level` sang `encrypt` hoặc `verify` ở phía gửi. Hành vi chuyển từ "có thì
  dùng" sang "không có thì không gửi" (fail-closed). Khi `verify` được dùng kèm một danh sách CA
  tin cậy, máy chủ gửi còn phát hiện được việc chứng chỉ đích bị giả mạo. Giải pháp này hiệu quả
  nhưng có giới hạn: nó chỉ buộc được những *cặp* máy chủ mà quản trị viên đã cấu hình.
* **MTA-STS (RFC 8461).** Chủ tên miền công bố chính sách bắt buộc TLS qua một tệp trên HTTPS kèm
  bản ghi `_mtasts` trong DNS. Vì chính sách được lấy qua HTTPS có chứng chỉ hợp lệ, kẻ ở giữa
  không thể âm thầm làm cho nó "biến mất". Đây là cơ chế đóng đúng lỗ hổng của opportunistic TLS
  ở quy mô toàn Internet.
* **DANE for SMTP (RFC 7672).** Neo giá trị băm chứng chỉ TLS vào bản ghi TLSA trong DNSSEC. Danh
  tính của máy chủ nhận được xác lập bởi DNS đã ký thay vì bởi một CA thương mại, loại bỏ cả tấn
  công hạ cấp lẫn tấn công chứng chỉ giả mạo.

Trong phạm vi một mạng cô lập gồm hai tổ chức do cùng một nhóm quản trị, giải pháp thứ nhất là đủ
và được chọn triển khai; hai giải pháp còn lại được đưa vào hướng phát triển trong phần Kết luận vì chúng
đòi hỏi hạ tầng DNSSEC hoặc HTTPS công cộng.

### Phương pháp đánh giá rủi ro

Mức độ rủi ro của từng lỗ hổng được lượng hoá theo công thức tích hai thành phần:

```
Risk = Likelihood (L) x Impact (I),   L va I theo thang 5 bac
```

Trong đó **L** được chấm theo *độ phức tạp khai thác quan sát được trong phòng thí nghiệm* chứ
không theo ước đoán: một tấn công thực hiện được bằng một lệnh duy nhất, không cần chiếm quyền thiết
bị, không cần tương tác với nạn nhân, được coi là L = 5. **I** được chấm theo mức độ thiệt hại lên
ba thuộc tính bí mật, toàn vẹn, sẵn dùng, cộng thêm yếu tố tuân thủ và uy tín. Thang phân loại
áp dụng: 1–6 là chấp nhận được; 8–14 cần biện pháp kiểm soát; 15–19 là cao; 20–25 là nghiêm trọng,
bắt buộc xử lý trước khi đưa hệ thống vào khai thác. Ngưỡng chấp nhận của đề tài đặt tại R ≤ 6.

Mỗi dòng của ma trận đều có cột "căn cứ đo" dẫn tới một kết quả thực nghiệm cụ thể ở Chương 3, để
điểm số không phải là nhận định chủ quan.

[[BANG|Ma trận rủi ro an toàn dịch vụ thư điện tử của hệ thống trước khi áp dụng biện pháp kiểm soát]]
|Mã|Mối đe doạ|Lỗ hổng bị khai thác|L|I|R|Mức|Căn cứ đo được trong lab|
|---|---|---|---|---|---|---|---|
|R1|Máy chủ bị lạm dụng phát thư rác, đưa vào danh sách chặn|`mynetworks` gồm cả dải lab; thiếu `reject_unauth_destination` hiệu lực|5|4|**20**|Nặng|Công cụ quét dịch vụ kết luận open relay trên cả hai MTA; `RCPT TO:` tới domain ngoài lab trả `250 2.1.5 Ok`|
|R2|Lộ lọt nội dung thư khi truyền|Cổng 25 và 143 hoạt động ở chế độ bản rõ|5|4|**20**|Nặng|Đọc nguyên văn `MAIL FROM`, `Subject` và số tài khoản từ gói tin bắt được; số dòng chứa STARTTLS trong capture bằng 0|
|R3|Đánh cắp thông tin đăng nhập SMTP/IMAP|Quảng bá `AUTH PLAIN LOGIN` trên kênh chưa mã hoá; `disable_plaintext_auth = no`|5|5|**25**|Nặng|Hai chuỗi Base64 giải mã ra đúng tên đăng nhập và mật khẩu; server đáp `235 2.7.0 Authentication successful`|
|R4|Giả mạo người gửi phục vụ lừa đảo|Không liên kết envelope sender với header sender|5|5|**25**|Nặng|Ba bức thư mạo danh đều được `queued` và `delivered to maildir`; ba bộ đếm header xác thực trong thư đều bằng 0|
|R5|Sửa nội dung thư trên đường truyền|Không có chữ ký toàn vẹn và không bắt buộc TLS|4|5|**20**|Nặng|Proxy trung gian thay số tài khoản trong thân thư dài 608 byte; nạn nhân nhận bản đã bị sửa|
|R6|Hạ cấp STARTTLS|Opportunistic TLS cho phép fallback về bản rõ|4|4|**16**|Cao|Dòng `250-STARTTLS` bị ẩn; phiên vẫn hoàn tất và thư vẫn được xếp hàng đợi|
|R7|Thu thập thông tin tiền tấn công|Lệnh `VRFY` bật, banner lộ tên và phiên bản phần mềm|5|2|**10**|TB|`VRFY giamdoc` trả `252` trên MTA Alpha; chuỗi chào `220 ... ESMTP Postfix (Ubuntu)`|
|R8|Tên miền bị giả mạo từ Internet thật|Chưa công bố SPF và DMARC|4|5|**20**|Nặng|Truy vấn `_dmarc` trả rỗng trước khi ban hành chính sách; bản ghi SPF chưa tồn tại|
|R9|Chữ ký hợp lệ của tên miền khác qua mặt bộ lọc|DKIM không ràng buộc `d=` với `Header From`|3|4|**12**|TB|Bức thư có SPF `pass` cho tên miền bên thứ ba nhưng `Header From` thuộc tên miền cần bảo vệ|

### Nhận xét về ma trận rủi ro và thứ tự xử lý

Hai kết luận rút ra từ bảng trên định hình toàn bộ trình tự triển khai phòng thủ ở Chương 3.

**Thứ nhất, R3 và R4 cùng đạt mức tối đa 25 và khuếch đại lẫn nhau.** Đánh cắp credential cho phép
kẻ tấn công sử dụng danh tính thật; khi đó mọi kiểm tra dựa trên nguồn gửi đều cho kết quả thuận.
Nói cách khác, một hệ thống chỉ bật SPF/DKIM/DMARC mà vẫn cho phép xác thực trên kênh rõ là một hệ
thống có lớp phòng thủ dễ bị vô hiệu hoá từ bên trong. Vì vậy biện pháp được ưu tiên số một không
phải là một cơ chế xác thực, mà là *ngắt khả năng xác thực ngoài TLS* (`smtpd_tls_auth_only`) kết
hợp bắt buộc mã hoá.

**Thứ hai, trước phòng thủ có tới 7/9 rủi ro vượt ngưỡng chấp nhận**, và phần lớn chúng không đòi
hỏi kỹ năng tấn công cao: các kịch bản R1 đến R4 đều thực hiện được bằng một dòng lệnh từ một máy
trạm thông thường trong mạng. Điều này khẳng định luận điểm của Chương 1: mức độ rủi ro của dịch vụ
email chủ yếu do *cấu hình và quy trình quản trị* quyết định, chứ không do việc thiếu công nghệ.

### Kết chương

Chương 2 đã phân tích bốn nhóm lỗ hổng cố hữu của SMTP, đi sâu vào cơ chế tấn công hạ cấp STARTTLS
, dạng tấn công đánh vào quá trình thương lượng chứ không đánh vào dữ liệu, và lượng hoá chín rủi
ro bằng thang 5×5 với căn cứ đo được. Ma trận cho thấy hai rủi ro nghiêm trọng nhất là đánh cắp
thông tin xác thực và giả mạo người gửi, đồng thời chỉ ra rằng việc xử lý chúng phải theo thứ tự:
bịt kênh xác thực bản rõ trước, sau đó mới đến ba cơ chế xác thực danh tính. Chương 3 sẽ hiện thực
hoá thứ tự đó trong một môi trường thực nghiệm cụ thể.


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
Internet thật, hệ quả này được phân tích đầy đủ ở mục 3.5.5.

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

[[BANG|Quy hoạch máy ảo, tài nguyên và dịch vụ, giá trị đọc trực tiếp từ cấu hình máy ảo và từ hệ điều hành khách]]
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
Đây là trạng thái giả lập một máy chủ "cho tiện trong nội bộ", tình huống phổ biến trong các sự cố
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

#### AT-01: Xác nhận chuyển tiếp mở

Kịch bản dùng hai phép đo độc lập để tránh phụ thuộc vào một công cụ: script chuyên dụng của Nmap
(`smtp-open-relay`, gồm 16 phép thử kết hợp nhiều cặp người gửi/người nhận khác nhau) và một kiểm
tra thủ công bằng swaks với người nhận thuộc tên miền ngoài lab. Kết quả:

[[HINH|h31-open-relay-truoc.png|Kết quả quét chuyển tiếp mở trên cả hai máy chủ thư ở giai đoạn chưa phòng thủ]]

Cả hai MTA đều được kết luận là open relay; phép kiểm tra thủ công xác nhận bằng mã `250 2.1.5 Ok`
cho một địa chỉ không thuộc bất kỳ tên miền nào của lab. Phép thử thứ ba, `VRFY giamdoc` trả về
`252 2.0.0 giamdoc`, cho thấy máy chủ còn đóng vai trò một oracle cho phép kẻ tấn công liệt kê
tài khoản hợp lệ, phục vụ việc soạn thư lừa đảo trúng đích.

#### AT-02: Nghe lén nội dung thư trên kênh bản rõ

Máy chủ được đặt ở `smtpd_tls_security_level = none`, một bức thư chứa số tài khoản ngân hàng được
gửi đi trong khi máy tấn công thu gói ở cổng 25. Toàn bộ hội thoại xuất hiện nguyên văn, bao gồm cả
phần thân thư:

[[HINH|h16-pcap-clear.png|Trích nội dung gói tin bắt được ở cổng 25: envelope, tiêu đề và số tài khoản ngân hàng đọc được trực tiếp]]

Điểm đáng chú ý trong cùng phép đo: bộ đếm số dòng chứa từ khóa `STARTTLS` trong toàn bộ capture
bằng **0**, tức không có bất kỳ nỗ lực mã hoá nào diễn ra, khác với trường hợp hạ cấp ở AT-06, nơi
nỗ lực mã hoá có tồn tại nhưng bị chặn mất.

#### AT-03: Đánh cắp thông tin xác thực SMTP

Ở cổng 587 khi chưa bật `smtpd_tls_auth_only`, máy chủ quảng bá `250-AUTH PLAIN LOGIN` ngay trên
kênh bản rõ. Kẻ tấn công thu được hai chuỗi Base64 trong phiên và giải mã bằng một lệnh:

[[HINH|h17-credential.png|Hai chuỗi Base64 thu được từ phiên AUTH LOGIN và kết quả giải mã tương ứng]]

Máy chủ xác nhận `235 2.7.0 Authentication successful` rồi chấp nhận thư. Ở thời điểm này, kẻ tấn
công không còn là người ngoài: họ có quyền gửi đúng danh tính của nạn nhân từ chính hạ tầng được uỷ
quyền, tức là vượt qua mọi kiểm tra dựa trên nguồn gửi.

#### AT-04 và AT-05: Giả mạo Header From và BEC trong cùng tên miền

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
nguồn là thật. Ba bộ đếm header xác thực trong tệp thư đều bằng 0, hệ thống không hề thực hiện bất
kỳ kiểm tra định danh nào trước khi phát thư.

[[HINH|h19-inbox-0.png|Hộp thư nạn nhân sau AT-04: ba bộ đếm Authentication-Results, Received-SPF và DKIM-Signature đều bằng 0]]

AT-05 lặp lại đúng kỹ thuật với hai địa chỉ *trong cùng tên miền Alpha* (`postmaster@` và
`giamdoc@`) và cả hai đều được chấp nhận, mô phỏng đúng kịch bản BEC nội bộ, kịch bản mà người dùng
được đào tạo nhận biết "người lạ" sẽ không phát hiện ra.

#### AT-06: Hạ cấp STARTTLS kết hợp sửa nội dung trên đường truyền

Đây là kịch bản phức tạp nhất và đòi hỏi viết một proxy trung gian riêng (`attacks/strip_starttls.py`)
hoạt động ở cổng 2525 trên vm-atk: nhận kết nối từ máy trạm, tự kết nối tới MTA, chuyển tiếp hai
chiều nhưng loại bỏ dòng `250-STARTTLS` trong phản hồi `EHLO`, ghi lại cặp thông tin đăng nhập và
thay số tài khoản trong thân thư.

Để loại trừ nghi vấn "kết quả có được là do cấu hình sai", phép đo được tổ chức thành một cặp có đối
chứng:

[[BANG|Cặp phép đo có đối chứng của kịch bản hạ cấp STARTTLS (AT-06)]]
| Bước | Phép đo | Kết quả thực tế |
|---|---|---|
| [0] | `EHLO` trực tiếp cổng 587, không qua proxy | Phản hồi **có** `250-STARTTLS`, điều kiện cần được xác lập |
| [1] | swaks yêu cầu TLS đi thẳng | `235 2.7.0 Authentication successful`, thư được xếp hàng đợi, kênh TLS thật hoạt động |
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

#### D-01: Đóng chuyển tiếp mở và siết chính sách truy cập

[[HINH|h11-relay-dong.png|Chuỗi restriction sau khi ban hành: mynetworks chỉ còn loopback, bổ sung kiểm tra recipient và policy service]]

Ba điểm kỹ thuật đáng lưu ý. Thứ nhất, `mynetworks` được thu về đúng ba dải loopback; mọi quyết định
chấp nhận thư từ nay dựa trên xác thực hoặc trên chính sách người nhận, không dựa vào vị trí mạng.
Thứ hai, `smtpd_helo_required = yes` và `disable_vrfy_command = yes` loại bỏ cả hai kênh thu thập
thông tin của rủi ro R7. Thứ ba, và là điểm sư phạm quan trọng nhất, **thứ tự** trong chuỗi
restriction quyết định hiệu lực của các lớp sau: `permit_mynetworks` đứng trước
`reject_unauth_destination` và trước `check_policy_service`, nên chỉ cần `mynetworks` còn chứa dải
lab thì bộ lọc SPF *không bao giờ được gọi*. Đây là lỗi cấu hình kinh điển và lab đo được nó một
cách tường minh.

#### D-02: Bắt buộc TLS và ngắt khả năng xác thực ngoài mã hoá

[[HINH|h09-tls-batbuoc.png|Trạng thái tham số TLS của Postfix và Dovecot sau khi ban hành chính sách bắt buộc mã hoá]]

Cấu hình được đặt ở ba mức khác nhau cho ba vai trò: phía nhận dùng `encrypt` (buộc phiên vào TLS),
phía gửi dùng `verify` (buộc và kiểm chứng chứng chỉ theo CA nội bộ), và `smtpd_tls_auth_only = yes`
khiến máy chủ *chỉ quảng bá* khả năng xác thực khi phiên đã nằm trong TLS. Ở tầng giao thức,
SSLv2/SSLv3/TLSv1/TLSv1.1 bị loại bỏ; phía Dovecot đặt `ssl = required` và
`disable_plaintext_auth = yes`.

Hai tác dụng quan sát được ngay sau khi nạp cấu hình, rất thuận lợi cho trình diễn: danh sách tính
năng trả về từ `EHLO` trên kênh bản rõ **không còn** dòng `250-AUTH`, và cũng mất luôn `VRFY`.

#### D-03: Bộ lọc SPF và công tắc thực thi

[[HINH|h12-spf-bo-loc.png|Cấu hình bộ lọc SPF: công tắc thực thi, chính sách từ chối và vị trí trong chuỗi restriction]]

Ba thành phần phải khớp nhau: bản ghi TXT được công bố trên DNS, dòng khai báo service trong
`master.cf`, và `check_policy_service unix:private/policyd-spf` trong chuỗi restriction của phía
nhận. Bộ lọc được đặt **sau** `reject_unauth_destination` để không biến máy chủ thành relay mở cho
thư được policy cho phép.

Điểm dễ gây nhầm lẫn nhất trong toàn bộ đề tài nằm ở tham số `TestOnly`. Trang man của gói
`postfix-policyd-spf-python` định nghĩa: *"set TestOnly = 0. If you want test operation with no
header added"*, tức giá trị `0` mới là chế độ thử không tác động, còn **`TestOnly = 1` là chế độ
thực thi**. Rất nhiều tài liệu hướng dẫn trên mạng diễn đạt ngược điều này. Nhóm phải đọc trực tiếp
trang man của gói đang cài để quyết định giá trị cấu hình.

[[HINH|h13-spf-dns.png|Hai bản ghi SPF được công bố và trạng thái bốn dịch vụ trên máy chủ phòng thủ]]

#### D-04: Sinh khoá RSA, công bố bản ghi và kích hoạt bộ lọc DKIM

[[HINH|h10-dkim-key.png|Cấu hình OpenDKIM phía ký: cặp khoá 2048 bit, selector, chế độ sv và danh sách máy nội bộ]]

Khoá được sinh bằng `opendkim-genkey -b 2048 -s mail`, khoá riêng đặt tại `/etc/dkimkeys` với quyền
chỉ người dùng `opendkim` đọc được, khoá công khai được chuyển thành bản ghi TXT tại
`mail._domainkey.<domain>` và nạp vào vùng quản trị. Hai chi tiết dễ sai: tên khoá trong
`opendkim.conf` là `InternalHosts` chứ **không phải** `TrustedHosts` (một khoá không tồn tại trong
OpenDKIM), và dòng `Socket` trong tệp cấu hình gói dùng ký tự tab nên các phép biến đổi văn bản dựa
vào khoảng trắng sẽ âm thầm không khớp.

#### D-05: Chính sách DMARC p=reject và phạm vi áp dụng

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
đi qua bình thường trong khi các kịch bản giả mạo vẫn bị chặn, hai mục tiêu đạt được đồng thời.

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
|T5|Thư hợp lệ: đúng tài khoản, có TLS, qua cổng 587|`250 2.0.0 Ok: queued`|`250 2.0.0 Ok: queued`|Không chặn, điều kiện phủ định|

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
|Alpha → Beta, thư hợp lệ|`pass`|`fail`, milter không lấy được khoá (mục 3.5.5)|`pass`|Có|
|Beta → Alpha, thư hợp lệ|`pass`|`fail`, như trên|`pass (p=reject dis=none)`|Có|
|Giả mạo từ máy ngoài lab|`fail`|không có chữ ký|`fail`|Không, `550 5.7.23`|
|Tên miền bên thứ ba, Header From lệch|`pass` cho `darkside.test`|không có chữ ký|`fail` do alignment|Không, `550 5.7.1`|

Hai dòng đầu cho thấy đúng tính chất "đủ một cơ chế là qua" của DMARC: `dmarc=pass` đạt được nhờ
SPF alignment, còn DKIM chưa đóng góp được trong môi trường lab. Đây là điểm cần được nói rõ thay vì
chỉ trình bày kết quả `pass`.

#### Kiểm tra mã hoá và khả năng chống hạ cấp

[[HINH|h28-tls-rates.png|Kiểm tra chứng chỉ, thương lượng TLS và phản ứng của máy chủ khi bị hạ cấp]]

Ba kết quả trong phép đo này. Thứ nhất, xác minh chứng chỉ bằng đúng CA của lab trả
`Verify return code: 0 (ok)` và phiên thương lượng ở TLSv1.3 trên cả cổng 25, 587 và 993. Thứ hai,
thử gửi thông tin đăng nhập trên kênh chưa mã hoá bị từ chối bằng mã `530 Must issue a STARTTLS
command first`. Thứ ba, phép đo quan trọng nhất, khi buộc phiên đi qua proxy ẩn `250-STARTTLS`
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
`openssl dgst -sha256 -verify` trả `Verified OK`. Chuỗi khoá riêng, chữ ký, khoá công khai là hợp
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
quy nội bộ để mọi thành phần, kể cả libunbound, có cùng một điểm hỏi.

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
lớp cuối cùng, không chặn nhầm người dùng hợp lệ, là lớp thường bị bỏ qua nhất trong các tài liệu
hướng dẫn triển khai.

### Kết chương

Chương 3 đã hoàn thành cả hai vế của phương pháp thực nghiệm. Ở vế tấn công, sáu kịch bản chứng minh
tính khả thi của bốn nhóm lỗ hổng bằng số liệu nguyên văn: hai máy chủ đều open relay, nội dung thư
và cặp thông tin đăng nhập đọc được từ gói tin, ba bức thư giả mạo được phát vào hộp thư nạn nhân
với toàn bộ bộ đếm xác thực bằng 0, và một cuộc tấn công hạ cấp vừa lấy được credential vừa sửa được
số tài khoản trong thân thư. Ở vế phòng thủ, bốn lớp được ban hành bằng script và được kiểm chứng
bằng cách phát lại đúng các tấn công cũ: năm trên năm tình huống cho kết quả khớp kỳ vọng, trong đó
tình huống T4 chứng minh vai trò không thể thay thế của DMARC alignment và tình huống T5 chứng minh
hệ thống không chặn nhầm. Hai phát hiện giá nhất của toàn bộ đề tài, công tắc `TestOnly` mang ngữ
nghĩa ngược với tên gọi, và phạm vi áp dụng milter theo từng dịch vụ, đều chỉ xuất hiện ở bước kiểm
chứng, không xuất hiện ở bước cấu hình.


# KẾT LUẬN

**Các kết quả đạt được.** Đề tài đã hoàn thành cả bốn mục tiêu đặt ra ở phần mở đầu, và mỗi mục
tiêu đều có một phép đo kèm theo.

Về cơ sở lý thuyết, báo cáo đã trình bày đầy đủ kiến trúc MUA–MTA–MDA, trình tự hội thoại SMTP
theo RFC 5321, quan hệ phụ thuộc giữa định tuyến thư và DNS, cũng như nguyên lý hoạt động của bốn
cơ chế STARTTLS, SPF, DKIM và DMARC kèm giới hạn của từng cơ chế. Điểm phân biệt của phần lý thuyết
này là cách tiếp cận theo câu hỏi: mỗi cơ chế chỉ trả lời một câu hỏi xác định, nên không cơ chế
nào thay thế được cơ chế khác.

Về phân tích lỗ hổng, chín rủi ro được lượng hoá theo thang 5×5 với căn cứ đo được. Hai rủi ro ở
mức tối đa 25 là đánh cắp thông tin xác thực và giả mạo người gửi; bảy trên chín rủi ro vượt ngưỡng
chấp nhận trước khi phòng thủ. Phân tích chuyên sâu về tấn công hạ cấp STARTTLS cho thấy đây là
dạng tấn công vào quá trình thương lượng chứ không vào dữ liệu, vì vậy nó không để lại dấu vết nào
trong nhật ký ở cả hai đầu.

Về triển khai, hệ thống gồm năm máy ảo Ubuntu Server 24.04.5 LTS trên mạng host-only VMnet2, với
hai tổ chức thư điện tử độc lập (`congtyA.test` và `congtyB.test`), một máy chủ DNS authoritative-only
quản trị ba vùng thuận và một vùng ngược, một CA nội bộ cấp chứng chỉ cho hai MTA, và một máy trạm
tấn công có proxy trung gian tự viết. Toàn bộ nằm trong 21 script chạy lại được và ba mốc snapshot.

Về thực nghiệm tấn công, sáu kịch bản đều thành công ở trạng thái chưa phòng thủ, với số liệu
nguyên văn: hai máy chủ đều được kết luận là open relay qua 16/16 phép thử; nội dung thư, tiêu đề
và số tài khoản ngân hàng đọc trực tiếp từ gói tin với số dòng chứa STARTTLS bằng 0; cặp thông tin
đăng nhập giải mã được từ hai chuỗi Base64 và được máy chủ xác nhận; ba bức thư giả mạo đều được
xếp hàng đợi và phát vào hộp thư nạn nhân với ba bộ đếm header xác thực cùng bằng 0; và kịch bản hạ
cấp vừa lấy được credential vừa thay đổi được số tài khoản trong thân thư 608 byte trước khi tới
tay người nhận.

Về kiểm chứng phòng thủ, phát lại đúng năm tình huống cho kết quả **5/5 khớp kỳ vọng**: chuyển tiếp
bị từ chối bằng `554 5.7.1 Relay access denied`; hai kịch bản giả mạo envelope sender bị chặn bằng
`550 5.7.23 … SPF fail - not authorized` ngay tại lệnh `RCPT`; tình huống lệch tên miền bị chặn bằng
`550 5.7.1 rejected by DMARC policy for congtyA.test`; và thư hợp lệ vẫn được xếp hàng đợi. Cùng
với đó, công cụ quét dịch vụ đảo kết luận sang "không phải open relay", xác minh chứng chỉ trả
`Verify return code: 0 (ok)` trên TLSv1.3, thử đăng nhập ngoài TLS bị trả `530 Must issue a STARTTLS
command first`, và nỗ lực hạ cấp kết thúc bằng mã thoát 28 thay vì âm thầm gửi bản rõ.

**Hai kết quả đáng chú ý nhất về mặt nghiệp vụ.** Thứ nhất, tình huống T4 chứng minh vai trò không
thể thay thế của DMARC: kẻ tấn công gửi từ một tên miền có SPF đúng của chính mình nên SPF không
phát hiện được, và chỉ có alignment của DMARC mới phát hiện `Header From` thuộc tên miền khác. Đây
chính là luận điểm trung tâm của đề tài được kiểm chứng bằng số liệu. Thứ hai, tình huống T5 chứng
minh hệ thống không chặn nhầm: sau khi siết cả bốn lớp, người dùng hợp lệ vẫn gửi được thư ở cả hai
chiều. Hai tính chất "chặn được tấn công" và "không chặn nhầm người dùng" đạt được đồng thời chỉ sau
khi phạm vi áp dụng milter được giới hạn theo từng dịch vụ.

**Ưu điểm của giải pháp đã triển khai.** Toàn bộ dựa trên phần mềm mã nguồn mở chuẩn công nghiệp,
không phụ thuộc nhà cung cấp. Cấu hình tuân thủ các RFC tương ứng nên có thể chuyển trực tiếp sang
môi trường khai thác thật với một tên miền đã đăng ký. Mô hình phòng thủ nhiều lớp thể hiện rõ tính
bù trừ: ba trong bốn lớp có thể độc lập fail mà thư hợp lệ vẫn được phát, trong khi chỉ cần một lớp
chặn đúng chỗ là tấn công thất bại. Mọi biện pháp đều được ban hành bằng script và được xác nhận
bằng phép đọc cấu hình thực tế sau khi nạp lại, nên kết quả tái lập được; một thành viên bất kỳ có
thể dựng lại toàn bộ lab trong khoảng một giờ từ snapshot G1.

**Những điểm còn giới hạn của mô hình.** Bốn giới hạn sau thuộc về phạm vi và hạ tầng của phòng thí
nghiệm, cần được nêu rõ để đánh giá đúng mức khả năng áp dụng ra môi trường thật.

* Bộ thẩm định DKIM của máy chủ nhận không tự truy vấn được khoá công khai trong môi trường cô lập,
  do OpenDKIM liên kết với thư viện phân giải đệ quy riêng và mạng lab không có resolver đệ quy.
  Chuỗi khoá, chữ ký, bản ghi DNS đã được kiểm chứng hợp lệ bằng một công cụ độc lập cài đặt đúng
  trình tự RFC 6376, nên đây là giới hạn của hạ tầng phân giải chứ không phải của định dạng bản ghi
  hay của thuật toán chữ ký. Hệ quả quan sát được trên header là `dkim=fail reason="key not found in
  DNS"` trong khi `dmarc=pass` vẫn đạt được nhờ SPF alignment.
* Chống hạ cấp hiện dựa trên việc cả hai đầu cùng đặt chế độ bắt buộc TLS. Với thư đến từ một MTA
  bên ngoài chưa cấu hình tương ứng, opportunistic TLS vẫn có thể bị hạ cấp ở chặng đó; các chuẩn
  MTA-STS và DANE là lời giải triệt để nhưng cần hạ tầng HTTPS công cộng và DNSSEC.
* Báo cáo tổng hợp DMARC đã được khai báo đúng qua tham số `rua` và alias hộp thư đã tồn tại, nhưng
  lab chưa xây dựng bộ phân tích tệp XML báo cáo, nên chưa khai thác được giá trị giám sát của cơ
  chế này.
* Chưa bổ sung các lớp lọc nội dung và tần suất: greylisting, rate limiting, danh sách chặn DNS
  công cộng và bộ quét mã độc tệp đính kèm.

**Bài học kinh nghiệm thu được.** Năm bài học dưới đây rút trực tiếp từ quá trình thực nghiệm.

* Một hệ thống "chạy được" khác hẳn một hệ thống "được kiểm chứng". Ba lỗi nghiêm trọng nhất tìm
  thấy đều xuất hiện ở bước *sau* khi cấu hình đã chạy: chính sách DMARC chặn nhầm người dùng hợp
  lệ vì áp dụng cho cả cổng đẩy thư; bộ lọc SPF không bao giờ được gọi vì một từ khoá cho phép đứng
  trước nó trong chuỗi restriction; và công tắc thực thi của bộ lọc SPF mang ngữ nghĩa ngược với tên
  gọi. Nếu chỉ dựng lab rồi chụp ảnh tệp cấu hình, cả ba đều lọt.
* Không nên suy ra ngữ nghĩa tham số từ tên gọi. Trường hợp `TestOnly` là minh chứng rõ nhất: cách
  an toàn là đọc trang man của đúng gói đang cài đặt trên hệ thống, thay vì đọc tài liệu thứ cấp.
* Công cụ kiểm chứng phải dùng đúng đường phân giải của hệ thống bị kiểm tra. Một truy vấn thủ công
  thành công không đồng nghĩa với việc ứng dụng thành công, vì hai bên có thể dùng hai resolver khác
  nhau; chỉ có phép đo ở tầng gói tin mới phân biệt được hai khả năng.
* Trong Postfix, thứ tự là nội dung. Vị trí của một từ khoá trong danh sách restriction quan trọng
  ngang bản thân từ khoá đó; trong chuỗi milter, bộ thẩm định DMARC buộc phải xếp sau bộ kiểm DKIM
  vì nó đọc kết quả do bộ trước đặt vào ngữ cảnh riêng của cùng thông điệp.
* Phòng thủ nhiều lớp không phải là bật đồng thời bốn tuỳ chọn, mà là hiểu lớp nào trả lời câu hỏi
  nào. Khi biết rõ câu hỏi, người quản trị mới đặt đúng cấu hình vào đúng chỗ và diễn giải đúng kết
  quả thu được.

**Hướng phát triển của đề tài.** Bốn hướng mở rộng được xác định theo thứ tự ưu tiên.

* Thứ nhất, bổ sung một resolver đệ quy nội bộ trong lab, hoặc bật phân giải đệ quy có kiểm soát
  trên máy chủ DNS hiện có, hoặc chạy một resolver cục bộ làm điểm hỏi duy nhất cho mọi tiến trình ,
  để bộ thẩm định DKIM tự lấy được khoá và `dkim=pass` trở thành kết quả đo được thay vì phải kiểm
  chứng bằng công cụ ngoài.
* Thứ hai, triển khai MTA-STS kèm TLS-RPT và DANE TLSA trên nền DNSSEC, nhằm đóng triệt để lỗ hổng
  hạ cấp giữa các tổ chức.
* Thứ ba, khai thác báo cáo DMARC: nhận và phân tích báo cáo tổng hợp từ `rua`, dựng bảng theo dõi
  số lượng thư bị chặn theo ngày và theo nguồn gửi.
* Thứ tư, mở rộng sang các chuẩn bổ trợ, ARC cho chuỗi chuyển tiếp, BIMI cho biểu tượng đã xác thực
 , và tích hợp thêm bộ lọc nội dung, quét mã độc, greylisting cùng một webmail có mã hoá đầu cuối
  để hoàn thiện bức tranh vận hành thực tế.

Nhìn chung, kết quả thực nghiệm khẳng định luận điểm ban đầu: an toàn dịch vụ thư điện tử không đạt
được bằng một công nghệ đơn lẻ, mà bằng một chuỗi phối hợp chặt chẽ giữa định tuyến (DNS), mã hoá
đường truyền (STARTTLS), uỷ quyền nguồn gửi (SPF), toàn vẹn nội dung (DKIM) và căn chỉnh định danh
(DMARC), trong đó phần khó nhất và cũng quyết định nhất nằm ở cấu hình và quy trình kiểm chứng,
không nằm ở bản thân các thuật toán.


# TÀI LIỆU THAM KHẢO

**Chuẩn Internet (RFC) của IETF**

[1] J. Klensin, "Simple Mail Transfer Protocol", RFC 5321, IETF, tháng 10 năm 2008. https://datatracker.ietf.org/doc/html/rfc5321

[2] P. Resnick, "Internet Message Format", RFC 5322, IETF, tháng 10 năm 2008. https://datatracker.ietf.org/doc/html/rfc5322

[3] P. Hoffman, "SMTP Service Extension for Secure SMTP over Transport Layer Security", RFC 3207, IETF, tháng 2 năm 2002. https://datatracker.ietf.org/doc/html/rfc3207

[4] M. Wong, W. Schlitt, "Sender Policy Framework (SPF) for Authorizing Use of Domains in Email, Version 1", RFC 7208, IETF, tháng 4 năm 2014. https://datatracker.ietf.org/doc/html/rfc7208

[5] D. Crocker, T. Hansen, M. Kucherawy, "DomainKeys Identified Mail (DKIM) Signatures", RFC 6376, IETF, tháng 9 năm 2011. https://datatracker.ietf.org/doc/html/rfc6376

[6] M. Kucherawy, E. Zwicky, "DMARC: Based Message Authentication, Reporting, and Conformance", RFC 7489, IETF, tháng 1 năm 2015. https://datatracker.ietf.org/doc/html/rfc7489

[7] N. Margolis, M. Gulbrandsen, "SMTP MTA Strict Transport Security (MTA-STS)", RFC 8461, IETF, tháng 10 năm 2018. https://datatracker.ietf.org/doc/html/rfc8461

[8] V. Dukhovni, W. Hardaker, "SMTP Security via Opportunistic DNS-Based Authentication of Named Entities (DANE) Transport Layer Security", RFC 7672, IETF, tháng 10 năm 2015. https://datatracker.ietf.org/doc/html/rfc7672

[9] P. Kitterman (ed.), "SMTP TLS Reporting", RFC 8460, IETF, tháng 10 năm 2018. https://datatracker.ietf.org/doc/html/rfc8460

[10] M. Crispin, "INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1", RFC 3501, IETF, tháng 3 năm 2003. https://datatracker.ietf.org/doc/html/rfc3501

[11] D. Thaler (ed.), "Reserved Top-Level DNS Names", RFC 6761, IETF, tháng 2 năm 2013. https://datatracker.ietf.org/doc/html/rfc6761

**Tài liệu của Học viện**

[12] Học viện Công nghệ Bưu chính Viễn thông, *Giáo trình học phần An toàn mạng (INT1482)*, Khoa An toàn thông tin, Hà Nội.

**Tài liệu kỹ thuật của các dự án mã nguồn mở**

[13] W. Venema, Postfix Documentation Project, "Postfix Architecture Overview", "Postfix BASIC Configuration" và trang man `postconf(5)`, `smtpd(8)`, `master(5)`, https://www.postfix.org/documentation.html, truy cập tháng 10 năm 2026.

[14] Dovecot Oy, "Dovecot v2.3 Configuration" và trang man `dovecot.conf(5)`, https://doc.dovecot.org/, truy cập tháng 10 năm 2026.

[15] Internet Systems Consortium, "BIND 9.18 Administrator Reference Manual", các mục `named.conf.options`, `recursion`, `allow-recursion`, https://bind9.readthedocs.io/, truy cập tháng 10 năm 2026.

[16] The Trusted Domain Project, "OpenDKIM Filter v2.11.0", trang man `opendkim.conf(5)`, `opendkim-genkey(8)`, `opendkim-testkey(8)`, http://www.opendkim.org/, truy cập tháng 10 năm 2026.

[17] The Trusted Domain Project, "OpenDMARC", trang man `opendmarc.conf(5)`, http://www.trusteddomain.org/opendmarc/, truy cập tháng 10 năm 2026.

[18] W. ten Bruijn, "postfix-policyd-spf-python", trang man `policyd-spf.conf(5)`, mục `TestOnly` và `Mail_From_reject`, https://launchpad.net/postfix-policyd-spf-python, truy cập tháng 10 năm 2026.

[19] NLnet Labs, "Unbound, documentation" (thư viện phân giải libunbound), https://nlnetlabs.nl/projects/unbound/documentation/, truy cập tháng 10 năm 2026.

[20] J. Jetmore, "swaks, The Swiss Army Knife of SMTP", tài liệu tham số lệnh bản 20240103.0, https://www.jetmore.org/john/code/swaks/, truy cập tháng 10 năm 2026.

[21] Nmap Project, "Nmap Scripting Engine: smtp-open-relay", "smtp-commands", https://nmap.org/nsedoc/, truy cập tháng 10 năm 2026.

[22] Wireshark Foundation, "Wireshark User's Guide: Analyzing Application Layer Protocols", https://www.wireshark.org/docs/wsug_html_chunked/, truy cập tháng 10 năm 2026.

[23] The OpenSSL Project, "openssl-s_client(1)", "openssl-x509(1)", "openssl-dgst(1)", https://www.openssl.org/docs/, truy cập tháng 10 năm 2026.

**Hướng dẫn triển khai và tài liệu tham khảo nghiệp vụ**

[24] US Cybersecurity and Infrastructure Security Agency (CISA), "Best Practices for Email Security", 2020. https://www.cisa.gov/

[25] Messaging, Malware and Mobile Anti-Abuse Working Group (M3AAWG), "Email Fraud and Abuse, DNS-based Controls", tài liệu dành cho nhà vận hành. https://www.m3aawg.org/

[26] Google LLC, "Ensure your SPF, DKIM and DMARC records are set up correctly", Google Workspace Administrator Help. https://support.google.com/a/

*Ghi chú về tính trung thực của số liệu.* Toàn bộ mã phản hồi SMTP, dòng nhật ký, giá trị băm và số
đo trong báo cáo được trích nguyên văn từ các tệp bằng chứng sinh ra trong phiên thực nghiệm ngày
18/10/2026 trên năm máy ảo của nhóm, lưu tại thư mục `evidence/` kèm mã tra SHA-256 (xem Phụ lục A).
Không có kết quả nào được ước lượng hay tái tạo lại.


# PHỤ LỤC

**Phụ lục A. Danh mục bằng chứng thực nghiệm.** Toàn bộ số liệu trong báo cáo truy nguyên về 85 tệp
bằng chứng thu từ năm máy ảo. Mỗi tệp mang dấu thời gian UTC của lượt chạy, và danh mục đầy đủ kèm
mã tra SHA-256 được lưu trong `evidence/evidence-checksums.txt`.

[[HINH|h30-evidence.png|Thống kê thư mục bằng chứng theo từng máy ảo và chín dòng đầu của tệp mã tra SHA-256]]

[[BANG|Nhóm bằng chứng chính theo từng giai đoạn thực nghiệm]]
|Giai đoạn|Máy tạo ra|Nhóm tệp|Nội dung|
|---|---|---|---|
|1. Nền tảng|vm-dns, vm-mail1, vm-mail2|`dns/10-dns-dig.txt`, `mail1/20-mail-alpha.txt`, `mail2/20-mail-beta.txt`|Kết quả phân giải và trạng thái cấu hình ban đầu của hai MTA ở chế độ chưa phòng thủ|
|2. Tấn công|vm-atk, vm-client, vm-mail1, vm-mail2|`atk/at01…at06`, `client/at03-*`, `client/at06-*`, `mail1/at02-*`, `mail2/at04-inbox-*`|Bản ghi từng kịch bản: quét relay, nghe lén kèm tệp pcap, đánh cắp credential, giả mạo header, hạ cấp qua proxy|
|3. Phòng thủ|vm-mail1, vm-mail2, vm-dns|`mail1/d01…d05b`, `mail2/d01…d05b`, `dns/d04b-dkim-publish-beta.txt`|Đầu ra của từng bước ban hành cấu hình kèm phần tự kiểm tra bằng `postconf -n`|
|4. Kiểm chứng|vm-dns, vm-atk, vm-client, hai MTA|`dns/v01-dns-records.txt`, `atk/v03-replay.txt`, `atk/v03-T1…T5`, `client/v02-happy-path.log`, `client/v04-tls-and-downgrade.txt`, `vm-mail2/v05-auth-results-ketoan.txt`|Bảng đối chiếu trước/sau, header xác thực của thư đến theo cả hai chiều, kết quả kiểm tra TLS và chống hạ cấp|

**Phụ lục B. Danh mục script của đề tài.** Hai mươi mốt tệp được tổ chức theo vai trò; mọi lệnh trong
báo cáo đều gọi trực tiếp từ các tệp này, không có thao tác tay không được ghi lại.

[[BANG|Cấu trúc mã nguồn của phòng thí nghiệm]]
|Thư mục|Tệp|Vai trò|
|---|---|---|
|`install/`|`00-apt.sh`, `00-base.sh`, `10-dns.sh`, `20-mail.sh`|Cài gói, cấu hình mạng tĩnh và DNS, dựng hai MTA ở trạng thái ban đầu có chủ đích|
|`attacks/`|`at01-open-relay.sh` … `at07-spf-pass-dmarc-fail.sh`, `strip_starttls.py`, `atk-run-strip-proxy.sh`|Bảy kịch bản tấn công và proxy trung gian phục vụ phép đo hạ cấp|
|`defense/`|`d00-aliases.sh` … `d05b-dmarc-enforce.sh`, `dns-add-record.sh`|Tám bước ban hành phòng thủ, mỗi bước tự kiểm tra sau khi nạp lại dịch vụ|
|`verify/`|`v00-preflight.sh` … `v05-auth-results.sh`, `smtp-probe.py`, `parse-headers.py`, `dkim-check.py`|Kiểm tra điều kiện tiền đề, phát lại tấn công, đo TLS và kiểm chứng chữ ký DKIM độc lập|
|`docs/`|`01-runbook-chay-lab.md`, `03-test-cases.md`, `04-risk-matrix.md`, `05-danh-sach-bang-chung.md`|Quy trình chạy theo vai trò, kế hoạch kiểm thử, ma trận rủi ro và danh mục bằng chứng|
|`bao-cao/lenh-chup/`|`vm-dns.sh`, `vm-mail1.sh`, `vm-mail2.sh`, `vm-atk.sh`, `vm-client.sh`|Tập hợp các lệnh dùng để chụp từng ảnh bằng chứng trong báo cáo, gọi được lại|

**Phụ lục C. Cách tái lập kết quả.** Trình tự dưới đây cho phép một người khác dựng lại toàn bộ
phòng thí nghiệm và thu được đúng các số liệu trong báo cáo.

```
# 0. Vat chu Windows: kiem tra nam may ao va ba moc snapshot
"C:\Program Files (x86)\VMware\VMware Workstation\vmrun" list
"C:\Program Files (x86)\VMware\VMware Workstation\vmrun" listSnapshots <duong-dan>\<ten>\.vmx

# 1. Dong bo ma nguon len ca nam may ao (da chay o Giai doan 0b)
bash install/00-apt.sh                       # moi may: cai goi theo vai tro
bash install/00-base.sh 10.30.0.20 mail1.congtyA.test vm-mail1
bash install/10-dns.sh                       # vm-dns
bash install/20-mail.sh alpha                # vm-mail1
bash install/20-mail.sh beta                 # vm-mail2
bash verify/v00-preflight.sh                 # kiem 5 IP song va cong 25/587/143

# 2. Giai doan tan cong (snapshot G2 = trang thai trong Chuong 3 muc 3.3)
bash attacks/at01-open-relay.sh              # vm-atk
bash attacks/at02-cleartext-sniff.sh         # vm-mail1 + vm-atk
bash attacks/at03-credential-theft.sh        # vm-client
bash attacks/at04-spoof-header.sh            # vm-atk
bash attacks/at05-spoof-own-domain.sh        # vm-atk
bash attacks/atk-run-strip-proxy.sh start && bash attacks/at06-starttls-strip.sh

# 3. Giai doan phong thu (snapshot G3)
bash defense/d01-close-relay.sh              # ca hai MTA
bash defense/d02a-ca.sh && bash defense/d02b-tls.sh encrypt
bash defense/d03-spf-enforce.sh && bash defense/d03b-spf-publish.sh
bash defense/d04a-dkim.sh && bash defense/d04b-dkim-publish.sh
bash defense/d05a-dmarc-publish.sh && bash defense/d05b-dmarc-enforce.sh

# 4. Kiem chung
bash verify/v01-dns-records.sh               # vm-dns
bash verify/v03-replay-attacks.sh            # vm-atk   -> 5/5 KHOP
bash verify/v02-happy-path.sh                # vm-client
bash verify/v04-tls-and-downgrade.sh         # vm-client
bash verify/v05-auth-results.sh ketoan       # vm-mail2
```

Lưu ý về thứ tự: `d01-close-relay.sh` đặt lại toàn bộ danh sách restriction, nên nếu chạy lại bước
này **sau** `d03-spf-enforce.sh` thì dòng `check_policy_service` sẽ bị xoá và bộ lọc SPF mất hiệu
lực. Ràng buộc thứ tự này được ghi ngay trong chú thích của tệp `d01` và là một trong ba lỗi cấu
hình mà chỉ bước kiểm chứng mới phát hiện ra.

**Phụ lục D. Quy ước đặt tên ảnh trong báo cáo.** Mỗi ảnh được chụp từ một cửa sổ console duy nhất,
chứa đúng một lệnh đã nêu ở phần chữ, và lệnh đó được lưu lại trong `bao-cao/lenh-chup/` để ảnh chụp
có thể tái tạo. Ảnh mang tên `h01-topo.png` là sơ đồ thiết kế; các ảnh còn lại là ảnh chụp màn hình
đầu ra thật của hệ thống tại thời điểm ghi trong chú thích.
