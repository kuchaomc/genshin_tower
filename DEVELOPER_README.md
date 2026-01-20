# Genshin Roguelike - 开发者文档

> 这是一个使用 Godot 4.5 引擎开发的类杀戮尖塔风格 Roguelike 动作游戏的开发者指南。

## 目录

- [项目概览](#项目概览)
- [技术栈](#技术栈)
- [项目架构](#项目架构)
- [核心系统](#核心系统)
- [属性系统](#属性系统)
- [开发工作流](#开发工作流)
- [代码规范](#代码规范)
- [常见问题](#常见问题)
- [调试指南](#调试指南)

---

## 项目概览

### 游戏特性

- **类杀戮尖塔地图系统**：垂直爬塔式地图，每层多个可选节点
- **多样化节点类型**：战斗、商店、休息、奇遇、BOSS
- **实时动作战斗**：流畅的近战战斗系统
- **角色成长系统**：战斗后升级选择，提升角色属性
- **数据驱动设计**：使用 Resource 和 JSON 配置，易于平衡调整

### 技术亮点

- **模块化架构**：清晰的目录结构和职责分离
- **统一属性系统**：CharacterStats/EnemyStats 统一管理属性和伤害计算
- **基类继承体系**：BaseCharacter/BaseEnemy 便于扩展新角色和敌人
- **信号驱动通信**：使用 Godot 信号系统实现松耦合
- **单例模式管理**：GameManager/DataManager/RunManager 管理全局状态

---

## 技术栈

- **游戏引擎**: Godot 4.5
- **开发语言**: GDScript
- **目标平台**: Windows / Linux / macOS / Mobile
- **版本控制**: Git
- **设计模式**: 单例模式、策略模式、工厂模式

---

## 项目架构

### 目录结构

```
genshin_game/
├── scripts/                    # 所有游戏脚本
│   ├── autoload/              # 全局单例（自动加载）
│   │   ├── game_manager.gd    # 游戏状态、场景管理、存档
│   │   ├── data_manager.gd    # 数据加载（角色、敌人、配置）
│   │   └── run_manager.gd     # 单局游戏状态（楼层、金币、统计）
│   │
│   ├── characters/            # 角色系统
│   │   ├── character_data.gd      # 角色数据 Resource 类
│   │   ├── character_stats.gd     # 角色属性系统（NEW）
│   │   ├── base_character.gd      # 角色基类（移动、血量、闪避）
│   │   ├── kamisato_ayaka_character.gd  # 神里绫华角色实现
│   │   └── ability_data.gd        # 技能数据 Resource 类
│   │
│   ├── enemies/               # 敌人系统
│   │   ├── enemy_data.gd      # 敌人数据 Resource 类
│   │   ├── enemy_stats.gd     # 敌人属性系统（NEW）
│   │   ├── base_enemy.gd      # 敌人基类（AI、血量、警告）
│   │   ├── chase_enemy.gd     # 追击型敌人
│   │   └── ranged_enemy.gd    # 远程敌人
│   │
│   ├── map/                   # 地图系统
│   │   ├── map_generator.gd  # 地图生成器（类杀戮尖塔）
│   │   ├── map_node.gd        # 地图节点（节点类型、连接）
│   │   └── map_room.gd        # 地图房间
│   │
│   ├── ui/                    # UI 系统
│   │   ├── main_menu.gd       # 主菜单
│   │   ├── character_select.gd    # 角色选择界面
│   │   ├── map_view.gd        # 地图视图
│   │   ├── upgrade_selection.gd   # 升级选择界面
│   │   ├── result_screen.gd   # 结算界面
│   │   ├── pause_menu.gd      # 暂停菜单
│   │   └── skill_ui.gd        # 技能 UI
│   │
│   ├── battle/                # 战斗系统
│   │   └── battle_manager.gd  # 战斗管理器（敌人生成、波次）
│   │
│   ├── projectiles/           # 抛射物系统
│   │   └── burst_projectile.gd
│   │
│   ├── boundaries/            # 边界系统
│   │   └── ellipse_boundary.gd
│   │
│   ├── camera/                # 相机系统
│   │   └── camera_controller.gd
│   │
│   ├── vfx/                   # 视觉特效
│   │   └── sword_trail.gd
│   │
│   └── upgrades/              # 升级系统（NEW）
│       ├── upgrade_data.gd        # 升级数据 Resource 类
│       └── upgrade_registry.gd    # 升级注册表（自动加载）
│
├── data/                      # 游戏数据（Resource 文件）
│   ├── characters/            # 角色配置
│   │   ├── kamisato_ayaka_character.tres  # 神里绫华角色数据
│   │   └── ayaka_stats.tres   # 神里绫华属性（NEW）
│   │
│   ├── enemies/               # 敌人配置
│   │   ├── normal_enemy.tres      # 普通敌人数据
│   │   ├── normal_enemy_stats.tres # 普通敌人属性（NEW）
│   │
│   ├── upgrades/              # 自定义升级配置（NEW）
│   │   └── example_custom_upgrade.tres  # 示例自定义升级
│   │
│   └── config/                # JSON 配置文件
│       └── map_config.json    # 地图生成配置
│
├── scenes/                    # 游戏场景
│   ├── ui/                    # UI 场景
│   │   ├── main_menu.tscn
│   │   ├── character_select.tscn
│   │   ├── map_view.tscn
│   │   ├── upgrade_selection.tscn
│   │   └── result_screen.tscn
│   │
│   ├── characters/            # 角色场景
│   │   ├── player.tscn
│   │   └── kamisato_ayaka.tscn
│   │
│   ├── enemies/               # 敌人场景
│   │   └── enemy.tscn
│   │
│   ├── battle/                # 战斗场景
│   │   └── battle_scene.tscn
│   │
│   └── map/                   # 地图场景
│       ├── map_node.tscn
│       └── map_room.tscn
│
├── textures/                  # 游戏贴图
│   ├── characters/            # 角色精灵图
│   ├── enemies/               # 敌人精灵图
│   ├── effects/               # 特效贴图
│   └── icons/                 # UI 图标
│
├── addons/                    # Godot 插件
│   └── agent/                 # AI 代理插件
│
├── project.godot              # Godot 项目配置
├── README.md                  # 用户文档
├── DEVELOPER_README.md        # 开发者文档（本文档）
├── REFACTORING_README.md      # 重构说明
├── DEBUG_TIPS.md              # 调试提示
└── CONTRIBUTING.md            # 贡献指南
```

---

## 核心系统

### 1. Autoload 单例系统

#### GameManager - 游戏状态管理器

**职责**：
- 管理游戏状态（主菜单、角色选择、地图、战斗、结算）
- 场景切换和加载
- 存档系统（结算记录）
- 游戏暂停和恢复

**关键方法**：
```gdscript
func go_to_main_menu() -> void            # 进入主菜单
func go_to_character_select() -> void     # 进入角色选择
func go_to_map_view() -> void             # 进入地图界面
func start_battle() -> void               # 开始战斗
func game_over() -> void                  # 游戏结束
func save_run_record(record: Dictionary)  # 保存结算记录
```

#### DataManager - 数据管理器

**职责**：
- 加载角色、敌人、配置数据
- 提供数据查询接口
- 数据缓存和验证

**关键方法**：
```gdscript
func load_all_data() -> void              # 加载所有数据
func get_character(id: String) -> CharacterData  # 获取角色
func get_enemy(id: String) -> EnemyData   # 获取敌人
func get_all_characters() -> Array[CharacterData]  # 获取所有角色
```

**数据加载流程**：
```
1. _ready() 触发
2. load_characters() - 扫描 data/characters/*.tres
3. load_enemies() - 扫描 data/enemies/*.tres
4. load_map_config() - 读取 map_config.json
5. emit data_loaded 信号
```

#### RunManager - 单局游戏状态管理器

**职责**：
- 管理当前角色、楼层、金币、血量
- 跟踪升级状态
- 统计数据（击杀数、伤害统计）
- 节点访问记录

**关键方法**：
```gdscript
func start_new_run(character: CharacterData)  # 开始新游戏
func end_run(victory: bool)                    # 结束游戏
func add_gold(amount: int)                     # 增加金币
func take_damage(amount: float)                # 受到伤害
func heal(amount: float)                       # 回复生命
func add_upgrade(upgrade_id: String)           # 添加升级
func get_upgrade_level(upgrade_id: String) -> int  # 获取升级等级
```

**信号系统**：
```gdscript
signal floor_changed(floor: int)
signal gold_changed(gold: int)
signal health_changed(current: float, maximum: float)
signal upgrade_added(upgrade_id: String)
```

---

### 2. 角色系统

#### 架构设计

```
CharacterData (Resource)
    ↓ 包含
CharacterStats (Resource) ← 统一属性系统
    ↓ 被使用
BaseCharacter (节点基类)
    ↓ 继承
KamisatoAyakaCharacter (具体角色)
```

#### CharacterData - 角色数据 Resource

**字段**：
```gdscript
@export var id: String                   # 角色唯一标识符
@export var display_name: String         # 显示名称
@export var description: String          # 描述文本
@export var icon: Texture2D              # 角色图标
@export var stats: CharacterStats        # 角色属性（必填）
@export var scene_path: String           # 角色场景路径
@export var abilities: Array[String]     # 技能列表（未来扩展）
```

**方法**：
```gdscript
func get_stats() -> CharacterStats       # 获取角色属性
func get_description() -> String         # 获取角色描述
```

#### CharacterStats - 角色属性系统（NEW）

**统一属性管理**：
```gdscript
# 生存属性
@export var max_health: float = 100.0           # 最大生命值
@export_range(0.0, 1.0) var defense_percent: float = 0.0  # 减伤比例

# 攻击属性
@export var attack: float = 25.0                # 基础攻击力
@export var attack_speed: float = 1.0           # 攻击速度倍率
@export var knockback_force: float = 150.0      # 击退力度

# 暴击属性
@export_range(0.0, 1.0) var crit_rate: float = 0.05      # 暴击率
@export var crit_damage: float = 0.5            # 暴击伤害倍率

# 移动属性
@export var move_speed: float = 100.0           # 移动速度
```

**核心方法**：
```gdscript
# 统一伤害计算公式
func calculate_damage(base_multiplier: float, target_defense: float, 
                      force_crit: bool, force_no_crit: bool) -> Array

# 计算受到的伤害（应用自身减伤）
func calculate_damage_taken(raw_damage: float) -> float

# 复制属性（用于运行时修改）
func duplicate_stats() -> CharacterStats

# 获取属性摘要（调试用）
func get_summary() -> String
```

**伤害计算公式**：
```
最终伤害 = 攻击力 × 攻击倍率 × 暴击倍率 × (1 - 目标减伤比例)

其中：
- 暴击倍率 = 1.0 + 暴击伤害（如果暴击）
- 暴击判定 = random() < 暴击率
```

#### BaseCharacter - 角色基类

**核心功能**：

1. **属性系统**：
   ```gdscript
   var character_data: CharacterData        # 角色数据引用
   var base_stats: CharacterStats           # 基础属性（不可修改）
   var current_stats: CharacterStats        # 当前属性（可被 buff 修改）
   ```

2. **移动系统**：
   ```gdscript
   func handle_movement() -> void           # WASD 移动
   func can_move() -> bool                  # 是否可移动（子类可重写）
   ```

3. **闪避系统**（右键）：
   ```gdscript
   @export var dodge_duration: float = 0.18        # 闪避持续时间
   @export var dodge_cooldown: float = 0.6         # 闪避冷却
   @export var dodge_distance: float = 120.0       # 闪避距离
   @export var dodge_speed_multiplier: float = 3.0 # 速度倍率
   ```
   - 无敌帧（dodge_invincible）
   - 穿怪能力（切换碰撞层）
   - 平滑速度曲线

4. **血量系统**：
   ```gdscript
   func take_damage(damage: float, knockback: Vector2)  # 受伤（应用减伤）
   func heal(amount: float)                             # 回复
   func start_invincibility()                           # 无敌状态
   ```

5. **伤害系统**：
   ```gdscript
   func deal_damage_to(target: Node, damage_multiplier: float, 
                       force_crit: bool, force_no_crit: bool) -> Array
   ```

6. **击退系统**：
   ```gdscript
   func apply_knockback(direction: Vector2, distance: float)  # 应用击退
   ```

7. **信号系统**：
   ```gdscript
   signal health_changed(current: float, maximum: float)
   signal character_died
   signal damage_dealt(damage: float, is_crit: bool, target: Node)
   ```

#### KamisatoAyakaCharacter - 神里绫华

**特色攻击系统**：

1. **第一段攻击**（单击左键）：
   - 向鼠标方向位移并挥剑
   - 位移距离可配置
   - 攻击倍率：1.0

2. **第二段攻击**（长按左键）：
   - 原地连续剑花攻击
   - 多段攻击（可配置段数）
   - 每段攻击倍率：0.5

3. **大招系统**（E 键）：
   - 冲锋 + 范围 AOE
   - 伤害倍率：2.0
   - 冷却时间可配置

---

### 3. 敌人系统

#### 架构设计

```
EnemyData (Resource)
    ↓ 包含
EnemyStats (Resource) ← 统一属性系统
    ↓ 被使用
BaseEnemy (节点基类)
    ↓ 继承
ChaseEnemy / RangedEnemy (具体敌人)
```

#### EnemyData - 敌人数据 Resource

**字段**：
```gdscript
@export var id: String                   # 敌人唯一标识符
@export var display_name: String         # 显示名称
@export var description: String          # 描述文本
@export var stats: EnemyStats            # 敌人属性（必填）
@export var warning_duration: float = 2.0  # 警告持续时间

# AI 配置
@export var behavior_type: String = "chase"  # AI 行为类型

# 掉落配置
@export var drop_gold: int = 10          # 掉落金币
@export var drop_exp: int = 1            # 掉落经验

# 场景配置
@export var scene_path: String           # 敌人场景路径
@export var enemy_type: String = "normal"  # 敌人类型（normal/boss）
```

#### EnemyStats - 敌人属性系统（NEW）

**字段**：
```gdscript
@export var max_health: float = 100.0           # 最大生命值
@export_range(0.0, 1.0) var defense_percent: float = 0.0  # 减伤比例
@export var attack: float = 25.0                # 基础攻击力
@export var move_speed: float = 100.0           # 移动速度
```

#### BaseEnemy - 敌人基类

**核心功能**：

1. **生成系统**：
   ```gdscript
   func spawn() -> void                 # 播放警告 → 显示敌人
   func _create_warning_sprite()        # 创建警告图标
   ```

2. **AI 系统**：
   ```gdscript
   func _update_ai(delta: float)        # AI 更新逻辑
   func _chase_player()                 # 追击玩家
   ```

3. **血量系统**：
   ```gdscript
   func take_damage(damage: float, knockback: Vector2)  # 受伤
   func update_hp_display()             # 更新 HP 条显示
   func die()                           # 死亡处理（掉落奖励）
   ```

4. **碰撞伤害**：
   ```gdscript
   func _on_body_entered(body: Node2D)  # 接触伤害
   ```

5. **信号系统**：
   ```gdscript
   signal enemy_died
   signal enemy_spawned
   ```

---

### 4. 地图系统

#### MapGenerator - 地图生成器

**生成算法**（类杀戮尖塔）：

```
楼层结构：
Floor 5:    [BOSS]              ← BOSS 层
Floor 4:    [节点] [节点] [节点]
Floor 3:    [节点] [节点] [节点] [节点]
Floor 2:    [节点] [节点] [节点]
Floor 1:    [节点] [节点]
Floor 0:    [起点]              ← 起始层
```

**配置文件**（`map_config.json`）：
```json
{
  "floors": 6,
  "min_nodes_per_floor": 2,
  "max_nodes_per_floor": 4,
  "boss_floor": 5,
  "node_weights": {
    "enemy": 50,
    "shop": 10,
    "rest": 10,
    "event": 15
  }
}
```

**核心方法**：
```gdscript
func generate_map() -> Dictionary        # 生成完整地图
func _generate_floor(floor_num: int) -> Array[MapNode]  # 生成单层
func _select_node_type(floor: int) -> String  # 选择节点类型
func _connect_nodes(floor_nodes, next_floor_nodes)  # 连接节点
```

#### MapNode - 地图节点

**节点类型**：
```gdscript
enum NodeType {
    ENEMY,      # 普通战斗
    SHOP,       # 商店
    REST,       # 休息处
    EVENT,      # 奇遇事件
    BOSS,       # BOSS 战
    START       # 起点
}
```

**状态管理**：
```gdscript
var is_visited: bool = false             # 是否已访问
var is_accessible: bool = false          # 是否可访问
var connected_nodes: Array[MapNode]      # 连接的节点
```

---

### 5. 战斗系统

#### BattleManager - 战斗管理器

**职责**：
- 敌人波次生成
- 战斗胜利/失败判定
- 战斗奖励发放
- 战斗结束处理

**核心流程**：
```gdscript
func start_battle(node_type: String) -> void:
    # 1. 根据节点类型生成敌人
    # 2. 初始化战斗状态
    # 3. 开始敌人生成

func spawn_wave() -> void:
    # 生成当前波次的敌人

func _on_all_enemies_defeated() -> void:
    # 1. 发放奖励（金币）
    # 2. 显示升级选择界面
    # 3. 更新 RunManager 统计

func _on_player_died() -> void:
    # 游戏结束
```

---

## 升级系统（NEW）

### 系统架构

```
UpgradeData (Resource)           # 升级数据定义
    ↓ 被注册到
UpgradeRegistry (Autoload)       # 升级注册表（管理所有升级）
    ↓ 提供升级给
upgrade_selection.gd             # 升级选择界面
    ↓ 选择后通知
RunManager (Autoload)            # 记录已获得的升级
    ↓ 应用升级到
BaseCharacter / 子类             # 角色属性实际生效
```

### UpgradeData - 升级数据 Resource

**核心字段**：
```gdscript
# 基础信息
@export var id: String                    # 升级唯一标识符
@export var display_name: String          # 显示名称
@export var description: String           # 描述（支持 {value} 占位符）

# 升级配置
@export var upgrade_type: UpgradeType     # 类型（固定值/百分比/技能/特殊）
@export var rarity: Rarity                # 稀有度（影响出现概率）
@export var target_stat: TargetStat       # 目标属性
@export var max_level: int                # 最大等级
@export var value_per_level: float        # 每级数值

# 条件限制
@export var required_character_ids: Array[String]  # 限定角色
@export var required_upgrade_ids: Array[String]    # 前置升级
@export var exclusive_upgrade_ids: Array[String]   # 互斥升级
@export var min_floor: int                         # 最低楼层要求

# 分类标签
@export var tags: Array[String]           # 用于筛选和分类
```

### UpgradeRegistry - 升级注册表

**作为自动加载单例使用**。

**核心方法**：
```gdscript
# 注册升级
func register_upgrade(upgrade: UpgradeData) -> void

# 查询升级
func get_upgrade(id: String) -> UpgradeData
func get_all_upgrades() -> Array[UpgradeData]
func get_upgrades_by_tag(tag: String) -> Array[UpgradeData]

# 随机选取升级（带权重和条件过滤）
func pick_random_upgrades(
    character_id: String,
    current_upgrades: Dictionary,
    current_floor: int,
    count: int = 3
) -> Array[UpgradeData]
```

### 内置升级列表

| 分类 | 升级ID | 名称 | 效果 | 稀有度 |
|------|--------|------|------|--------|
| 基础 | health_flat | 生命强化 | +20 最大生命 | 普通 |
| 基础 | health_percent | 生命提升 | +10% 最大生命 | 稀有 |
| 基础 | attack_flat | 攻击强化 | +5 攻击力 | 普通 |
| 基础 | attack_percent | 攻击提升 | +10% 攻击力 | 稀有 |
| 基础 | defense | 防御提升 | +5% 减伤 | 稀有 |
| 移动 | move_speed_flat | 迅捷 | +15 移动速度 | 普通 |
| 移动 | move_speed_percent | 疾风 | +10% 移动速度 | 精良 |
| 攻速 | attack_speed | 攻速提升 | +10% 攻击速度 | 稀有 |
| 暴击 | crit_rate | 暴击率提升 | +5% 暴击率 | 稀有 |
| 暴击 | crit_damage | 暴击伤害提升 | +15% 暴击伤害 | 稀有 |
| 闪避 | dodge_distance | 闪避距离 | +20 闪避距离 | 稀有 |
| 闪避 | dodge_cooldown | 闪避冷却 | -0.1秒 冷却 | 精良 |
| 技能 | skill_damage | 技能伤害 | +15% 技能伤害 | 精良 |
| 技能 | skill_cooldown | 技能冷却 | -10% 冷却 | 精良 |
| 技能 | skill_radius | 技能范围 | +15% 技能范围 | 精良 |
| 大招 | burst_damage | 大招伤害 | +20% 大招伤害 | 史诗 |
| 大招 | energy_gain | 充能效率 | +20% 充能 | 精良 |

### 升级应用流程

```
1. 玩家在升级选择界面选择升级
2. upgrade_selection.gd 调用 RunManager.add_upgrade(id, 1)
3. RunManager._recalculate_stat_bonuses() 重新计算所有加成
4. RunManager.apply_upgrades_to_character(character) 应用到角色
5. BaseCharacter.apply_upgrades(run_manager) 更新角色属性
6. 角色的 current_stats 被更新，技能倍率生效
```

### 扩展升级系统

#### 添加自定义效果升级

如果需要实现无法通过属性加成表达的效果（如"击杀敌人回复生命"），可以：

1. 创建升级时设置 `upgrade_type = UpgradeType.CUSTOM`
2. 在角色或系统代码中检查升级等级并实现效果：

```gdscript
# 在 BaseEnemy.die() 中
func die() -> void:
    # ... 原有代码 ...
    
    # 检查自定义升级
    if RunManager:
        var lifesteal_level = RunManager.get_upgrade_level("lifesteal_on_kill")
        if lifesteal_level > 0:
            var player = get_tree().get_first_node_in_group("player")
            if player and player.has_method("heal"):
                player.heal(5.0 * lifesteal_level)
```

---

## 属性系统

### 为什么需要统一属性系统？

**旧版问题**：
- 属性字段分散在各个类中
- 伤害计算逻辑重复
- 难以添加新属性（如暴击、减伤）
- buff/debuff 系统难以实现

**新版解决方案**：
- CharacterStats/EnemyStats 统一管理所有属性
- 统一的伤害计算公式
- 基础属性（base_stats）和当前属性（current_stats）分离
- 便于实现 buff/debuff 系统

### 属性修改流程

#### 修改角色生命上限

**方法 1**：在编辑器中修改（推荐）
1. 打开 `data/characters/ayaka_stats.tres`
2. 找到 `max_health` 字段
3. 修改数值（例如：100.0 → 200.0）
4. 保存

**方法 2**：通过代码修改运行时属性
```gdscript
# 永久修改（修改基础属性）
character.base_stats.max_health = 200.0
character.current_stats.max_health = 200.0
character.max_health = 200.0

# 临时修改（buff）
character.current_stats.max_health += 50.0
character.max_health = character.current_stats.max_health
```

#### 添加 Buff/Debuff

```gdscript
# BaseCharacter 提供的方法
func add_attack(amount: float)              # 增加攻击力
func add_crit_rate(amount: float)           # 增加暴击率
func add_crit_damage(amount: float)         # 增加暴击伤害
func add_defense_percent(amount: float)     # 增加减伤
func add_move_speed(amount: float)          # 增加移动速度
func add_attack_speed(amount: float)        # 增加攻击速度
func reset_stats_to_base()                  # 重置属性到基础值

# 使用示例
player.add_attack(10.0)                     # 增加 10 点攻击力
player.add_crit_rate(0.1)                   # 增加 10% 暴击率
```

### 升级系统集成

升级通过 RunManager 管理：

```gdscript
# 在 upgrade_selection.gd 中
func apply_upgrade(upgrade_id: String) -> void:
    var player = get_tree().get_first_node_in_group("player") as BaseCharacter
    
    match upgrade_id:
        "damage":
            player.add_attack(5.0)           # 增加攻击力
        "health":
            player.current_stats.max_health += 20.0
            player.max_health = player.current_stats.max_health
            player.heal(20.0)                # 回复并提升上限
        "crit":
            player.add_crit_rate(0.05)       # 增加 5% 暴击率
    
    RunManager.add_upgrade(upgrade_id)       # 记录升级
```

---

## 开发工作流

### 添加新角色

#### 步骤 1：创建属性资源

在编辑器中：
1. 右键 `data/characters/` → "新建资源"
2. 选择 `CharacterStats`
3. 命名为 `new_character_stats.tres`
4. 配置属性值

#### 步骤 2：创建角色数据

1. 右键 `data/characters/` → "新建资源"
2. 选择 `CharacterData`
3. 命名为 `new_character.tres`
4. 配置字段：
   ```
   id: "new_character"
   display_name: "新角色"
   description: "角色描述"
   stats: 拖入 new_character_stats.tres
   scene_path: "res://scenes/characters/new_character.tscn"
   ```

#### 步骤 3：创建角色场景（可选）

如果需要自定义逻辑：

```gdscript
# scripts/characters/new_character.gd
extends BaseCharacter
class_name NewCharacter

func perform_attack() -> void:
    # 实现自定义攻击逻辑
    pass
```

#### 步骤 4：测试

在 DataManager 会自动扫描 `data/characters/*.tres` 并加载。

---

### 添加新敌人

#### 步骤 1：创建敌人属性

```gdscript
# 在编辑器中创建 EnemyStats 资源
# data/enemies/new_enemy_stats.tres
max_health = 150.0
attack = 30.0
move_speed = 80.0
defense_percent = 0.1  # 10% 减伤
```

#### 步骤 2：创建敌人数据

```gdscript
# data/enemies/new_enemy.tres
id = "new_enemy"
display_name = "新敌人"
stats = new_enemy_stats.tres
behavior_type = "chase"
drop_gold = 15
enemy_type = "normal"
```

#### 步骤 3：创建自定义 AI（可选）

```gdscript
# scripts/enemies/new_enemy.gd
extends BaseEnemy
class_name NewEnemy

func _update_ai(delta: float) -> void:
    # 实现自定义 AI 逻辑
    # 例如：远程攻击、特殊技能等
    pass
```

---

### 添加新升级选项

升级系统使用 `UpgradeData` 资源类和 `UpgradeRegistry` 注册表管理。

#### 方法 1：在代码中注册（推荐用于通用升级）

在 `scripts/upgrades/upgrade_registry.gd` 的 `_register_builtin_upgrades()` 方法中添加：

```gdscript
_register_upgrade(_create_stat_upgrade(
    "new_upgrade_id",           # 升级唯一ID
    "新升级名称",                # 显示名称
    "增加 {value} 某属性",       # 描述（支持占位符）
    UpgradeData.TargetStat.ATTACK,  # 目标属性
    UpgradeData.UpgradeType.STAT_FLAT,  # 升级类型
    10.0,                        # 每级数值
    5,                           # 最大等级
    UpgradeData.Rarity.RARE,     # 稀有度
    ["offensive", "custom"]      # 标签
))
```

#### 方法 2：通过资源文件添加（推荐用于自定义/角色专属升级）

1. 在 `data/upgrades/` 目录下创建 `.tres` 文件
2. 设置脚本为 `UpgradeData`
3. 配置升级属性

示例：`data/upgrades/custom_upgrade.tres`
```
[gd_resource type="Resource" script_class="UpgradeData"]

[ext_resource type="Script" path="res://scripts/upgrades/upgrade_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "custom_upgrade"
display_name = "自定义升级"
description = "增加 {value} 攻击力"
upgrade_type = 0  # STAT_FLAT
rarity = 2        # RARE
target_stat = 1   # ATTACK
max_level = 3
value_per_level = 15.0
required_character_ids = []  # 空数组 = 所有角色可用
tags = ["custom", "offensive"]
```

#### 升级类型说明

| 类型 | 枚举值 | 说明 |
|------|--------|------|
| STAT_FLAT | 0 | 固定值加成（如 +20 生命） |
| STAT_PERCENT | 1 | 百分比加成（如 +10% 攻击） |
| ABILITY | 2 | 技能相关（技能范围、冷却等） |
| SPECIAL | 3 | 特殊效果（闪避距离等） |
| CUSTOM | 4 | 自定义效果（需要代码实现） |

#### 目标属性说明

| 属性 | 枚举值 | 说明 |
|------|--------|------|
| MAX_HEALTH | 0 | 最大生命值 |
| ATTACK | 1 | 攻击力 |
| DEFENSE_PERCENT | 2 | 减伤比例 |
| MOVE_SPEED | 3 | 移动速度 |
| ATTACK_SPEED | 4 | 攻击速度 |
| CRIT_RATE | 5 | 暴击率 |
| CRIT_DAMAGE | 6 | 暴击伤害 |
| DODGE_DISTANCE | 8 | 闪避距离 |
| SKILL_DAMAGE | 11 | 技能伤害倍率 |
| SKILL_COOLDOWN | 12 | 技能冷却时间 |
| SKILL_RADIUS | 13 | 技能范围 |
| BURST_DAMAGE | 14 | 大招伤害倍率 |
| ENERGY_GAIN | 16 | 充能效率 |

#### 稀有度说明

| 稀有度 | 枚举值 | 颜色 | 权重倍率 |
|--------|--------|------|----------|
| COMMON | 0 | 白色 | 1.0 |
| UNCOMMON | 1 | 绿色 | 0.7 |
| RARE | 2 | 蓝色 | 0.4 |
| EPIC | 3 | 紫色 | 0.15 |
| LEGENDARY | 4 | 橙色 | 0.05 |

#### 角色专属升级

在升级数据中设置 `required_character_ids` 可以限制升级只对特定角色可用：

```gdscript
var ayaka_upgrade = _create_stat_upgrade(...)
ayaka_upgrade.required_character_ids = ["kamisato_ayaka"]  # 只对神里绫华可用
_register_upgrade(ayaka_upgrade)
```

---

### 修改地图生成规则

编辑 `data/config/map_config.json`：

```json
{
  "floors": 8,                    // 增加楼层数
  "min_nodes_per_floor": 3,       // 每层最少节点
  "max_nodes_per_floor": 5,       // 每层最多节点
  "boss_floor": 7,                // BOSS 楼层
  "node_weights": {
    "enemy": 50,
    "shop": 15,
    "rest": 10,
    "event": 10
  }
}
```

---

## 重构回归与性能基线（务必先看）

> 本节用于“重构不改玩法”的验收，以及性能对比。每完成一个重构阶段，都至少跑一遍回归清单，并记录关键观测点的数值/体感变化。

### 回归手测清单（核心玩法流程）

- **启动**：启动项目后能进入主菜单（无报错/无卡死）。
- **选角**：进入角色选择界面，选择任意角色并确认。
- **进入地图**：进入地图界面后，地图能正常生成与显示（节点/连线/楼层文字正确）。
- **选择第1层节点**：可点击第1层可选节点，点击后：
  - 楼层数更新
  - 当前节点被标记“已访问”
  - 下一步可选节点状态更新
- **进入战斗**：选择“普通战斗”节点后进入战斗场景：
  - 玩家正确生成（血量 UI 正确）
  - 敌人会按计时器生成
- **战斗胜利**：击杀达到胜利条件后：
  - 清场成功（敌人消失）
  - 进入升级选择界面
- **升级**：选择升级后能够返回地图或继续流程（依当前实现）。
- **战斗失败**：玩家死亡后能触发失败流程（游戏结束→结算/回到地图，依当前实现）。

### 性能观测点（重构前后对比）

**重点场景**
- **地图界面**：首次进入、从战斗返回后再次进入、刷新/重绘节点与连线时。
- **战斗界面**：刷怪高峰（怪多的时候）、结算清场、切场景瞬间（尖峰）。

**重点指标（建议记录）**
- **帧率与帧时间**：是否出现明显掉帧/卡顿尖峰（尤其是 16ms→50ms+ 的瞬间）。
- **节点数量**：地图界面节点数量（MapNode/UI/Line2D）是否明显下降。
- **GC/内存尖峰**：地图显示/战斗清场时是否出现明显内存抖动。

### 推荐观测方法

- **Godot Profiler**：运行项目后打开 Profiler，关注 Frame Time、Physics、Script、Rendering 的尖峰来源。
- **日志打点（可开关）**：在地图生成/显示、战斗刷怪/清场等关键路径加计时日志（后续重构阶段会逐步补齐统一的轻量计时工具）。

---

## 代码规范

### GDScript 风格指南

#### 命名规范

```gdscript
# 类名：PascalCase
class_name BaseCharacter

# 常量：UPPER_SNAKE_CASE
const MAX_ENEMIES: int = 10
const PLAYER_COLLISION_LAYER: int = 4

# 变量和函数：snake_case
var current_health: float
func take_damage(amount: float) -> void

# 私有变量/函数：前缀 _
var _is_dodging: bool
func _update_dodge(delta: float) -> void

# 导出变量：使用类型提示
@export var max_health: float = 100.0
@export var move_speed: float = 100.0
```

#### 注释规范

```gdscript
## 类文档注释（使用 ##）
## 这是一个角色基类，包含所有角色的通用逻辑
class_name BaseCharacter extends CharacterBody2D

## 公共方法文档注释
## target: 目标节点
## damage_multiplier: 伤害倍率
## 返回值: [实际伤害, 是否暴击]
func deal_damage_to(target: Node, damage_multiplier: float) -> Array:
    # 单行解释性注释（使用 #）
    var result = current_stats.calculate_damage(damage_multiplier)
    return result
```

#### 代码组织

```gdscript
extends CharacterBody2D
class_name BaseCharacter

# ========== 导出变量 ==========
@export var max_health: float = 100.0
@export var move_speed: float = 100.0

# ========== 私有变量 ==========
var _is_dodging: bool = false

# ========== 公共变量 ==========
var current_health: float

# ========== 信号 ==========
signal health_changed(current: float, maximum: float)
signal character_died

# ========== 生命周期方法 ==========
func _ready() -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

# ========== 公共方法 ==========
func take_damage(amount: float) -> void:
    pass

# ========== 私有方法 ==========
func _update_dodge(delta: float) -> void:
    pass
```

### 最佳实践

#### 1. 使用类型提示

```gdscript
# ✅ 好
func get_stats() -> CharacterStats:
    return stats

var player: BaseCharacter = get_node("Player")

# ❌ 差
func get_stats():
    return stats

var player = get_node("Player")
```

#### 2. 使用信号进行通信

```gdscript
# ✅ 好 - 使用信号
signal health_changed(current: float, maximum: float)

func take_damage(amount: float) -> void:
    current_health -= amount
    emit_signal("health_changed", current_health, max_health)

# ❌ 差 - 直接调用 UI
func take_damage(amount: float) -> void:
    current_health -= amount
    get_node("/root/UI/HPBar").update_value(current_health)
```

#### 3. 数据驱动设计

```gdscript
# ✅ 好 - 使用 Resource
var character_data: CharacterData = load("res://data/characters/ayaka.tres")

# ❌ 差 - 硬编码
var max_health: float = 100.0
var move_speed: float = 100.0
```

#### 4. 避免硬编码

```gdscript
# ✅ 好
const PLAYER_GROUP: String = "player"
var player = get_tree().get_first_node_in_group(PLAYER_GROUP)

# ❌ 差
var player = get_node("/root/BattleScene/Player")
```

---

## 常见问题

### Q1: 如何快速修改角色生命值？

**A**: 打开 `data/characters/ayaka_stats.tres`，修改 `max_health` 字段。

### Q2: 如何添加新的属性（如吸血、护盾）？

**A**: 
1. 在 `CharacterStats` 中添加新字段
2. 在 `BaseCharacter` 中实现相关逻辑
3. 更新伤害计算公式（如果需要）

### Q3: 如何调整敌人难度？

**A**: 修改 `data/enemies/*_stats.tres` 中的属性值，或在 `BattleManager` 中调整生成数量。

### Q4: 如何禁用闪避系统？

**A**: 在 `BaseCharacter` 中：
```gdscript
func can_dodge() -> bool:
    return false  # 禁用闪避
```

### Q5: 如何添加新的节点类型？

**A**:
1. 在 `MapNode.NodeType` 枚举中添加新类型
2. 在 `map_config.json` 中添加权重
3. 在 `MapGenerator._select_node_type()` 中添加选择逻辑
4. 在相应的 UI 中处理点击事件

### Q6: 如何实现多人模式？

**A**: 当前架构不支持。需要重构为服务器-客户端架构，使用 Godot 的网络系统。

---

## 调试指南

### 常见错误

#### 错误 1：Cannot get class 'CharacterData'

**原因**：Resource 类未正确注册

**解决**：
1. 确保脚本顶部有 `class_name CharacterData`
2. 重启 Godot 编辑器
3. 重新导入资源文件

#### 错误 2：场景加载失败

**原因**：场景路径错误

**解决**：
```gdscript
# 在 CharacterData 中检查
scene_path = "res://scenes/characters/kamisato_ayaka.tscn"  # 确保路径正确
```

#### 错误 3：Autoload 单例未找到

**原因**：project.godot 中未配置 Autoload

**解决**：
```ini
[autoload]
GameManager="*res://scripts/autoload/game_manager.gd"
DataManager="*res://scripts/autoload/data_manager.gd"
RunManager="*res://scripts/autoload/run_manager.gd"
```

### 调试技巧

#### 1. 启用详细日志

在关键位置添加 print 语句：

```gdscript
func initialize(data: CharacterData) -> void:
    print("角色初始化：", data.display_name)
    print("属性：", current_stats.get_summary())
```

#### 2. 使用断言验证数据

```gdscript
func initialize(data: CharacterData) -> void:
    assert(data != null, "CharacterData 不能为空")
    assert(data.stats != null, "CharacterStats 不能为空")
```

#### 3. 检查节点树

```gdscript
func _ready() -> void:
    print("节点树：")
    print_tree_pretty()
```

#### 4. 使用 Godot 调试器

- 设置断点（点击行号）
- F10：单步执行
- F11：步入函数
- 检查变量值

### 性能优化

#### 1. 对象池（敌人/子弹）

```gdscript
# 避免频繁创建销毁
var _enemy_pool: Array[BaseEnemy] = []

func get_enemy() -> BaseEnemy:
    if _enemy_pool.is_empty():
        return preload("res://scenes/enemies/enemy.tscn").instantiate()
    else:
        return _enemy_pool.pop_back()

func return_enemy(enemy: BaseEnemy) -> void:
    enemy.visible = false
    _enemy_pool.append(enemy)
```

#### 2. 信号连接清理

```gdscript
func _exit_tree() -> void:
    # 断开所有信号连接
    if health_changed.is_connected(some_function):
        health_changed.disconnect(some_function)
```

#### 3. 使用组（Groups）而非查找节点

```gdscript
# ✅ 好
var player = get_tree().get_first_node_in_group("player")

# ❌ 差
var player = get_node("/root/BattleScene/Player")
```

---

## 扩展阅读

- [Godot 官方文档](https://docs.godotengine.org/)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot 设计模式](https://github.com/gdquest-demos/godot-design-patterns)

---

## 联系方式

- **GitHub Issues**: 报告 Bug 和功能请求
- **Discussions**: 技术讨论和问答
- **开发者**: kuchao

---

**最后更新**: 2026-01-20

**版本**: 1.4.0

**Godot 版本**: 4.5+
