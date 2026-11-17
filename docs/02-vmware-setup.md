# 07 · Cấu hình VMware và đáp án từng màn hình cài Ubuntu (để tạo 5 VM nhanh)

ISO: `C:\Users\Administrator\Documents\Qoder\2026-10-06\eb46c113\iso\ubuntu-24.04.5-live-server-amd64.iso`
sha256 chính thức của Ubuntu: `97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8`

## 1. Thông số từng VM

| VM | Tên trong library | vCPU | RAM | Đĩa | NIC ở giai đoạn 0b | NIC từ giai đoạn 1 | hostname đặt khi cài |
|---|---|---|---|---|---|---|---|
| DNS | `vm-dns` | 1 | 1 GB | 20 GB, *Store as single file*, thin | VMnet8 (NAT) | **VMnet2 (host-only)** | `vm-dns` |
| Mail Alpha | `vm-mail1` | 2 | 2 GB | 20 GB thin | VMnet8 | VMnet2 | `vm-mail1` |
| Mail Beta | `vm-mail2` | 2 | 2 GB | 20 GB thin | VMnet8 | VMnet2 | `vm-mail2` |
| Attacker | `vm-atk` | 1 | 1 GB | 20 GB thin | VMnet8 | VMnet2 | `vm-atk` |
| Client | `vm-client` | 1 | 1 GB | 20 GB thin | VMnet8 | VMnet2 | `vm-client` |

Tổng RAM khi bật cả 5: **7 GB**. Nếu máy chỉ còn ≥ 5 GB free thì chạy theo nhóm:
- Nhóm A (GĐ0–GĐ1, GĐ3): `vm-dns` + `vm-mail1` + `vm-mail2` (4 GB), suspend `vm-atk`, `vm-client`.
- Nhóm B (GĐ2 tấn công, GĐ4 kiểm chứng): thêm `vm-atk` (5 GB); `vm-client` bật riêng khi làm AT-03/AT-06/v02.
Không cần đổi cấu hình, chỉ *Pause/Suspend* VM không dùng (VMware chỉ tính RAM cho VM đang chạy).

Tắt *Memory Trim / ballooning* không cần thiết; điều quan trọng hơn: **đừng cấp RAM cho VM nếu host đang mở Chrome > 20 tab**.

## 2. Wizard "New Virtual Machine" (5 lần, mỗi lần đổi 2 ô)

1. *Typical (recommended)* → Next.
2. *Installer disc image file (iso)* →/browse tới ISO ở trên → Next. VMware sẽ tự nhận "Ubuntu Linux 5.x or later 64-bit" (cứ để nguyên, không sao).
3. *Easy Install* hỏi username/password: điền `ubuntu` / `Lab@2026`, nhưng **bỏ qua Easy Install nếu màn hiện ra** bằng cách bấm *Finish* rồi *Edit virtual machine settings* → CD/DVD → *Use ISO image* nếu cần. (Easy Install tự tạo user `ubuntu` đúng ý ta, dùng nó cũng được.)
4. *Name*: `vm-dns` (tương tự 4 VM còn lại) → chọn vị trí `C:\LabATM\vm-dns`.
5. *Disk capacity* 20 GB, tick **Store virtual disk as a single file** → *Advanced* → Virtual device node: SATA.
6. *Customize hardware* → Network → **NAT** (tạm thời) → Finish.

Sau khi cài xong và chạy `00-apt.sh` (cần Internet): *Settings → Network Adapter* → **Custom:_specific virtual network_ → VMnet2**.

## 3. Đáp án từng màn hình của Ubuntu Server 24.04 installer

| Màn hình | Chọn | Vì sao |
|---|---|---|
| Language | English | tránh lỗi font trong ảnh chụp terminal |
| Keyboard | US | default |
| Install type | **Ubuntu Server** (bản chuẩn, *không* tick "minimized") | bản minimized cắt cả `curl`/`iproute2` tối giản, lab cần `curl`, `ss`, `dig` |
| Update to new installer | Skip / No | khỏi tải thêm 300 MB lúc đang NAT |
| Network connections | **eth0/ens33 = DHCP (automatic)** ở giai đoạn này, giữ default | `00-base.sh` sẽ ghi IP tĩnh sau; để DHCP để còn Internet mà `apt` |
| Proxy address | để trống | |
| Mirror address | `http://archive.ubuntu.com/ubuntu` | mirror mặc định, đúng bản ta đã đối chiếu package |
| Guided storage | **Use an entire disk** → disk 20 GB → *Set up this disk as an LVM group* **bỏ tick** | bỏ LVM để `/home` đơn giản, đọc `Maildir` bằng đường dẫn `/home/<user>/Maildir` |
| Profile | Your name `lab`, username `ubuntu`, password `Lab@2026`, **tick "Require a strong password" → bỏ** | `Lab@2026` bị installer coi là đủ mạnh; nếu nó vẫn đòi thì chọn `Lab@2026x` rồi dùng nhất quán ở mọi máy |
| Upgrade Ubuntu | **No / None** | tránh unattended-upgrade đổi package giữa lúc lab đang chụp ảnh |
| SSH setup | **tick Enable SSH server + Import SSH keys → No** | cần `scp` từ Windows |
| Featured Server Snaps | **không chọn gì** | mỗi snap là vài trăm MB, không dùng |
| Reboot | Reboot now, **remove installation media** khi được nhắc | |

## 4. Đưa project vào VM (sau khi reboot, VM vẫn đang ở NAT)

**Bước 1, đọc IP do DHCP cấp, ngay trong VM:**

```
ip -4 addr show
```

**Bước 2, trên Windows (Git Bash/PowerShell), scp với chính IP vừa đọc** (ví dụ máy này nhận `192.168.122.101`):

```
scp -r btl-atm-topic03-email-security ubuntu@192.168.122.101:~/lab-upload
```

Mỗi VM có một IP khác nhau, nên lặp lại với IP của từng máy. Mật khẩu đăng nhập: `Lab@2026`.

Trong VM:

```
sudo -i
passwd
```
(đặt `Lab@2026` cho root, prompt phải đổi thành `root@vm-…`)

```
mkdir -p /root/lab && cp -r /home/ubuntu/lab-upload/* /root/lab/ && ls /root/lab
```
Phải thấy 6 mục: `attacks configs defense docs install verify` (README nằm ở gốc, không sao).

## 4b. IP NAT thực tế mà nhóm em đã dùng (giai đoạn cài + `00-apt.sh`)

Card ảo của 5 VM là **ens33**; dải VMnet8 của máy này là `192.168.153.0/24`:

| VM | IP NAT | hostname |
|---|---|---|
| vm-dns | 192.168.153.139 | `vm-dns` |
| vm-mail1 | 192.168.153.140 | `vm-mail1` |
| vm-mail2 | 192.168.153.141 | `vm-mail2` |
| vm-atk | 192.168.153.142 | `vm-atk` |
| vm-client | 192.168.153.143 | `vm-client` |

Các IP này **chỉ tồn tại ở giai đoạn 0b**. Từ giai đoạn 1, mọi thứ dùng IP lab `10.30.0.10/20/30/40/50`.
Báo cáo chỉ nêu dải 10.30.0.0/24; dải NAT ghi ở đây để đối chiếu lúc dựng lại lab.
KHÔNG chạy `apt upgrade`/`pro attach`, mọi tham số đã đối chiếu theo bản GA 24.04.5.

## 5. Check-list trước khi bấm `00-base.sh` (VM đang NAT, chưa cắt mạng)

```
bash /root/lab/install/00-apt.sh dns        # tren vm-dns
bash /root/lab/install/00-apt.sh mail       # tren vm-mail1 va vm-mail2
bash /root/lab/install/00-apt.sh atk        # tren vm-atk
bash /root/lab/install/00-apt.sh client     # tren vm-client
apt-cache policy postfix dovecot-core opendkim opendmarc postfix-policyd-spf-python swaks bind9 | grep -E '^[a-z]|Candidate'
```

Dòng `Candidate` của 6 package phải **không** là `(none)`. Nếu là `(none)` → repository `universe` chưa bật,
script `00-apt.sh` đã có đoạn tự bật; kiểm tra lại bằng:

```
grep -h universe /etc/apt/sources.list.d/ubuntu.sources
```

Xong bước này mới tới giai đoạn 1 trong `docs/01-runbook-chay-lab.md` (đổi NIC sang VMnet2 → `00-base.sh` →
`10-dns.sh` → `20-mail.sh`).

## 6. Đặt tên snapshot để không phải dựng lại lab

| Thời điểm | Tên snapshot (đúng 5 VM) | Dùng để |
|---|---|---|
| Sau `00-apt.sh` | `G0-pkg` | quay lại nếu dựng DNS hỏng |
| Sau `20-mail.sh` | `G1-mail-tran` | **chạy lại toàn bộ tấn công nhiều lần** (mỗi lần chạy AT xong thì revert) |
| Sau `d02b-tls.sh may` | `G2-opportunistic` | chạy AT-06 |
| Sau `d05b` | `G3-phong-thu` | chạy verify/v01..v05 và quay phim demo |

Nhờ có snapshot, một cuộc tấn công có thể trình diễn bao nhiêu lần tuỳ thích mà kết quả vẫn là **thật**
(không phải số liệu ghi một lần rồi chép vào báo cáo).
