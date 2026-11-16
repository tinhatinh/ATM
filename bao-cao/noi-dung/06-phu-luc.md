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
