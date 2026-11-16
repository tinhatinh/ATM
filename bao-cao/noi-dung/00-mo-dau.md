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

Bốn cơ chế chuẩn hoá do IETF ban hành — STARTTLS (RFC 3207), SPF (RFC 7208), DKIM (RFC 6376) và
DMARC (RFC 7489) — được thiết kế để bịt đúng bốn khe hở nói trên, nhưng mỗi cơ chế chỉ trả lời
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
