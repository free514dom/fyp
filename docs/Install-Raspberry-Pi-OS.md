# Raspberry Pi Setup Strategy (Fedora / Fish Shell Edition)

**Target:** Raspberry Pi OS (Bookworm)
**Network:** Pixel Hotspot (SSID: li / PSK: 11111111)
**Shell:** Fish Shell (Host)

## 0. 变量与挂载 (Environment Setup)

请务必先确认 SD 卡设备名。

```fish
# 1. 设置变量 (请根据 lsblk 修改设备名)
set SD_DEV "/dev/sdb"
set MNT_DIR "/mnt/pi"

# 2. 挂载分区
sudo mkdir -p $MNT_DIR
# 挂载 Root 分区 (分区2)
sudo mount {$SD_DEV}2 $MNT_DIR
# 挂载 Boot 分区 (分区1)
sudo mount {$SD_DEV}1 $MNT_DIR/boot

# 3. 挂载内核伪文件系统 (使用 Fish 的循环语法)
for dir in sys proc dev dev/pts
    sudo mount --bind /$dir $MNT_DIR/$dir
end

# 4. 复制 DNS (确保 chroot 内能解析域名)
sudo cp /etc/resolv.conf $MNT_DIR/etc/resolv.conf
```

---

## 1. 网络配置 (Network Injection)

直接从宿主机写入文件，使用 `sudo tee` 解决权限问题。

```fish
# 写入 NetworkManager 配置
# 这里的 EOF 块会被 Fish 传递给 sudo tee 写入目标文件
cat <<EOF | sudo tee $MNT_DIR/etc/NetworkManager/system-connections/PixelHotspot.nmconnection > /dev/null
[connection]
id=PixelHotspot
uuid=6fad2b0b-98a7-4796-ae19-3bfd30bd3e97
type=wifi
interface-name=wlan0
permissions=

[wifi]
mode=infrastructure
ssid=li

[wifi-security]
key-mgmt=wpa-psk
psk=11111111

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF

# 修正权限 (必须是 600)
sudo chmod 600 $MNT_DIR/etc/NetworkManager/system-connections/PixelHotspot.nmconnection
sudo chown root:root $MNT_DIR/etc/NetworkManager/system-connections/PixelHotspot.nmconnection

echo "✅ WiFi 配置已注入"
```

---

## 2. 用户与服务配置 (System Configuration)

这一步我们使用 `chroot ... /bin/bash -c "..."` 的方式。
**原理**：虽然你在用 Fish，但树莓派里是 Bash。我们把一连串 Bash 命令包在引号里传进去执行。这样你不需要离开 Fish 环境。

```fish
# 定义要在 chroot 内部执行的脚本块
set SETUP_SCRIPT '
# 1. 创建用户 pi (如果存在则忽略错误)
id -u pi &>/dev/null || useradd -m -s /bin/bash pi

# 2. 设置密码 (pi:raspberry)
echo "pi:raspberry" | chpasswd

# 3. 赋予 Sudo 权限
usermod -aG sudo,video,audio,plugdev,games,users,input,render,netdev,gpio,i2c,spi pi

# 4. 配置免密 Sudo
echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
chmod 440 /etc/sudoers.d/010_pi-nopasswd

# 5. 强制开启 SSH
systemctl enable ssh
rm -f /etc/ssh/sshd_not_to_be_run

# 6. 设置 WiFi 国家代码 (CN)
echo "REGDOMAIN=CN" > /etc/default/crda
'

# 执行注入
sudo chroot $MNT_DIR /bin/bash -c "$SETUP_SCRIPT"

echo "✅ 用户与服务配置已应用"
```

---

## 3. 清理与卸载 (Cleanup)

```fish
# 卸载所有挂载点
sudo umount $MNT_DIR/boot
for dir in dev/pts dev sys proc
    sudo umount $MNT_DIR/$dir
end
sudo umount $MNT_DIR

echo "🎉 准备就绪！请拔卡并上电。"
```

---

## 4. 连接 (Connect)

上电 30 秒后：

```fish
# 扫描
sudo nmap -p 22 192.168.9.14

# 连接 (密码默认设为了 raspberry)
ssh pi@192.168.9.14
```
