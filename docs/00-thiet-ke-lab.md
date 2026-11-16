# 00 · Thiết kế môi trường lab

Tài liệu này là phần "Mô tả môi trường Lab" mà thầy yêu cầu trong **Phần 3** của báo cáo
(topology, phiên bản phần mềm, địa chỉ IP các máy). Mọi con số dưới đây đều là **số thật dùng trong lab**.

## 1. Mô hình và lý do chọn

Hai tổ chức ảo cùng tồn tại trong một mạng cô lập:

- **congtyA.test** – Công ty Alpha: có người dùng hợp lệ, là **nạn nhân** bị giả mạo định danh
  (giám đốc `giamdoc@`, quản trị `admin@`). Mail server: `mail1` (vừa gửi vừa nhận).
- **congtyB.test** – Công ty Beta: là **nhà phòng thủ**, người nhận `ketoan@congtyB.test`,
  nơi triển khai toàn bộ tầng SPF/DKIM/DMARC. Mail server: `mail2`.
- **darkside.test** – domain của attacker (`atk`), dùng cho kịch bản "DKIM đúng nhưng sai lien ket mien"
  (mục tùy chọn AT-07).

Lý do bắt buộc phải có **2 MTA + 1 DNS riêng**: SPF/DKIM/DMARC chỉ kiểm tra được khi có
*người gửi ở domain khác* và *mail server nhận tra vấn DNS của domain gửi*. Một máy chủ đơn
không tạo ra được hiện tượng giả mạo xuyên tổ chức.

```
                         VMnet host-only  10.30.0.0/24  (không NAT, không bridge)
   ┌──────────────────────────────────────────────────────────────────────────────────┐
   │                                                                                  │
   │   ┌────────────────┐        SMTP/25  plaintext (GĐ1)      ┌────────────────┐     │
   │   │  vm-mail1      │ ───────────────────────────────────▶ │  vm-mail2      │     │
   │   │ 10.30.0.20     │        + AUTH/587, STARTTLS (GĐ3)    │ 10.30.0.30     │     │
   │   │ Postfix MTA    │                                      │ Postfix MTA    │     │
   │   │ Dovecot 143/993│        DNS/53 (mọi máy)              │ Dovecot 143/993│     │
   │   │ OpenDKIM s+v   │ ◀──────────────┬──────────────────── │ policyd-spf    │     │
   │   └────────────────┘                │                     │ OpenDKIM v     │     │
   │                                     │                     │ OpenDMARC      │     │
   │   ┌────────────────┐                │                     └────────────────┘     │
   │   │  vm-dns        │ ◀─────────────┘                                             │
   │   │ 10.30.0.10     │  BIND9 authoritative + Lab CA (ldaps? không) + openssl      │
   │   │ congtyA/B/dark │                                                             │
   │   └────────────────┘                                                             │
   │        ▲                    ▲                                                   │
   │        │ DNS                │ DNS/spoof, 25, 587, relayhost chèn giữa            │
   │   ┌────┴─────────┐     ┌────┴──────────────┐                                    │
   │   │  vm-client   │     │  vm-atk           │                                     │
   │   │ 10.30.0.50   │     │ 10.30.0.40        │                                     │
   │   │ MUA mutt     │     │ swaks nmap        │                                     │
   │   │ tshark/wiresh│     │ tcpdump, py proxy │                                     │
   │   └──────────────┘     └───────────────────┘                                     │
   └──────────────────────────────────────────────────────────────────────────────────┘
```

## 2. Bảng máy ảo (cam kết với báo cáo)

| VM | Hostname ngắn | FQDN | IP tĩnh /24 | CPU · RAM · đĩa | Dịch vụ | Phiên bản **đọc bằng `dpkg-query` ngày 13/10/2026** |
|---|---|---|---|---|---|---|
| vm-dns | `ns1` | `ns1.congtyA.test` | 10.30.0.10 | 1 · 1 GB · 20 GB | DNS, Lab CA | bind9 1:9.18.39-0ubuntu0.24.04.7 · bind9-utils · bind9-dnsutils (cùng bản) · openssl 3.0.13-0ubuntu3.16 · tcpdump 4.99.4-3ubuntu4.24.04.1 |
| vm-mail1 | `mail1` | `mail1.congtyA.test` | 10.30.0.20 | 2 · 2 GB · 20 GB | MTA gửi/nhận Alpha, IMAP, ký + kiểm tra DKIM/SPF/DMARC | postfix 3.8.6-1ubuntu0.1 · dovecot-core/imapd/lmtpd 1:2.3.21+dfsg1-2ubuntu6.5 · opendkim + opendkim-tools 2.11.0~beta2-9build4 · opendmarc 1.4.2-4.1build2 · postfix-policyd-spf-python 3.0.4-2 · mailutils 1:3.17-1.1build3 |
| vm-mail2 | `mail2` | `mail2.congtyB.test` | 10.30.0.30 | 2 · 2 GB · 20 GB | MTA nhận Beta (nhà phòng thủ) | **giống hệt vm-mail1** — bộ ba phòng thủ bật trên cả hai MTA để chiều Beta→Alpha cũng có `dkim=pass` (TC25) |
| vm-atk | `atk` | `atk.darkside.test` | 10.30.0.40 | 1 · 1 GB · 20 GB | Tấn công, MitM | swaks 20240103.0-1 · nmap + nmap-common + ncat 7.94+git20230807.3be01efb1+dfsg-3build2 · ettercap-text-only 1:0.8.3.1-13build3 · python3 3.12.3 · tcpdump 4.99.4 |
| vm-client | `client` | `client.congtyA.test` | 10.30.0.50 | 1 · 1 GB · 20 GB | MUA, phân tích gói | mutt 2.2.12-0.1build4 · tshark 4.2.2-1.1build3 · swaks 20240103.0-1 · mailutils 1:3.17-1.1build3 |

Ghi chú về phiên bản (nêu được trong báo cáo, thể hiện cách làm việc):
- `bind9` là **9.18.39-0ubuntu0.24.04.7** chứ không phải 9.18.24 của bản GA, vì `apt` lấy từ pocket
  `-updates` của 24.04.5. Toàn bộ tham số cấu hình em đối chiếu theo file mặc định trong `.deb`
  của noble nên vẫn đúng.
- `vm-client` có `postfix 3.8.6` chỉ vì `mailutils` phụ thuộc vào nó; dịch vụ được tắt bằng
  `systemctl disable --now postfix` để client không mở cổng 25 lạ trong ảnh chụp `ss -ltnp`.
- `dig` có mặt trên **cả 5 máy** (package `bind9-dnsutils`) — cần cho `policyd-spf`, `opendkim`
  và các script `verify/`.

Cổng làm việc:

| Cổng | Hướng | Nội dung | Ở giai đoạn nào |
|---|---|---|---|
| 53/tcp-udp | mọi máy → vm-dns | tra vấn zone congtyA/B/darkside, reverse | tất cả |
| 25/tcp | mail1 ↔ mail2, atk → mail1/mail2, client → mail1 | SMTP (MX inbound, relay MTA→MTA) | tất cả |
| 587/tcp | client/atk → mail1 | submission (STARTTLS + SASL LOGIN) | GĐ1 plaintext → GĐ3 bắt buộc TLS |
| 143 / 993 | client → mail1/mail2 | IMAP đọc hop thu (đọc bằng chứng, MUA) | GĐ1 không TLS → GĐ3 `ssl = required` |
| 8891 / 8893 (loopback) | postfix → milter | OpenDKIM / OpenDMARC trên chính máy đó | GĐ3 |
| 2525/tcp | mail1 → atk | proxy chặn STARTTLS (vị trí MitM) | GĐ2 |

## 3. Quy hoạch DNS

`ns1.congtyA.test` là **name server duy nhất, authoritative-only** (`recursion no`), được cấu hình
làm DNS của *chính* 5 máy qua netplan → không cần Internet, không có forwarder.

Zone file để ở **`/var/lib/bind/`** (AppArmor của bind9 trên Ubuntu chỉ cho ghi ở đó, `/etc/bind` chỉ đọc).

| Zone | File | Bản ghi quan trọng |
|---|---|---|
| `congtyA.test` | `/var/lib/bind/db.congtyA.test` | SOA/NS, `mail1 A 10.30.0.20`, `MX 10 mail1`, `$INCLUDE /var/lib/bind/lab/congtyA.identity` |
| `congtyB.test` | `/var/lib/bind/db.congtyB.test` | `mail2 A 10.30.0.30`, `MX 10 mail2`, include tương tự |
| `darkside.test` | `/var/lib/bind/db.darkside.test` | `atk A 10.30.0.40`, `mail A 10.30.0.40`, include tương tự |
| `0.30.10.in-addr.arpa` | `/var/lib/bind/db.10.30.0` | PTR 5 máy (chứng minh hiểu reverse zone; phục vụ kiểm tra `ptr` của SPF) |

Cơ chế quan trọng cho tiến trình lab: **các bản ghi định danh (SPF/DKIM/DMARC) không có sẵn từ đầu**,
mà nằm trong file `$INCLUDE` rỗng. `defense/d03/d04/d05` ghi nội dung vào file đó, tăng serial và
`rndc reload`. Nhờ vậy "xuất bản bản ghi DNS" trở thành một *hành động có bằng chứng*
(`cat` file trước/sau, `dig TXT` trước/sau) chứ không phải mô tả trên giấy.

## 4. Người dùng trong lab (Unix account thật, Maildir)

| Email | Máy | Unix user | Mật khẩu lab | Dùng để |
|---|---|---|---|---|
| `giamdoc@congtyA.test` | vm-mail1 | `giamdoc` | `Lab@2026` | nạn nhân bị giả mạo header From |
| `admin@congtyA.test` | vm-mail1 | `admin` | `Lab@2026` | đối tượng spoof trong AT-04 |
| `dmarc-reports@congtyA.test` | vm-mail1 | alias → `admin` | – | `rua=` trong bản ghi DMARC |
| `ketoan@congtyB.test` | vm-mail2 | `ketoan` | `Lab@2026` | người nhận thư lừa đảo / thư hợp lệ |
| `admin@congtyB.test` | vm-mail2 | `admin` | `Lab@2026` | quản trị nhà phòng thủ |

Chọn **local unix account + `home_mailbox = Maildir/`** (không dùng `virtual_mailbox_*`):
không cần `vmail`/uid map/`virtual_mailbox_maps`, Dovecot dùng `userdb passwd` có sẵn, và
bằng chứng đọc (`cat ~/Maildir/new/*`) là đường dẫn thật, không phải cấu hình trừu tượng.

## 5. Threat model (cơ sở cho ma trận rủi ro – docs/04)

| Ký hiệu | Đe dọa | Điểm yếu SMTP gốc | Kịch bản lab | Kiểm soát |
|---|---|---|---|---|
| T1 | Open relay | `mynetworks` rộng, thiếu `smtpd_relay_restrictions` | AT-01 (nmap smtp-open-relay) | D-01 |
| T2 | Nghe lén nội dung + credential | 25/587 plaintext, opportunistic TLS | AT-02, AT-03 (tcpdump + base64) | D-02 |
| T3 | Giả mạo Envelope/`Header From` | SMTP không xác thực người gửi, `MAIL FROM` do client chọn | AT-04, AT-05 (swaks) | D-03, D-05 |
| T4 | Sửa nội dung thư đã ký | DKIM không được verify ở nơi nhận | AT-06 (proxy body tamper) | D-04 |
| T5 | Hạ cấp STARTTLS (strip) | Client "tốt bụng" tự fallback plaintext | AT-06/AT-06b (strip proxy) | D-02 (mandatory TLS), hướng mở rộng MTA-STS/DANE |
| T6 | DKIM hợp lệ nhưng sai liên kết miền | chữ ký không ràng buộc với `Header From` | AT-07 (tùy chọn) | D-05 (DMARC alignment) |

## 6. Quy ước bằng chứng

- Thư mục trên mỗi VM: `~/evidence/<vm-short>/`. Tên file: `at04-spoof.log`, `at02-smtp.pcap`, `v03-auth-results.log`…
- Ảnh chụp màn hình đánh số `CHỤP 01 … CHỤP NN` liên tục toàn bài; một ảnh = một trạng thái đã được
  xác minh bằng lệnh `grep`/`dig`/`postconf -n` in ngay trên màn hình.
- Ảnh bắt buộc cho báo cáo (15–20 trang, 5 phần):
  1.topology + `ip -br addr` 5 máy · 2. `dig` zone trước phòng thủ (không có TXT định danh)
  3. nmap open-relay trước/sau · 4. tcpdump/tshark thấy `MAIL FROM:` và `AUTH` bản rõ
  5. swaks spoof được chấp nhận (250 OK) + file trong `~/Maildir/new/` của `ketoan`
  6. `opendkim-genkey` + `dig TXT mail._domainkey.congtyA.test` · 7. `dig TXT _dmarc.congtyA.test`
  8. thư hợp lệ có `Authentication-Results: spf=pass dkim=pass dmarc=pass`
  9. spoof sau phòng thủ bị từ chối (mã SMTP 5xx in nguyên văn) · 10. `openssl s_client` TLSv1.3
  11. strip proxy thất bại sau mandatory TLS · 12. `postconf -n` hai máy sau củng cố.

## 7. Ràng buộc an toàn & quy chế

- VMnet **host-only**: card ảo Windows `10.30.0.1` là thiết bị duy nhất ngoài 5 VM có thể tới dải này.
- Không mở NAT/bridged cho bất kỳ VM nào, kể cả để `apt install` → mirror được cài **trước** khi rút mạng
  (script `00-base.sh` có bước kiểm tra và báo rõ nếu thiếu package).
- Không dùng `.local` (RFC 6762 dành cho mDNS) → toàn bộ lab dùng `.test` (RFC 6761, không bao giờ phân giải ra Internet).
- SPF `ip4:10.30.0.20` là dải riêng tư theo RFC 1918; trong sản xuất sẽ là IP công cộng của MX — lab ghi rõ điểm khác biệt này trong Phần 4.
