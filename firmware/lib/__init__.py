# Saffron STM32 Core - Sensor Drivers Module
# 藏红花STM32核心传感器驱动模块
# 
# 版本: 1.0.0
# 作者: 藏红花培育系统项目组
# 日期: 2024
#
# 支持的传感器:
# - DHT11/DHT22 温湿度传感器 (硬件级+软件级+模拟)
# - 更多传感器待扩展...

"""
藏红花培育系统传感器驱动模块

此模块提供了智能农业系统所需的各种传感器驱动程序，
采用分层架构设计，支持多种驱动方式的自动降级。

主要特性:
- 硬件级驱动优先 (machine.dht_readinto)
- 软件级驱动备用 (纯Python实现)
- 模拟数据保底 (用于演示和测试)
- 统一的传感器接口
- 完善的错误处理和日志
"""

# 版本信息
__version__ = "1.0.0"
__author__ = "Saffron Cultivation System Team"

# 导入核心模块
try:
    from .sensor_base import SensorBase, SensorError
    from .dht11 import DHT11Sensor
    
    # 定义公开API
    __all__ = [
        'SensorBase',
        'SensorError', 
        'DHT11Sensor',
        'create_dht11_sensor',
        'get_driver_info'
    ]
    
    print(f"✅ 传感器驱动模块加载成功 v{__version__}")
    
except ImportError as e:
    print(f"❌ 传感器驱动模块加载失败: {e}")
    # 提供基本的错误处理
    __all__ = []

def create_dht11_sensor(pin, sensor_type='DHT11'):
    """
    工厂函数: 创建DHT11传感器实例
    
    参数:
        pin: MicroPython Pin对象
        sensor_type: 传感器类型 ('DHT11' 或 'DHT22')
    
    返回:
        DHT11Sensor实例
    """
    try:
        from .dht11 import DHT11Sensor
        return DHT11Sensor(pin, sensor_type)
    except ImportError:
        raise ImportError("DHT11驱动模块未正确安装")

def get_driver_info():
    """
    获取驱动模块信息
    
    返回:
        dict: 包含版本、支持的传感器等信息
    """
    import sys
    
    # 检查硬件支持
    hardware_support = False
    try:
        import machine
        if hasattr(machine, 'dht_readinto'):
            hardware_support = True
    except:
        pass
    
    return {
        'version': __version__,
        'author': __author__,
        'platform': sys.platform,
        'micropython_version': sys.version,
        'hardware_dht_support': hardware_support,
        'supported_sensors': ['DHT11', 'DHT22'],
        'driver_modes': ['hardware', 'software', 'simulated']
    }

# 模块初始化完成提示
def _init_message():
    """显示模块初始化信息"""
    info = get_driver_info()
    print("📦 传感器驱动模块信息:")
    print(f"   版本: {info['version']}")
    print(f"   平台: {info['platform']}")
    print(f"   硬件DHT支持: {'✅ 是' if info['hardware_dht_support'] else '❌ 否'}")
    print(f"   支持传感器: {', '.join(info['supported_sensors'])}")

# 在导入时显示信息 (仅调试时)
if __name__ == "__main__":
    _init_message()
