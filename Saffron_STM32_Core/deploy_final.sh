#!/bin/bash
# === 藏红花培育系统 - 最终部署脚本 (v2.4 - 集成手势识别) ===
# 功能: 自动部署主程序、驱动库、OLED驱动和手势识别驱动

echo "=== 藏红花培育系统 - 智能部署 (v2.4 - 手势识别版) ==="

# 切换到脚本文件所在的目录, 保证所有相对路径都正确
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# 确定串口设备，优先使用 ttyACM0，如果不存在则尝试 ttyACM1
DEVICE_PORT="/dev/ttyACM0"
if [ ! -e "$DEVICE_PORT" ]; then
    echo "   - 未找到 $DEVICE_PORT, 正在尝试 /dev/ttyACM1..."
    DEVICE_PORT="/dev/ttyACM1"
fi

# 使用绝对路径激活虚拟环境 (如果存在)
if [ -f ../.venv/bin/activate ]; then
    source ../.venv/bin/activate
fi

# --- 核心改进：自动管理服务 ---
echo -e "\n🔄 步骤 1/7: 自动停止后台服务以释放串口..."
sudo systemctl stop saffron-server.service
echo "   ✅ 服务已停止。"
sleep 1 # 等待服务完全释放资源

echo -e "\n🔄 步骤 2/7: 重置 STM32 并检查连接 (设备: $DEVICE_PORT)..."
mpremote reset > /dev/null 2>&1
sleep 2
if ! mpremote connect ${DEVICE_PORT} exec "print('✅ STM32F411 连接正常')"; then
    echo "❌ 错误: 无法连接到 STM32。请检查连接。"
    echo "   (正在尝试重启服务...)"
    sudo systemctl start saffron-server.service # 部署失败，恢复服务
    exit 1
fi

echo -e "\n📦 步骤 3/7: 上传模块化驱动文件 (drivers)..."
mpremote fs cp -r drivers/ :drivers/ >/dev/null 2>&1 || {
    echo "   - (备用方案) 逐个上传驱动文件..."
    mpremote fs mkdir :drivers >/dev/null 2>&1
    mpremote fs cp drivers/__init__.py :drivers/__init__.py
    mpremote fs cp drivers/sensor_base.py :drivers/sensor_base.py
    mpremote fs cp drivers/dht11.py :drivers/dht11.py
}
echo "✅ 传感器驱动模块上传完成。"

echo -e "\n📦 步骤 4/7: 上传 OLED 驱动库 (ssd1306.py)..."
mpremote fs cp ssd1306.py :ssd1306.py
echo "✅ OLED 驱动库上传完成。"

echo -e "\n📦 步骤 5/7: 上传 PAJ7620 手势识别驱动库..."
mpremote fs cp paj7620.py :paj7620.py
echo "✅ PAJ7620 驱动库上传完成。"

echo -e "\n🚀 步骤 6/7: 上传主程序并设为自启动..."
mpremote fs cp main_modular.py :main.py
echo "✅ 主程序部署完成，STM32 将在下次重启后自动运行。"

mpremote reset
echo "✅ STM32 已重启，正在自动运行主程序 (请观察OLED屏幕和手势传感器)。"

# --- 核心改进：自动重启服务 ---
echo -e "\n✔️  步骤 7/7: 自动重启后台服务..."
sudo systemctl start saffron-server.service
sleep 2 # 给服务一点启动时间

echo "   检查服务状态..."
if systemctl is-active --quiet saffron-server.service; then
    echo "   ✅ 服务已成功重启并正在后台运行！"
else
    echo "   ⚠️ 警告: 服务未能自动重启，请手动检查: sudo systemctl status saffron-server.service"
fi

echo -e "\n🎉 部署完成! 代码已更新，手势识别已集成，服务已恢复。"
echo "   现在可以在传感器前挥手，观察OLED和Web界面的实时变化了。"
