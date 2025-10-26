#!/bin/bash
# === 藏红花培育系统 - 部署/设置脚本 (v3.0 - Root Version) ===
# 放在项目根目录运行

echo "=== 藏红花培育系统 - 智能部署工具 ==="

# 确保脚本在根目录执行
if [ ! -d "firmware" ] || [ ! -d "edge-server" ]; then
    echo "❌ 错误: 请在项目根目录下运行此脚本 (也就是包含 firmware 和 edge-server 文件夹的地方)"
    exit 1
fi

# 确定串口设备
DEVICE_PORT="/dev/ttyACM0"
if [ ! -e "$DEVICE_PORT" ]; then
    echo "   - 未找到 $DEVICE_PORT, 正在尝试 /dev/ttyACM1..."
    DEVICE_PORT="/dev/ttyACM1"
fi

# 激活虚拟环境 (如果有)
if [ -f .venv/bin/activate ]; then
    source .venv/bin/activate
fi

# --- 1. 管理后台服务 ---
echo -e "\n🔄 [1/5] 停止后台服务以释放串口..."
sudo systemctl stop saffron-server.service || echo "   (服务可能未安装或未运行)"
sleep 1

# --- 2. 连接检查 ---
echo -e "\n🔄 [2/5] 检查 STM32 连接 ($DEVICE_PORT)..."
# 尝试软重启确保连接
mpremote connect ${DEVICE_PORT} exec "import machine; machine.reset()" >/dev/null 2>&1
sleep 2 # 等待重启
if ! mpremote connect ${DEVICE_PORT} exec "print('✅ STM32 连接正常')"; then
    echo "❌ 错误: 无法连接到 STM32。"
    echo "   尝试恢复服务..."
    sudo systemctl start saffron-server.service
    exit 1
fi

# --- 3. 上传驱动库 ---
echo -e "\n📦 [3/5] 同步驱动库 (firmware/lib -> /lib)..."
# 将本地 firmware/lib 目录下的所有内容同步到 STM32 的 /lib 目录
# mpremote 的 cp -r 可能会比较慢，这里使用 recursive copy
mpremote connect ${DEVICE_PORT} fs cp -r firmware/lib/ :lib/
echo "✅ 驱动库更新完成。"

# --- 4. 上传主程序 ---
echo -e "\n🚀 [4/5] 上传主程序 (firmware/main.py -> /main.py)..."
mpremote connect ${DEVICE_PORT} fs cp firmware/main.py :main.py
echo "✅ 主程序部署完成。"

# 重启设备
mpremote connect ${DEVICE_PORT} reset
echo "✅ STM32 已重启并运行新代码。"

# --- 5. 恢复服务 ---
echo -e "\n✔️  [5/5] 重启后台服务..."
sudo systemctl start saffron-server.service
sleep 2

if systemctl is-active --quiet saffron-server.service; then
    echo "   ✅ 服务已成功运行！"
else
    echo "   ⚠️ 服务启动检查失败，请手动检查: sudo systemctl status saffron-server.service"
fi

echo -e "\n🎉 部署全部完成！"
