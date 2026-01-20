# 奇遇事件系统框架

这是一个可扩展的奇遇事件系统框架，参考了升级系统的设计模式，支持多种事件类型和灵活的配置。

## 系统架构

```
EventData (Resource)           # 事件数据定义
    ↓ 被注册到
EventRegistry (Autoload)      # 事件注册表和管理器
    ↓ 被使用
EventUI (场景脚本)             # 事件UI显示和交互
```

## 核心组件

### 1. EventData - 事件数据资源类

定义单个事件的所有属性和行为。

**位置**: `scripts/events/event_data.gd`

**主要属性**:
- `id`: 事件唯一标识符
- `display_name`: 事件显示名称
- `description`: 事件描述文本（支持占位符）
- `event_type`: 事件类型（REWARD, CHOICE, BATTLE等）
- `rarity`: 事件稀有度（COMMON, UNCOMMON, RARE等）
- `base_weight`: 基础权重（影响出现概率）
- `reward_type` / `reward_value`: 奖励配置
- `choices`: 选择项列表（用于CHOICE类型）
- `tags`: 标签系统（用于分类和筛选）

**事件类型**:
- `REWARD`: 简单奖励事件（直接给奖励）
- `CHOICE`: 选择事件（多个选项，不同结果）
- `BATTLE`: 战斗事件（触发战斗）
- `SHOP`: 特殊商店事件
- `REST`: 休息事件（回复生命值）
- `UPGRADE`: 升级事件（直接给升级）
- `RANDOM`: 随机事件（随机结果）
- `CUSTOM`: 自定义事件（通过回调实现）

### 2. EventRegistry - 事件注册表

管理所有可用事件的注册、查询和随机选取。

**位置**: `scripts/events/event_registry.gd`

**主要功能**:
- 自动加载内置事件
- 从文件加载自定义事件（`data/events/*.tres`）
- 根据条件筛选可用事件
- 权重随机选取事件
- 管理已触发的事件记录

**主要方法**:
```gdscript
# 注册事件
func register_event(event: EventData)

# 获取事件
func get_event(id: String) -> EventData

# 随机选取事件
func pick_random_event(character_id: String, current_floor: int) -> EventData

# 标记事件已触发
func mark_event_triggered(event_id: String)

# 清除已触发记录（用于新游戏）
func clear_triggered_events()
```

### 3. EventUI - 事件UI脚本

处理事件的显示和交互。

**位置**: `scripts/ui/event_ui.gd`

**主要功能**:
- 从EventRegistry随机选取事件
- 根据事件类型显示不同的UI
- 处理事件结果并应用奖励
- 支持多种奖励类型（摩拉、生命值、升级等）

## 如何添加新事件

### 方法1: 在代码中注册（内置事件）

在 `EventRegistry._register_builtin_events()` 方法中添加：

```gdscript
var my_event = EventData.new()
my_event.id = "my_event_id"
my_event.display_name = "我的事件"
my_event.description = "这是一个示例事件。"
my_event.event_type = EventData.EventType.REWARD
my_event.reward_type = EventData.RewardType.GOLD
my_event.reward_value = 100
my_event.rarity = EventData.Rarity.COMMON
my_event.tags = ["reward", "gold"]
_register_event(my_event)
```

### 方法2: 创建资源文件（推荐）

1. 在Godot编辑器中，右键点击 `data/events/` 目录
2. 选择 "新建资源"
3. 选择 `EventData` 作为资源类型
4. 配置事件属性
5. 保存为 `.tres` 文件（例如：`my_custom_event.tres`）

系统会自动加载 `data/events/` 目录下的所有 `.tres` 文件。

### 示例：创建选择事件

```gdscript
# 在资源文件中配置
id = "mysterious_choice"
display_name = "神秘的选择"
description = "你遇到了一个分岔路口，需要做出选择。"
event_type = 1  # CHOICE
rarity = 2      # RARE
choices = [
    {
        "text": "选择左边的路",
        "reward_type": 0,  # GOLD
        "reward_value": 50,
        "cost": 0,
        "description": "安全地获得50摩拉"
    },
    {
        "text": "选择右边的路",
        "reward_type": 4,  # MULTIPLE
        "reward_value": {"gold": 150, "health": -30},
        "cost": 0,
        "description": "获得150摩拉，但失去30点生命值"
    }
]
```

## 事件条件系统

事件支持多种条件限制：

- **角色限制**: `required_character_ids` - 只有指定角色才能触发
- **楼层限制**: `min_floor` / `max_floor` - 只在特定楼层出现
- **前置事件**: `required_event_ids` - 必须先触发过这些事件
- **互斥事件**: `exclusive_event_ids` - 不能与这些事件同时出现
- **一次性事件**: `one_time_only` - 只能触发一次

## 奖励类型

- `GOLD`: 摩拉奖励
- `HEALTH`: 生命值奖励（恢复）
- `UPGRADE`: 升级奖励（可以是具体ID或"random"）
- `ARTIFACT`: 圣遗物奖励（待实现）
- `MULTIPLE`: 多种奖励组合（字典格式）

## 标签系统

使用 `tags` 数组为事件添加标签，可以用于：
- 分类和筛选事件
- 在代码中查询特定类型的事件
- 实现事件组合效果

示例标签：
- `["reward", "gold"]` - 奖励类，摩拉相关
- `["choice", "risk"]` - 选择类，有风险
- `["battle", "combat"]` - 战斗类

## 权重系统

事件的权重影响其出现概率：

1. **基础权重**: `base_weight` - 每个事件的基础权重
2. **稀有度调整**: 稀有度越高，权重越低
3. **楼层调整**: 高楼层略微增加稀有事件出现概率
4. **动态权重**: 可以重写 `calculate_weight()` 方法实现自定义权重逻辑

## 扩展性设计

### 添加新的事件类型

1. 在 `EventData.EventType` 枚举中添加新类型
2. 在 `EventUI._display_event()` 中添加对应的显示逻辑
3. 在 `EventUI` 中添加对应的事件处理方法

### 添加新的奖励类型

1. 在 `EventData.RewardType` 枚举中添加新类型
2. 在 `EventUI._apply_reward()` 中添加对应的处理逻辑

### 自定义事件行为

可以继承 `EventData` 类，重写以下方法：
- `can_trigger()` - 自定义触发条件
- `calculate_weight()` - 自定义权重计算
- `get_formatted_description()` - 自定义描述格式化

## 注意事项

1. **事件ID唯一性**: 确保每个事件的ID是唯一的
2. **资源文件路径**: 自定义事件必须放在 `data/events/` 目录下
3. **新游戏重置**: 系统会在新游戏开始时自动清除已触发的事件记录
4. **占位符**: 描述文本支持 `{floor}`, `{gold}`, `{health}`, `{reward}` 等占位符

## 示例事件文件

参考 `data/events/` 目录下的示例文件：
- `example_treasure_event.tres` - 宝藏奖励事件
- `example_choice_event.tres` - 选择事件
- `example_healing_event.tres` - 治愈事件
