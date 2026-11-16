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
đã phân tích ở mục 1.2.2. Máy chủ nhận không có nghĩa vụ — và trong SMTP nguyên thủy là không có
khả năng — kiểm tra xem địa chỉ hiển thị trong `From:` có thuộc quyền sử dụng của bên đang gửi hay
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

* Nội dung thư và tệp đính kèm — bao gồm hợp đồng, hồ sơ tài chính, thông tin khách hàng.
* Danh tính người gửi, người nhận, tiêu đề và thời gian gửi — đủ để dựng lại sơ đồ quan hệ của một
  tổ chức (metadata analysis).
* Thông tin đăng nhập khi MUA xác thực với MTA qua kênh chưa mã hoá. Trường hợp này nghiêm trọng
  hơn hai trường hợp trên, vì cơ chế `AUTH PLAIN` và `AUTH LOGIN` chỉ là mã hoá Base64 — một phép
  biến đổi mã hoá không khoá, giải mã được bằng một lệnh duy nhất.

**Hệ quả dây chuyền của việc mất credential.** Khác với các lỗ hổng còn lại, đánh cắp credential
không chỉ cho phép *đọc* mà cho phép *gửi đúng danh tính thật*. Khi kẻ tấn công có tài khoản hợp lệ
và gửi từ chính hạ tầng được uỷ quyền, cả ba cơ chế SPF, DKIM và DMARC đều trả kết quả `pass` một
cách chính đáng. Đây là lý do nhóm xếp rủi ro này ở mức cao nhất trong ma trận ở mục 2.3.

#### Tấn công lừa đảo có chủ đích và xâm nhập email doanh nghiệp (BEC)

Giả mạo danh tính là viên gạch nền cho hai lớp tấn công nghiệp vụ:

* **Business Email Compromise (BEC).** Kẻ tấn công mạo danh lãnh đạo hoặc đối tác, gửi yêu cầu
  chuyển tiền khẩn cấp tới bộ phận kế toán — bộ phận có động cơ tâm lý để tuân thủ và ít có thói
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
trạng thái hợp lệ và im lặng — không có tín hiệu lỗi nào phát sinh cho người dùng hay cho quản trị
viên.

#### Nguyên lý kẻ đứng giữa bóc tách chỉ thị STARTTLS

Kẻ tấn công ở vị trí trung gian (đầu độc ARP, chiếm quyền định tuyến, hoặc kiểm soát một cổng trung
chuyển) thực hiện đúng một thao tác: chặn phản hồi `EHLO` của máy chủ nhận và loại bỏ dòng
`250-STARTTLS` trước khi chuyển tiếp cho bên gửi.

1. Client gửi `EHLO`.
2. Server đáp danh sách tính năng, trong đó có `250-STARTTLS`.
3. Kẻ trung gian xoá dòng đó (hoặc thay bằng một dòng vô nghĩa mà client bỏ qua).
4. Client kết luận server đích không hỗ trợ TLS.
5. Theo quy tắc opportunistic, client hạ cấp và truyền toàn bộ nội dung — kể cả thông tin đăng nhập
   — dưới dạng bản rõ.

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
ba thuộc tính bí mật — toàn vẹn — sẵn dùng, cộng thêm yếu tố tuân thủ và uy tín. Thang phân loại
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
— dạng tấn công đánh vào quá trình thương lượng chứ không đánh vào dữ liệu — và lượng hoá chín rủi
ro bằng thang 5×5 với căn cứ đo được. Ma trận cho thấy hai rủi ro nghiêm trọng nhất là đánh cắp
thông tin xác thực và giả mạo người gửi, đồng thời chỉ ra rằng việc xử lý chúng phải theo thứ tự:
bịt kênh xác thực bản rõ trước, sau đó mới đến ba cơ chế xác thực danh tính. Chương 3 sẽ hiện thực
hoá thứ tự đó trong một môi trường thực nghiệm cụ thể.
