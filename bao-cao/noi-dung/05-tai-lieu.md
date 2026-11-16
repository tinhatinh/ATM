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

[16] The Trusted Domain Project, "OpenDKIM Filter v2.11.0" — trang man `opendkim.conf(5)`, `opendkim-genkey(8)`, `opendkim-testkey(8)`, http://www.opendkim.org/, truy cập tháng 10 năm 2026.

[17] The Trusted Domain Project, "OpenDMARC" — trang man `opendmarc.conf(5)`, http://www.trusteddomain.org/opendmarc/, truy cập tháng 10 năm 2026.

[18] W. ten Bruijn, "postfix-policyd-spf-python" — trang man `policyd-spf.conf(5)`, mục `TestOnly` và `Mail_From_reject`, https://launchpad.net/postfix-policyd-spf-python, truy cập tháng 10 năm 2026.

[19] NLnet Labs, "Unbound — documentation" (thư viện phân giải libunbound), https://nlnetlabs.nl/projects/unbound/documentation/, truy cập tháng 10 năm 2026.

[20] J. Jetmore, "swaks — The Swiss Army Knife of SMTP", tài liệu tham số lệnh bản 20240103.0, https://www.jetmore.org/john/code/swaks/, truy cập tháng 10 năm 2026.

[21] Nmap Project, "Nmap Scripting Engine: smtp-open-relay", "smtp-commands", https://nmap.org/nsedoc/, truy cập tháng 10 năm 2026.

[22] Wireshark Foundation, "Wireshark User's Guide: Analyzing Application Layer Protocols", https://www.wireshark.org/docs/wsug_html_chunked/, truy cập tháng 10 năm 2026.

[23] The OpenSSL Project, "openssl-s_client(1)", "openssl-x509(1)", "openssl-dgst(1)", https://www.openssl.org/docs/, truy cập tháng 10 năm 2026.

**Hướng dẫn triển khai và tài liệu tham khảo nghiệp vụ**

[24] US Cybersecurity and Infrastructure Security Agency (CISA), "Best Practices for Email Security", 2020. https://www.cisa.gov/

[25] Messaging, Malware and Mobile Anti-Abuse Working Group (M3AAWG), "Email Fraud and Abuse — DNS-based Controls", tài liệu dành cho nhà vận hành. https://www.m3aawg.org/

[26] Google LLC, "Ensure your SPF, DKIM and DMARC records are set up correctly", Google Workspace Administrator Help. https://support.google.com/a/

*Ghi chú về tính trung thực của số liệu.* Toàn bộ mã phản hồi SMTP, dòng nhật ký, giá trị băm và số
đo trong báo cáo được trích nguyên văn từ các tệp bằng chứng sinh ra trong phiên thực nghiệm ngày
18/10/2026 trên năm máy ảo của nhóm, lưu tại thư mục `evidence/` kèm mã tra SHA-256 (xem Phụ lục A).
Không có kết quả nào được ước lượng hay tái tạo lại.
