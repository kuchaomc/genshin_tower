# Genshin Roguelike Game

一个使用 Godot 引擎开发的类杀戮尖塔风格的 Roguelike 动作游戏。

![Godot Version](https://img.shields.io/badge/Godot-4.5-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Mobile-lightgrey.svg)

## 📖 项目简介

这是一个受《杀戮尖塔》启发的 Roguelike 动作游戏，结合了卡牌游戏的策略性和动作游戏的爽快感。玩家需要选择角色，在地图上探索不同的节点，与敌人战斗，获得升级，最终挑战 BOSS。

## ✨ 主要特性

### 🎮 核心玩法
- **角色选择系统** - 选择不同的角色开始冒险，每个角色都有独特的属性和技能
- **类杀戮尖塔地图** - 垂直爬塔式地图系统，每层都有多个节点供玩家选择
- **多样化节点类型**：
  - 🗡️ 普通战斗 - 与普通敌人战斗
  - 🏪 商店 - 购买道具和升级
  - 🛌 休息处 - 回复生命值
  - 🎲 奇遇事件 - 随机事件
  - 👹 BOSS战 - 最终挑战

### ⚔️ 战斗系统
- **两段攻击系统** - 第一段位移挥剑，第二段原地剑花攻击
- **多种敌人类型** - 普通敌人、BOSS，每种都有不同的行为模式
- **实时战斗** - 流畅的动作战斗体验

### 📈 成长系统
- **角色升级** - 战斗后可以选择不同的升级选项
- **能力提升** - 伤害、生命值、速度等多种属性升级
- **结算记录** - 记录每局游戏的统计数据

### 🏗️ 技术特性
- **模块化架构** - 清晰的代码结构，易于扩展和维护
- **数据驱动设计** - 使用 Resource 和 JSON 配置，方便调整游戏平衡
- **可扩展系统** - 基类设计便于添加新角色和敌人

## 🚀 快速开始

### 环境要求

- **Godot 引擎**: 4.5 或更高版本
- **操作系统**: Windows / Linux / macOS / Mobile

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/kuchaomc/genshin_tower.git
   cd genshin_game
   ```

2. **使用 Godot 打开项目**
   - 下载并安装 [Godot 4.5](https://godotengine.org/download)
   - 打开 Godot 编辑器
   - 点击"导入"按钮，选择项目根目录
   - 选择 `project.godot` 文件

3. **运行游戏**
   - 在 Godot 编辑器中点击"运行项目"按钮（F5）
   - 或直接运行 `release/` 目录下的可执行文件（暂未发布）

## 🎯 游戏玩法

### 基本操作

- **WASD** - 移动角色
- **鼠标左键** - 攻击
  - 单击：第一段攻击（位移挥剑）
  - 按住：第二段攻击（原地剑花）

### 游戏流程

1. **选择角色** - 在主界面选择你喜欢的角色
2. **探索地图** - 在地图上选择要前往的节点
3. **战斗** - 击败敌人获得金币和经验
4. **升级** - 选择能力升级提升角色实力
5. **挑战BOSS** - 到达顶层挑战最终BOSS

## 📁 项目结构

```
genshin_game/
├── scripts/              # 游戏脚本
│   ├── autoload/        # 全局单例（GameManager, DataManager, RunManager）
│   ├── characters/      # 角色系统
│   ├── enemies/         # 敌人系统
│   ├── map/            # 地图系统
│   ├── ui/             # UI界面
│   └── battle_manager.gd # 战斗管理器
├── scenes/              # 游戏场景
│   ├── 主界面.tscn
│   ├── 角色选择.tscn
│   ├── 地图.tscn
│   ├── 游戏场景.tscn
│   └── ...
├── data/                # 游戏数据
│   ├── characters/     # 角色配置
│   ├── enemies/        # 敌人配置
│   └── config/         # JSON配置
├── textures/            # 游戏贴图
└── project.godot        # Godot项目配置
```

## 🛠️ 开发指南

### 添加新角色

1. 创建角色数据 Resource (`data/characters/new_character.tres`)
2. 创建角色场景 (`scenes/characters/new_character.tscn`)
3. 可选：创建新的角色类继承 `BaseCharacter` (`scripts/characters/new_character.gd`)

### 添加新敌人

1. 创建敌人数据 Resource (`data/enemies/new_enemy.tres`)
2. 可选：创建新的敌人类继承 `BaseEnemy` (`scripts/enemies/new_enemy.gd`)

### 修改地图配置

编辑 `data/config/map_config.json` 文件来调整：
- 楼层数量
- 每层节点数量
- 节点类型权重
- BOSS楼层

## 🎨 技术栈

- **引擎**: Godot 4.5
- **语言**: GDScript
- **架构**: 模块化、数据驱动
- **设计模式**: 单例模式、基类继承、信号系统

## 📝 开发计划

- [ ] 完善商店系统
- [ ] 实现休息处功能
- [ ] 添加更多奇遇事件
- [ ] 实现更多角色类型
- [ ] 添加更多敌人AI行为
- [ ] 完善技能系统
- [ ] 添加音效和背景音乐
- [ ] 优化UI界面

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 使用有意义的变量和函数名
- 添加必要的注释（特别是复杂逻辑）
- 遵循 GDScript 编码规范
- 确保代码可以正常运行

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 👥 作者

- **开发者** - [kuchao](https://github.com/kuchaomc)

## 🙏 致谢

- 感谢 [Godot Engine](https://godotengine.org/) 提供优秀的游戏引擎
- 灵感来源于《杀戮尖塔》(Slay the Spire)
- 感谢所有贡献者和测试者

## 📞 联系方式

- **Issues**: [GitHub Issues](https://github.com/kuchaomc/genshin_tower/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kuchaomc/genshin_tower/discussions)

---

如果这个项目对你有帮助，请给个 ⭐ Star！
