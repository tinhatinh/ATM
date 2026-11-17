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
