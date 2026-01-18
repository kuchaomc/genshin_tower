# 游戏架构重构说明

## 重构概述

本次重构将项目从单一脚本架构重构为模块化、可扩展的架构，支持以下功能：
- 选择角色功能
- 类杀戮尖塔地图功能
- 不同敌人类型
- 角色能力升级
- 结算记录

## 新目录结构

```
scripts/
├── autoload/           # 全局单例
│   ├── game_manager.gd    # 游戏状态、场景切换、存档
│   ├── data_manager.gd    # 数据加载（角色、敌人、配置）
│   └── run_manager.gd     # 单局游戏状态管理
├── characters/         # 角色系统
│   ├── character_data.gd  # 角色数据Resource
│   ├── ability_data.gd     # 技能数据Resource
│   ├── base_character.gd  # 角色基类
│   └── sword_character.gd # 剑士角色实现
├── enemies/            # 敌人系统
│   ├── enemy_data.gd      # 敌人数据Resource
│   └── base_enemy.gd      # 敌人基类
├── map/               # 地图系统
│   ├── map_generator.gd   # 地图生成器
│   └── map_node.gd        # 地图节点
├── ui/                # UI脚本
│   ├── character_select.gd # 角色选择界面
│   ├── map_view.gd        # 地图界面
│   ├── result_screen.gd    # 结算界面
│   └── upgrade_selection.gd # 升级选择界面
└── battle_manager.gd  # 战斗管理器

data/
├── characters/        # 角色配置 (.tres)
│   └── sword_character.tres
├── enemies/           # 敌人配置 (.tres)
│   ├── normal_enemy.tres
│   └── elite_enemy.tres
└── config/            # JSON配置
    └── map_config.json
```

## 核心系统说明

### 1. Autoload单例

#### GameManager
- 管理游戏状态和场景切换
- 处理存档和结算记录
- 提供场景切换方法（go_to_main_menu, go_to_character_select等）

#### DataManager
- 加载角色、敌人和配置数据
- 提供数据查询接口（get_character, get_enemy等）

#### RunManager
- 管理单局游戏状态（当前角色、楼层、金币、血量等）
- 跟踪统计数据（击杀数、伤害等）
- 管理升级系统

### 2. 角色系统

#### CharacterData (Resource)
存储角色的基础属性：
- id, display_name, description
- max_health, move_speed, base_damage
- scene_path（角色场景路径）

#### BaseCharacter
角色基类，包含：
- 通用移动逻辑
- 血量管理
- 动画处理
- 伤害和回复

#### SwordCharacter
剑士角色实现：
- 两段攻击系统（位移挥剑 + 原地剑花）
- 继承自BaseCharacter

### 3. 敌人系统

#### EnemyData (Resource)
存储敌人的基础属性：
- id, display_name
- max_health, damage, move_speed
- behavior_type（AI行为类型）
- drop_gold, drop_exp

#### BaseEnemy
敌人基类，包含：
- 警告系统
- 血量管理
- 基础AI（追逐玩家）
- 碰撞伤害

### 4. 地图系统

#### MapGenerator
生成类杀戮尖塔风格的垂直地图：
- 支持多楼层
- 每层随机节点数量
- 节点类型权重系统
- 节点连接逻辑

#### MapNode
地图节点：
- 节点类型（ENEMY, ELITE, SHOP, REST, EVENT, BOSS）
- 节点UI显示
- 访问状态管理

### 5. UI系统

#### 角色选择界面
- 显示所有可用角色
- 角色属性展示
- 角色选择确认

#### 地图界面
- 显示生成的地图
- 节点选择和导航
- 楼层显示

#### 结算界面
- 显示游戏统计数据
- 胜利/失败状态
- 返回主菜单

#### 升级选择界面
- 随机3个升级选项
- 升级效果说明
- 升级等级管理

## 使用流程

1. **主菜单** → 点击"开始游戏"
2. **角色选择** → 选择角色 → 确认
3. **地图界面** → 选择节点
4. **战斗/商店/休息** → 根据节点类型进入相应场景
5. **战斗后** → 返回地图或显示结算

## 扩展指南

### 添加新角色

1. 创建角色数据Resource（data/characters/new_character.tres）
2. 创建角色场景（scenes/characters/new_character.tscn）
3. 可选：创建新的角色类继承BaseCharacter（scripts/characters/new_character.gd）

### 添加新敌人

1. 创建敌人数据Resource（data/enemies/new_enemy.tres）
2. 可选：创建新的敌人类继承BaseEnemy（scripts/enemies/new_enemy.gd）
3. 在场景中使用BaseEnemy或新敌人类

### 添加新升级

在`scripts/ui/upgrade_selection.gd`的UPGRADES字典中添加新升级定义

### 修改地图生成规则

编辑`data/config/map_config.json`文件

## 注意事项

1. 所有Autoload单例需要在project.godot中配置
2. 角色和敌人数据使用Resource系统，需要在编辑器中创建.tres文件
3. 地图配置使用JSON格式，便于外部编辑
4. 战斗场景需要BattleManager脚本来管理战斗逻辑

## 待完善功能

- [ ] 商店系统实现
- [ ] 休息处系统实现
- [ ] 奇遇事件系统实现
- [ ] BOSS战特殊逻辑
- [ ] 更多角色类型
- [ ] 更多敌人类型和AI行为
- [ ] 技能系统完善
- [ ] 存档系统完善（保存游戏进度）
