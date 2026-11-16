# BTL An toàn mạng — Topic 03: An toàn dịch vụ thư điện tử (SMTP · SPF · DKIM · DMARC)

**Học viện Công nghệ Bưu chính Viễn thông** · Lớp học phần **INT1482 – An toàn mạng**

> **Đề tài:** An toàn dịch vụ thư điện tử — tấn công giả mạo định danh và phòng thủ bằng
> STARTTLS, SPF, DKIM, DMARC.

Repo này là **toàn bộ phần thực hành** của bài tập lớn: môi trường lab cô lập 5 máy ảo, file cấu
hình thật, kịch bản tấn công thật, tầng phòng thủ thật, script kiểm chứng và toàn bộ bằng chứng
log/pcap. Báo cáo được viết **từ output thật** sinh ra khi chạy các kịch bản trong repo này.

---

## Mục lục

- [1. Nhóm thực hiện](#1-nhóm-thực-hiện)
- [2. Kiến trúc lab](#2-kiến-trúc-lab)
- [3. Vòng đời bài tập](#3-vòng-đời-bài-tập)
- [4. Cấu trúc repo](#4-cấu-trúc-repo)
- [5. Bắt đầu nhanh](#5-bắt-đầu-nhanh)
- [6. Báo cáo và tài liệu](#6-báo-cáo-và-tài-liệu)
- [7. Kết quả thực nghiệm](#7-kết-quả-thực-nghiệm)
- [8. Lỗi đã gặp và giới hạn đã root-cause](#8-lỗi-đã-gặp-và-giới-hạn-đã-root-cause)
- [9. Liêm chính học thuật](#9-liêm-chính-học-thuật)

---

## 1. Nhóm thực hiện

| Thành viên | MSSV | Vai trò trong lab |
|---|---|---|
| Phạm Minh Thiện | B23DCAT285 | Trưởng nhóm · MTA/MDA: Postfix + Dovecot trên 2 máy chủ mail |
| Đỗ Hà Quân | B23DCAT245 | Phân tích lỗ hổng, threat model, ma trận rủi ro |
| Nghiêm Xuân Hoàng Tùng | B23DCAT326 | Topology VMware + DNS BIND9 (zone A/MX/TXT) |
| Phan Thành Danh | B23DCAT040 | Kịch bản tấn công (swaks, nmap, tcpdump) + thu bằng chứng |
| Trần Văn Trung | B23DCAT305 | STARTTLS/SPF/DKIM/DMARC: sinh khoá, xuất bản bản ghi, milter |

## 2. Kiến trúc lab

Hai tổ chức ảo cùng tồn tại trong **một mạng cô lập** — đây là điều kiện bắt buộc để SPF/DKIM/DMARC
có nghĩa: phải có *người gửi ở domain khác* và *mail server nhận tra vấn DNS của domain gửi*.

| # | Máy | FQDN | IP | Vai trò | Phần mềm chính (Ubuntu 24.04 LTS) |
|---|---|---|---|---|---|
| 1 | `vm-dns` | `ns1.congtyA.test` | 10.30.0.10 | DNS authoritative + CA của lab | bind9 9.18.24, openssl |
| 2 | `vm-mail1` | `mail1.congtyA.test` | 10.30.0.20 | MTA/MDA **Công ty Alpha** (bên gửi, nạn nhân) | postfix 3.8.6 · dovecot 2.3.21 · opendkim 2.11.0~beta2 (ký + kiểm tra) · opendmarc 1.4.2 · postfix-policyd-spf-python 3.0.4 |
| 3 | `vm-mail2` | `mail2.congtyB.test` | 10.30.0.30 | MTA/MDA **Công ty Beta** (bên nhận, nhà phòng thủ) | như `vm-mail1` — bộ ba phòng thủ bật trên **cả hai** MTA |
| 4 | `vm-atk` | `atk.darkside.test` | 10.30.0.40 | Attacker + vị trí MitM | swaks 20240103.0, nmap 7.94, tcpdump, python3, postfix + opendkim (mục tuỳ chọn) |
| 5 | `vm-client` | `client.congtyA.test` | 10.30.0.50 | MUA của user hợp lệ | mutt, mailutils, tshark, wireshark |

Mạng **VMnet host-only `10.30.0.0/24`** (không NAT, không bridge) → cô lập tuyệt đối với Internet và
với mạng của học viện. Tên miền dùng đuôi `.test` theo RFC 6761 (không phân giải ra ngoài, không
xung đột mDNS như đuôi `.local`).

- **congtyA.test** – Công ty Alpha: có người dùng hợp lệ, là **nạn nhân** bị giả mạo định danh
  (`giamdoc@`, `admin@`). Mail server: `mail1` (vừa gửi vừa nhận).
- **congtyB.test** – Công ty Beta: **nhà phòng thủ**, người nhận `ketoan@congtyB.test`, nơi triển
  khai toàn bộ tầng SPF/DKIM/DMARC. Mail server: `mail2`.
- **darkside.test** – domain của attacker (`atk`), dùng cho kịch bản "DKIM đúng nhưng sai liên kết
  miền" (AT-07, mục tuỳ chọn).

Chi tiết topology, sơ đồ và lý do chọn mô hình: [`docs/00-thiet-ke-lab.md`](docs/00-thiet-ke-lab.md).

## 3. Vòng đời bài tập

```
Giai đoạn 0  Dựng nền tảng      : VMnet + 5 VM + IP tĩnh + DNS   (install/00-*.sh, install/10-*.sh)
Giai đoạn 1  Mail "trần"        : Postfix/Dovecot chưa phòng thủ  (install/20-*.sh)
Giai đoạn 2  TẤN CÔNG (CLO2)    : attacks/at01..at07  -> evidence/  (bắt buộc thành công)
Giai đoạn 3  PHÒNG THỦ (CLO3)   : defense/d01..d05    -> cấu hình + bản ghi DNS
Giai đoạn 4  KIỂM CHỨNG         : verify/v01..v05 + chạy lại attacks -> evidence/ (bắt buộc thất bại)
Giai đoạn 5  VIẾT BÁO CÁO       : docs/03,04,05  -> nội dung 5 phần của báo cáo
```

## 4. Cấu trúc repo

```
install/    00-apt.sh  00-base.sh  10-dns.sh  20-mail.sh
configs/dns/  named.conf.options · named.conf.local · zones/db.{congtyA,congtyB,darkside,10.30.0} · lab/*.identity
attacks/    at01-open-relay  at02-cleartext-sniff  at03-credential-theft  at04-spoof-header
            at04-check-inbox  at05-spoof-own-domain  at06-starttls-strip  at07-spf-pass-dmarc-fail
            atk-run-strip-proxy · strip_starttls.py · selftest-strip-proxy.py · payloads/*.txt
defense/    d00-aliases · d01-close-relay · d02a-ca · d02b-tls(may|encrypt) · d03-spf-enforce
            d03b-spf-publish · d04a-dkim · d04b-dkim-publish · d05a-dmarc-publish
            d05b-dmarc-enforce · dns-add-record
verify/     v00-preflight · v01-dns-records · v02-happy-path · v03-replay-attacks
            v04-tls-and-downgrade · v05-auth-results · parse-headers.py · dkim-check.py · smtp-probe.py
docs/       00 thiết kế · 01 runbook · 03 test cases · 04 risk matrix · 05 bằng chứng
            06 vấn đáp · 07 cấu hình VMware & đáp án cài Ubuntu
            08 CONFIG + DEMO (giá trị thật, ý nghĩa, 13 lỗi đã gặp, hướng phát triển)
            09 HƯỚNG DẪN TỪ LUỒNG: tấn công -> vá -> tấn công lại (LAB 1..8)
evidence/   log + pcap thu từ từng máy ảo · EVIDENCE-TREE.txt · evidence-checksums.txt
bao-cao/    Bao cao ATM - Topic 03 - nhom 3.docx / .pdf · Bao-cao-ATM-Topic03.md
            noi-dung/ (7 file nguồn) · anh/ (31 hình) · lenh-chup/ (lệnh sinh từng ảnh)
state.sh    in trạng thái cấu hình theo chuẩn cố định để so sánh TRƯỚC/SAU mỗi bước
```

## 5. Bắt đầu nhanh

**Bước 1 — Pha cài package khi VM còn ở NAT** (cần Internet), sau đó mới cắt sang host-only —
xem `docs/01-runbook-chay-lab.md` giai đoạn 0b → 1. Máy Windows có card ảo `10.30.0.1` trên cùng
VMnet host-only nên scp được thẳng vào VM:

```bash
scp -r btl-atm-topic03-email-security ubuntu@10.30.0.10:~/lab-upload
```

**Bước 2 — Trên từng VM** (sau `sudo -i`) đưa về đường dẫn chuẩn `/root/lab` — mọi script đều dùng
đường dẫn tuyệt đối này:

```bash
mkdir -p /root/lab && cp -r /home/ubuntu/lab-upload/* /root/lab/ && ls /root/lab
```

**Bước 3 — Chạy từng script một, đúng thứ tự số trong tên file:**

```bash
bash /root/lab/install/00-base.sh 10.30.0.10 ns1.congtyA.test vm-dns
```

Mọi script đều `set -euo pipefail` và in khối `=== XAC MINH ===` ở cuối; nếu không thấy dòng kỳ
vọng thì dừng lại và đọc lỗi, không chụp ảnh "cho đủ". Riêng công cụ MitM có self-test chạy trên
bất kỳ máy nào (chỉ dùng `127.0.0.1`, không cần VM):

```bash
python3 /root/lab/attacks/selftest-strip-proxy.py      # kỳ vọng: 5 dòng PASS
```

**Thu bằng chứng.** Mỗi script tấn công/kiểm chứng tự ghi log vào `/root/evidence/<vm-short>/`
(`.log`, `.txt`) và `.pcap` khi có bắt gói. Kéo về Windows để cắm vào báo cáo:

```bash
scp -r root@10.30.0.40:/root/evidence ./ev/atk
```

Báo cáo dùng số `Hình 1, 2, 3…` do Word tự đánh số (kiểu `BTL-Hinh`). Mỗi ảnh tương ứng một lệnh có
thật, lưu trong `bao-cao/lenh-chup/vm-<may>.sh` (gọi `bash /root/shot/vm-<may>.sh <ten-case>` để tạo
lại ảnh). `docs/05-danh-sach-bang-chung.md` giữ bảng map số `CHỤP NN` với file log/pcap tương ứng.

## 6. Báo cáo và tài liệu

| Tài liệu | Đường dẫn |
|---|---|
| Báo cáo bản Word | [`bao-cao/Bao cao ATM - Topic 03 - nhom 3.docx`](bao-cao/Bao%20cao%20ATM%20-%20Topic%2003%20-%20nhom%203.docx) |
| Báo cáo bản PDF | [`bao-cao/Bao cao ATM - Topic 03 - nhom 3.pdf`](bao-cao/Bao%20cao%20ATM%20-%20Topic%2003%20-%20nhom%203.pdf) |
| Báo cáo bản Markdown (dễ diff) | [`bao-cao/Bao-cao-ATM-Topic03.md`](bao-cao/Bao-cao-ATM-Topic03.md) |
| 7 file nguồn của báo cáo | [`bao-cao/noi-dung/`](bao-cao/noi-dung) |
| 31 hình trong báo cáo | [`bao-cao/anh/`](bao-cao/anh) |
| Lệnh sinh lại từng hình | [`bao-cao/lenh-chup/`](bao-cao/lenh-chup) |
| Runbook dựng lab | [`docs/01-runbook-chay-lab.md`](docs/01-runbook-chay-lab.md) |
| Bộ test case | [`docs/03-test-cases.md`](docs/03-test-cases.md) |
| Ma trận rủi ro | [`docs/04-risk-matrix.md`](docs/04-risk-matrix.md) |
| Danh sách bằng chứng | [`docs/05-danh-sach-bang-chung.md`](docs/05-danh-sach-bang-chung.md) |
| Câu hỏi vấn đáp | [`docs/06-van-dap.md`](docs/06-van-dap.md) |
| Cấu hình + demo (giá trị thật) | [`docs/08-config-va-demo.md`](docs/08-config-va-demo.md) |
| Từ luồng: tấn công → vá → tấn công lại | [`docs/09-lam-lab-tung-buoc.md`](docs/09-lam-lab-tung-buoc.md) |

## 7. Kết quả thực nghiệm

**Đã chạy thật trên 5 VM Ubuntu 24.04.5 (18/10/2026, 08:52 → 10:46 UTC):**

| Hạng mục | Kết quả thật |
|---|---|
| Nền tảng: `00-base.sh`, `10-dns.sh`, `20-mail.sh` | 5 VM có IP tĩnh 10.30.0.10–50, BIND authoritative-only phục vụ 4 zone, 2 MTA chạy `postfix 3.8.6` + `dovecot 2.3.21`, user/Maildir thật |
| Tấn công AT-01 → AT-06 | Open relay `16/16 tests` trên cả 2 MTA; sniff bản rõ thấy `Subject` + số tài khoản; lấy được `giamdoc / Lab@2026` từ AUTH; 3 thư giả mạo vào hộp thư nạn nhân với 0 header xác thực; STARTTLS stripping + sửa body thành công (`1029384756` thay `9999999999`) |
| Phòng thủ D-00 → D-05b | Đóng relay, TLS `encrypt` + `verify`, SPF `TestOnly = 1`, DKIM 2048-bit đã ký thật (`DKIM-Signature: a=rsa-sha256; d=congtya.test; s=mail`), DMARC `p=reject` + `RejectFailures true` |
| Kiểm chứng chữ ký DKIM | `verify/dkim-check.py` → `openssl dgst -verify` trả **`Verified OK`** với khoá lấy từ DNS bằng `dig` |

**Trạng thái kiểm chứng của chính bộ file trong repo (minh bạch, ghi cả vào báo cáo):**

| Đã kiểm chứng | Cách kiểm chứng | Kết quả |
|---|---|---|
| `attacks/strip_starttls.py` (ẩn STARTTLS + sửa body) | `python3 attacks/selftest-strip-proxy.py` trên loopback `127.0.0.1`, máy Windows | 5/5 PASS: EHLO của client không còn `250-STARTTLS`, MTA nhận `1029384756` thay vì `9999999999` *(log: `attacks/selftest-loopback-windows.log`)* |
| Cú pháp toàn bộ script | `bash -n` cho 24 script, `py_compile` cho 2 file Python | không lỗi |
| Tên package / tham số cấu hình | đối chiếu trực tiếp file mặc định và man page trích từ `.deb` của Ubuntu 24.04 (`opendkim.conf`, `opendmarc.conf`, `policyd-spf.conf`, `master.cf.dist`, `dovecot/conf.d/*`, `named.conf.options`) | mọi khoá dùng trong repo đều tồn tại; các khoá bị bịa phổ biến (`TrustedHosts`, `RejectAction`, `opendmarc-tools`) đã bị loại |

## 8. Lỗi đã gặp và giới hạn đã root-cause

**Lỗi script đã sửa nhờ chạy thật** (mỗi lỗi đều từng làm hỏng một bước):

- `policyd-spf --version` không tồn tại và treo vô hạn.
- `sed 's|^Socket .*|'` không khớp vì `opendkim.conf` dùng TAB.
- `/etc/opendmarc.conf` không có dòng `Socket` để mà `sed`.
- `99-lab-tls.conf` xếp *trước* `99-lab.conf` theo ASCII nên `ssl = no` vẫn thắng.
- `hostname -f` trả `vm-mail1` (không FQDN) sau khi `/etc/hosts` có dòng `127.0.1.1`.
- `ncat` chỉ có ở vai `atk`.
- `v01` ghép `"ten TXT"` vào một biến làm `dig` nhận nhầm tên.
- `grep -c` / `grep -oE` trả 1 làm abort khối `set -e`.

**Giới hạn đã root-cause** (ghi thành một mục trong báo cáo): OpenDKIM 2.11 của Ubuntu 24.04 liên kết
`libunbound.so.8` và tự phân giải lặp từ root server thay vì dùng `/etc/resolv.conf`, nên trong mạng
host-only không Internet nó không bao giờ lấy được bản ghi DKIM của vùng `.test` — kể cả khi trỏ
`ResolverConfiguration` bằng `forward-zone`/`stub-zone`/`root-hints` (`tcpdump` xác nhận 0 gói tin
được gửi). Chuỗi khoá–chữ ký vẫn đúng, chứng minh bằng `verify/dkim-check.py`.

## 9. Liêm chính học thuật

- Mọi lệnh tấn công chỉ nhắm 5 IP trong `10.30.0.0/24`. Không quét/gửi tới bất kỳ host nào ngoài dải này.
- Không có kết quả nào trong repo được điền sẵn. Cột "Kết quả thực tế" của bảng test case và mọi
  output trong báo cáo **phải** lấy từ file trong `evidence/`.
- Kết quả thu được khác kỳ vọng cũng là kết quả đúng — ghi lại nguyên văn rồi cùng phân tích.
- Toàn bộ máy ảo đã được xoá sau khi hoàn thành bài; repo chỉ giữ lại script, cấu hình, log và
  bằng chứng để có thể dựng lại lab từ đầu.

---

*Ubuntu 24.04 LTS · Postfix 3.8.6 · Dovecot 2.3.21 · OpenDKIM 2.11 · OpenDMARC 1.4.2 · BIND 9.18.24*
