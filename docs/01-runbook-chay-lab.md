# 01 · Runbook triển khai lab Topic 03 (theo đúng thứ tự phải bấm)

**Quy ước đường dẫn:** mã nguồn bài tập đặt tại **`/root/lab`** trên **cả 5 VM** (xem README, mục "Đưa file vào VM").
**Cách dùng:** mỗi dòng là **MỘT lệnh**, dán rồi Enter; nhìn cột "Phải thấy", đạt rồi mới chụp `CHỤP NN`.
Không copy cả bảng. Không dán kèm prompt (`root@vm-mail1:~#`). Không đánh số lại `CHỤP`.
Ký hiệu máy: `D`=vm-dns(10.30.0.10), `M1`=vm-mail1(.20), `M2`=vm-mail2(.30), `A`=vm-atk(.40), `C`=vm-client(.50).

---

## Giai đoạn 0: Chuẩn bị VMware (Thiện + Tùng)

| # | Máy | Người | Việc phải làm | Phải thấy / CHỤP |
|---|---|---|---|---|
| 0.1 | Windows | Tùng | VMware → *Edit → Virtual Network Editor* (Run as administrator) → *Add Network* → **VMnet2** → tích **Host-only** | danh sách có `VMnet2 (Host-only)` |
| 0.2 | Windows | Tùng | Ở VMnet2: bỏ *Use local DHCP service*, đặt *Subnet IP* `10.30.0.0`, *Netmask* `255.255.255.0` → Apply | `CHỤP 01` subnet + host adapter `10.30.0.1` |
| 0.3 | Windows | Tùng | Tạo 5 VM Ubuntu **24.04.5 LTS server** (2 vCPU · 2 GB · 20 GB): `vm-dns vm-mail1 vm-mail2 vm-atk vm-client`; NIC **tạm để NAT (VMnet8)** để còn tải package. **Thông số từng VM + đáp án mọi màn hình cài đặt: `docs/02-vmware-setup.md`** | `CHỤP 02` 5 VM trong Library |
| 0.4 | Mỗi VM | Mỗi người | Cài Ubuntu: user `ubuntu`, mật khẩu `Lab@2026`, tick *Install OpenSSH server* | `CHỤP 03` màn Identity |
| 0.5 | Mỗi VM | Mỗi người | `sudo apt update` | có dòng `Get:1 http://archive.ubuntu.com` |

## Giai đoạn 0b: Đưa mã nguồn vào VM và cài package (còn Internet)

| # | Máy | Người | Lệnh | Phải thấy |
|---|---|---|---|---|
| 0.6 | Windows | Thiện | `scp -r btl-atm-topic03-email-security ubuntu@10.30.0.10:~/lab-upload` (làm tương tự với .20 .30 .40 .50) | progress bar, không `Permission denied` |
| 0.7 | Mỗi VM | chủ máy | `sudo -i` | prompt đổi thành `root@vm-…` |
| 0.8 | Mỗi VM | chủ máy | `mkdir -p /root/lab && cp -r /home/ubuntu/lab-upload/* /root/lab/ && ls /root/lab` | thấy `attacks configs defense docs install payloads→verify` |
| 0.9 | D | Tùng | `bash /root/lab/install/00-apt.sh dns` | `named`, `rndc`, `dig`, `named-checkzone` có version; `OK: du package` |
| 0.10 | M1 | Thiện | `bash /root/lab/install/00-apt.sh mail` | `postfix 3.8.6`, `dovecot 2.3.21`, `opendkim 2.11.0~beta2`, `opendmarc`, `policyd-spf` |
| 0.11 | M2 | Trung | `bash /root/lab/install/00-apt.sh mail` | như 0.10 |
| 0.12 | A | Danh | `bash /root/lab/install/00-apt.sh atk` | `swaks 20240103.0`, `nmap 7.94`, `ncat`, `python3` |
| 0.13 | C | Quân | `bash /root/lab/install/00-apt.sh client` | `mutt`, `tshark 4.2.2`, `swaks`, `mail` |
| 0.14 | M2 | Trung | `CHỤP 04`: output của 0.11 (đủ 5 dịch vụ) | thấy đủ `postfix dovecot opendkim opendmarc policyd-spf` |
| 0.15 | D | Tùng | Kiểm tra tự test của công cụ MitM: `python3 /root/lab/attacks/selftest-strip-proxy.py` | 5 dòng `PASS`, kết luận `proxy hoat dong dung thiet ke` |

## Giai đoạn 1: Cắt sang host-only, dựng DNS và mail "trần"

| # | Máy | Người | Lệnh | Phải thấy (chụp rồi đi tiếp) |
|---|---|---|---|---|
| 1.1 | Windows | Tùng | Tắt 5 VM → *Settings → Network Adapter* → **Custom VMnet2** → bật lại 5 VM | `CHỤP 05` cửa số Network Adapter |
| 1.2 | D | Tùng | `bash /root/lab/install/00-base.sh 10.30.0.10 ns1.congtyA.test vm-dns` | `10.30.0.10/24`; `nameserver 10.30.0.10` |
| 1.3 | M1 | Thiện | `bash /root/lab/install/00-base.sh 10.30.0.20 mail1.congtyA.test vm-mail1` | `10.30.0.20/24` |
| 1.4 | M2 | Trung | `bash /root/lab/install/00-base.sh 10.30.0.30 mail2.congtyB.test vm-mail2` | `10.30.0.30/24` |
| 1.5 | A | Danh | `bash /root/lab/install/00-base.sh 10.30.0.40 atk.darkside.test vm-atk` | `10.30.0.40/24` |
| 1.6 | C | Quân | `bash /root/lab/install/00-base.sh 10.30.0.50 client.congtyA.test vm-client` | `10.30.0.50/24` |
| 1.7 | D | Tùng | `bash /root/lab/install/10-dns.sh` | 4 dòng `OK` của `named-checkzone`, `active`, `dig` ra MX/PTR |
| 1.8 | D | Tùng | `cat /var/lib/bind/lab/congtyA.test.identity` | `CHỤP 06` file **chỉ có comment** = chưa phòng thủ |
| 1.9 | M1 | Thiện | `bash /root/lab/install/20-mail.sh alpha` | `Da tao user: giamdoc admin`; `ss` có 25/587/143; `smtpd_milters =` rỗng |
| 1.10 | M2 | Trung | `bash /root/lab/install/20-mail.sh beta` | `Da tao user: ketoan admin`; khối `NHAC LAI` hiện ra |
| 1.11 | C | Quân | `bash /root/lab/verify/v00-preflight.sh` | 5 IP `OK`; cổng 25/587/143 `MO` |
| 1.12 | Windows | Thiện | Snapshot 5 VM tên `G1-mail-tran` | `CHỤP 07` Snapshot Manager |

## Giai đoạn 2: TẤN CÔNG (CLO2): kết quả phải là "tấn công ĐƯỢC"

| # | Máy | Người | Lệnh | Phải thấy |
|---|---|---|---|---|
| 2.1 | A | Danh | `bash /root/lab/attacks/at01-open-relay.sh` | `SPAM … open relay` + RCPT `250` cho domain ngoài lab → `CHỤP 08` |
| 2.2 | M1 | Thiện | `bash /root/lab/attacks/at02-cleartext-sniff.sh` | `so dong chua STARTTLS = 0`; thấy `Subject:` và `1029384756` → `CHỤP 09` |
| 2.3 | Windows | Danh | `scp -r root@10.30.0.20:/root/evidence/mail1 ./ev` → mở `at02-smtp25.pcap` → *Statistics / Follow → TCP Stream* | cả phiên SMTP đọc được bằng mắt → `CHỤP 10` |
| 2.4 | C | Quân | `bash /root/lab/attacks/at03-credential-theft.sh` | `250-AUTH PLAIN LOGIN` + 2 dòng giải mã ra `giamdoc`, `Lab@2026` → `CHỤP 11` |
| 2.5 | A | Danh | `bash /root/lab/attacks/at04-spoof-header.sh` | `250 2.0.0 Ok: queued` cho thư mạo `admin@congtyA.test` → `CHỤP 12` |
| 2.6 | M2 | Trung | `bash /root/lab/attacks/at04-check-inbox.sh ketoan` | có file trong `Maildir/new`; 3 bộ đếm xác thực `= 0` → `CHỤP 13` |
| 2.7 | C | Quân | `mutt -f imap://ketoan@mail2.congtyB.test/Maildir` (mật khẩu `Lab@2026`) | MUA hiện thư "[KHAN] Yeu cau chuyen khoan" → `CHỤP 14` |
| 2.8 | A | Danh | `bash /root/lab/attacks/at05-spoof-own-domain.sh` | cả 2 phiên `250 queued` → `CHỤP 15` |
| 2.9 | D | Tùng | `bash /root/lab/defense/d02a-ca.sh` | `verify` = `OK`, `ss` có `:8080` |
| 2.10 | M1, M2 | Trung | `bash /root/lab/defense/d02b-tls.sh may` (chạy trên **từng** máy) | `Verify return code: 0 (ok)`, `Protocol: TLSv1.3`, EHLO có `250-STARTTLS` → `CHỤP 16` |
| 2.11 | A | Danh | `bash /root/lab/attacks/atk-run-strip-proxy.sh start` | `LISTEN 0.0.0.0:2525` → `CHỤP 17` |
| 2.12 | C | Quân | `bash /root/lab/attacks/at06-starttls-strip.sh` | [1] baseline qua TLS OK; [3] `so dong chua STARTTLS = 0` + AUTH bản rõ + `250 queued` → `CHỤP 18` |
| 2.13 | A | Danh | `bash /root/lab/attacks/atk-run-strip-proxy.sh show` | `[STRIP] AN DONG…`, `[AUTH-THIEP] PASSWORD = 'Lab@2026'`, `[TAMPER] … 1029384756` → `CHỤP 19` |
| 2.14 | M2 | Trung | `bash /root/lab/attacks/at04-check-inbox.sh ketoan` | thư mới nhất chứa **số tài khoản giả** `1029384756` → `CHỤP 20` |
| 2.15 | A | Danh | `bash /root/lab/attacks/atk-run-strip-proxy.sh stop` | `Da tat proxy.` |
| 2.16 | Windows | Quân | Snapshot `G2-ket-qua-tan-cong`; chép `evidence/` của cả 5 máy về máy | `CHỤP 21` cây thư mục evidence |

> Chốt Giai đoạn 2: **Quân + Danh** điền cột *Kết quả thực tế* của TC06–TC14 (`docs/03-test-cases.md`)
> và cột *Căn cứ đo được* của R1–R9 (`docs/04-risk-matrix.md`), **copy từ file evidence**, không nhớ miệng.

## Giai đoạn 3: PHÒNG THỦ (CLO3)

| # | Máy | Người | Lệnh | Phải thấy |
|---|---|---|---|---|
| 3.1 | M1, M2 | Thiện | `bash /root/lab/defense/d00-aliases.sh alpha` và `bash /root/lab/defense/d00-aliases.sh beta` (mỗi máy đúng role) | `dmarc-reports@… -> admin@…`, không `unknown user` |
| 3.2 | M1, M2 | Thiện | `bash /root/lab/defense/d01-close-relay.sh alpha` / `beta` | `mynetworks=127.0.0.0/8 …`, `disable_vrfy_command=yes` → `CHỤP 22` |
| 3.3 | M1, M2 | Trung | `bash /root/lab/defense/d02b-tls.sh encrypt` trên **cả hai** máy | `smtpd_tls_security_level=encrypt`, `smtp_tls_security_level=verify`, `ssl = required` → `CHỤP 23` |
| 3.4 | M2 rồi M1 | Trung | `bash /root/lab/defense/d03-spf-enforce.sh beta` / `alpha` | `TestOnly = 1`; `check_policy_service` nằm **sau** `reject_unauth_destination` → `CHỤP 24` |
| 3.5 | D | Tùng | `bash /root/lab/defense/d03b-spf-publish.sh` | `dig TXT congtyA.test` → `"v=spf1 ip4:10.30.0.20 mx -all"` → `CHỤP 25` |
| 3.6 | M1 | Thiện | `bash /root/lab/defense/d04a-dkim.sh alpha` | in ra block `mail._domainkey IN TXT ( "v=DKIM1; h=sha256; k=rsa; " "p=MIIBIjAN…" )` → `CHỤP 26` |
| 3.7 | M2 | Trung | `bash /root/lab/defense/d04a-dkim.sh beta` | như 3.6 cho congtyB.test |
| 3.8 | M1 | Thiện | `sudo cat /etc/dkimkeys/mail.txt` (giữ nguyên màn hình để dán tiếp) | 2–3 dòng `IN TXT ( "v=DKIM1…" "p=…" )` |
| 3.9 | D | Tùng | `bash /root/lab/defense/d04b-dkim-publish.sh alpha` → **dán** nội dung 3.8, Enter, Ctrl-D | serial tăng, `named-checkzone OK`, `p= dài ~392 ký tự` → `CHỤP 27` |
| 3.10 | M1 | Thiện | `opendkim-testkey -d congtyA.test -s mail -vvv 2>&1` rồi `echo "exit=$?"` | không có `key not found`; `exit=0` → `CHỤP 28` |
| 3.11 | D | Tùng | `bash /root/lab/defense/d04b-dkim-publish.sh beta` (dán `mail.txt` của M2) | `dig mail._domainkey.congtyB.test` có `v=DKIM1` |
| 3.12 | D | Tùng | `bash /root/lab/defense/d05a-dmarc-publish.sh` | `_dmarc.congtyA.test` → `v=DMARC1; p=reject; …` → `CHỤP 29` |
| 3.13 | M2, M1 | Trung | `bash /root/lab/defense/d05b-dmarc-enforce.sh beta` / `alpha` | `RejectFailures true`, `smtpd_milters=inet:localhost:8891, inet:localhost:8893` → `CHỤP 30` |
| 3.14 | D | Tùng | `bash /root/lab/verify/v01-dns-records.sh` | 6 dòng `PASS` (SPF×2, DKIM×2, DMARC×2) → `CHỤP 31` |
| 3.15 | Windows | Thiện | Snapshot `G3-phong-thu` | `CHỤP 32` |

## Giai đoạn 4: KIỂM CHỨNG: phòng thủ có hiệu lực thật không

| # | Máy | Người | Lệnh | Phải thấy |
|---|---|---|---|---|
| 4.1 | C | Quân | `bash /root/lab/verify/v00-preflight.sh` | 993 đã `MO`; SPF/DMARC/DKIM không rỗng |
| 4.2 | A | Danh | `bash /root/lab/verify/v03-replay-attacks.sh` | T1 `554` relay denied · T2/T3 `5xx` · T4 `5xx` DMARC · T5 `250` → `CHỤP 33` |
| 4.3 | M2 | Trung | `tail -n 80 /var/log/mail.log` | dòng `policyd-spf … 550 5.7.23`, `opendmarc … reject` → `CHỤP 34` |
| 4.4 | C | Quân | `bash /root/lab/verify/v02-happy-path.sh` | `250 2.0.0 Ok: queued`, `swaks exit code = 0` → `CHỤP 35` |
| 4.5 | M2 | Trung | `bash /root/lab/verify/v05-auth-results.sh ketoan` | `spf=pass dkim=pass dmarc=pass`, `DKIM-Signature d=congtyA.test; s=mail` → `CHỤP 36` |
| 4.6 | C | Quân | chạy lệnh ở mục **[4]** của `v02` (Beta→Alpha), rồi trên M1: `bash /root/lab/verify/v05-auth-results.sh giamdoc` | `dkim=pass header.d=congtyB.test` → `CHỤP 37` |
| 4.7 | C | Quân | `bash /root/lab/verify/v04-tls-and-downgrade.sh` | [2] `Verify return code: 0` · [4] AUTH trên kênh không TLS bị `538/550` · [5] cùng lệnh với 2.12 nhưng **thất bại** → `CHỤP 38` |
| 4.8 | A | Danh | `bash /root/lab/attacks/at01-open-relay.sh` | `smtp-open-relay` không còn báo open relay → `CHỤP 39` |
| 4.9 | D | Tùng | `bash /root/lab/defense/d02a-ca.sh stop` | `Da tat dich vu phat file` (đóng kênh chia sẻ private key) |
| 4.10 | Windows | Danh | `scp -r root@10.30.0.10:/root/evidence ./ev/dns` (tương tự .20 .30 .40 .50) | `CHỤP 40` cây thư mục evidence đầy đủ |

## Giai đoạn 5: Hoàn thiện hồ sơ

1. **Quân** chốt `docs/04-risk-matrix.md`: mỗi dòng R trỏ đúng file evidence; nếu thực tế khác dự kiến thì **sửa bảng theo thực tế**, không sửa số liệu cho khớp bảng.
2. **Danh** điền `docs/03-test-cases.md` (cột *Kết quả thực tế* + tên file) và `docs/05-danh-sach-bang-chung.md`.
3. **Thiện + Trung** viết Phần 1 (cơ sở lý thuyết) và Phần 3 (triển khai) của báo cáo từ chính file trong `configs/`, `install/`, `defense/`.
4. **Tùng** vẽ lại sơ đồ topology với đúng IP đã chạy + ảnh `CHỤP 01–02` (VMware Network Editor).
5. Cả nhóm làm slide 15–20 trang, tỉ lệ 30% lý thuyết / 50% demo / 20% kết luận, mỗi ảnh demo lấy từ `CHỤP NN` đã chụp.
6. Nộp PDF đúng cú pháp: `Bao cao ATM - <Mã lớp> - Nhom <số>.pdf`; kèm link GitHub/Drive trỏ tới thư mục này (thầy khuyến khích file config + kịch bản lab).

## Sự cố thường gặp (một lệnh để kiểm tra / sửa)

| Triệu chứng | Nguyên nhân | Lệnh kiểm tra / sửa |
|---|---|---|
| `apt` không tải được | NIC đang host-only mà chưa cài package | Switch NIC về NAT, chạy lại 0.9–0.13, rồi mới cắt |
| `named-checkzone` báo lỗi cú pháp zone | dán thiếu một dòng `p=` | `grep -n 'p=' /var/lib/bind/lab/congtyA.test.identity`; xoá dòng hỏng, chạy lại 3.9 |
| `dig` trả `status: REFUSED` | hỏi tên ngoài zone lab | dùng `dig @10.30.0.10 congtyA.test MX` |
| `554 5.7.1 Relay access denied` ngay Giai đoạn 2 | lỡ chạy `d01` | `postconf -h mynetworks` phải chứa `10.30.0.0/24`; hoặc restore `G1-mail-tran` |
| swaks báo lỗi TLS (exit 29) ở Giai đoạn 2 | lỡ chạy `d02b encrypt` | `postconf -h smtpd_tls_security_level`; restore snapshot |
| `warning: problem talking to server 127.0.0.1:8891` | OpenDKIM chưa đổi sang inet | `grep '^Socket' /etc/opendkim.conf`; `systemctl restart opendkim` |
| Thư hợp lệ nhưng `dkim=none` | `InternalHosts` thiếu IP client | `cat /etc/opendkim/InternalHosts` phải có `10.30.0.50/32` |
| `dmarc=fail` cho thư của user thật | `Header From` khác domain ký | `grep -E '^(From|Authentication-Results)' file_trong_Maildir` |
| `certificate is not yet valid` | đồng hồ VM lệch | `date -u` → `date -u --set='2026-10-06 10:00:00'` |
| `plaintext authentication prohibited` khi login IMAP | `d02b encrypt` đã bật (đúng) | dùng `imaps://…:993` hoặc `mutt -f imaps://ketoan@mail2.congtyB.test` |
