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
  Chuỗi khoá — chữ ký — bản ghi DNS đã được kiểm chứng hợp lệ bằng một công cụ độc lập cài đặt đúng
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

* Thứ nhất, bổ sung một resolver đệ quy nội bộ trong lab — hoặc bật phân giải đệ quy có kiểm soát
  trên máy chủ DNS hiện có, hoặc chạy một resolver cục bộ làm điểm hỏi duy nhất cho mọi tiến trình —
  để bộ thẩm định DKIM tự lấy được khoá và `dkim=pass` trở thành kết quả đo được thay vì phải kiểm
  chứng bằng công cụ ngoài.
* Thứ hai, triển khai MTA-STS kèm TLS-RPT và DANE TLSA trên nền DNSSEC, nhằm đóng triệt để lỗ hổng
  hạ cấp giữa các tổ chức.
* Thứ ba, khai thác báo cáo DMARC: nhận và phân tích báo cáo tổng hợp từ `rua`, dựng bảng theo dõi
  số lượng thư bị chặn theo ngày và theo nguồn gửi.
* Thứ tư, mở rộng sang các chuẩn bổ trợ — ARC cho chuỗi chuyển tiếp, BIMI cho biểu tượng đã xác thực
  — và tích hợp thêm bộ lọc nội dung, quét mã độc, greylisting cùng một webmail có mã hoá đầu cuối
  để hoàn thiện bức tranh vận hành thực tế.

Nhìn chung, kết quả thực nghiệm khẳng định luận điểm ban đầu: an toàn dịch vụ thư điện tử không đạt
được bằng một công nghệ đơn lẻ, mà bằng một chuỗi phối hợp chặt chẽ giữa định tuyến (DNS), mã hoá
đường truyền (STARTTLS), uỷ quyền nguồn gửi (SPF), toàn vẹn nội dung (DKIM) và căn chỉnh định danh
(DMARC) — trong đó phần khó nhất và cũng quyết định nhất nằm ở cấu hình và quy trình kiểm chứng,
không nằm ở bản thân các thuật toán.
