# Bài tập lớn An toàn mạng: Bảo vệ dịch vụ thư điện tử

**Học phần:** INT1482, An toàn mạng<br>**Đề tài:** Tấn công giả mạo thư điện tử và biện pháp bảo vệ bằng STARTTLS, SPF, DKIM, DMARC.

Repo gồm báo cáo, mã cấu hình lab, kịch bản tấn công và kiểm chứng, cùng bằng chứng thu thập từ môi trường thực nghiệm. Để xem nội dung theo thứ tự, bắt đầu từ báo cáo rồi tham khảo tài liệu triển khai và các tệp bằng chứng được liên kết bên dưới.

## Xem báo cáo

1. [Báo cáo PDF](bao-cao/Bao%20cao%20ATM%20-%20Topic%2003%20-%20nhom%203.pdf) 
2. [Báo cáo Word](bao-cao/Bao%20cao%20ATM%20-%20Topic%2003%20-%20nhom%203.docx) 
3. [Bản Markdown](bao-cao/Bao-cao-ATM-Topic03.md) 

## Tài liệu theo nội dung

| Nội dung | Tài liệu |
|---|---|
| Thiết kế mạng, máy ảo và mô hình đe doạ | [docs/00-thiet-ke-lab.md](docs/00-thiet-ke-lab.md) |
| Các bước triển khai theo thứ tự | [docs/01-runbook-chay-lab.md](docs/01-runbook-chay-lab.md) |
| Cấu hình VMware và cài Ubuntu | [docs/02-vmware-setup.md](docs/02-vmware-setup.md) |
| Kịch bản và kết quả kiểm thử | [docs/03-test-cases.md](docs/03-test-cases.md) |
| Ma trận đánh giá rủi ro | [docs/04-risk-matrix.md](docs/04-risk-matrix.md) |
| Danh mục log, ảnh và bằng chứng | [docs/05-danh-sach-bang-chung.md](docs/05-danh-sach-bang-chung.md) |
| Cấu hình hệ thống và kịch bản demo | [docs/06-config-va-demo.md](docs/06-config-va-demo.md) |
| Hướng dẫn thực hành từng bước | [docs/07-lam-lab-tung-buoc.md](docs/07-lam-lab-tung-buoc.md) |

## Cấu trúc repo

| Thư mục | Nội dung |
|---|---|
| `bao-cao/` | Báo cáo PDF, Word, Markdown, hình minh hoạ và các tệp nguồn |
| `docs/` | Thiết kế, hướng dẫn triển khai, kiểm thử và bằng chứng |
| `install/` | Script cài đặt hệ điều hành, DNS và máy chủ thư |
| `configs/` | Tệp cấu hình DNS và các vùng thử nghiệm |
| `attacks/` | Kịch bản mô phỏng các lỗ hổng trong lab |
| `defense/` | Kịch bản áp dụng các biện pháp bảo vệ |
| `verify/` | Script kiểm tra cấu hình và kết quả sau phòng thủ |
| `evidence/` | Log và gói tin thu được trong quá trình thực nghiệm |

## Tóm tắt thực nghiệm

Mô hình gồm năm máy ảo Ubuntu trong mạng host-only `10.30.0.0/24`: một máy DNS, hai máy chủ thư, một máy tấn công và một máy khách. Các thử nghiệm trước phòng thủ ghi nhận chuyển tiếp thư không được phép, nghe lén dữ liệu bản rõ, lộ thông tin xác thực và giả mạo người gửi. Sau khi cấu hình, nhóm kiểm tra lại TLS, SPF, DKIM và DMARC bằng các script trong `verify/`.

Môi trường chỉ dùng cho thực nghiệm cô lập. Kết quả và nhận định chi tiết được trình bày trong [báo cáo](bao-cao/Bao%20cao%20ATM%20-%20Topic%2003%20-%20nhom%203.pdf); log gốc nằm trong [evidence/](evidence/) và được lập danh mục tại [docs/05-danh-sach-bang-chung.md](docs/05-danh-sach-bang-chung.md).

## Thành viên

| Thành viên | MSSV | Phần việc chính |
|---|---|---|
| Phạm Minh Thiện | B23DCAT285 | Postfix và Dovecot |
| Đỗ Hà Quân | B23DCAT245 | Phân tích lỗ hổng và rủi ro |
| Nghiêm Xuân Hoàng Tùng | B23DCAT326 | VMware và DNS BIND9 |
| Phan Thành Danh | B23DCAT040 | Kịch bản tấn công và thu thập bằng chứng |
| Trần Văn Trung | B23DCAT305 | STARTTLS, SPF, DKIM và DMARC |

**Phiên bản thành phần chính:** Ubuntu Server 24.04 LTS, Postfix 3.8.6, Dovecot 2.3.21, BIND 9.18.24, OpenDKIM 2.11 và OpenDMARC 1.4.2.
