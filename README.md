# 杀原戮神尖塔（Genshin Roguelike Game）

一个使用 Godot 引擎开发的类杀戮尖塔风格的 Roguelike 动作游戏。

![Godot Version](https://img.shields.io/badge/Godot-4.5-blue.svg)
![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Mobile-lightgrey.svg)

## 📚 文档导航

- **开发者文档**：[`DEVELOPER_README.md`](DEVELOPER_README.md)
- **调试提示**：[`DEBUG_TIPS.md`](DEBUG_TIPS.md)
- **贡献指南**：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- **奇遇事件系统**：[`scripts/events/README.md`](scripts/events/README.md)
- **调试日志系统**：[`调试日志使用说明.md`](调试日志使用说明.md)
- **运行时日志系统**：[`运行时日志使用说明.md`](运行时日志使用说明.md)

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

- **Godot 引擎**: Godot 4.5 stable
- **操作系统**: Windows（主要）/ Mobile（目标），其它平台未完整验证

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/kuchaomc/genshin_tower.git
   cd genshin_tower
   ```

2. **使用 Godot 打开项目**
   - 下载并安装 [Godot 4.5](https://godotengine.org/download)
   - 打开 Godot 编辑器
   - 点击"导入"按钮，选择项目根目录
   - 选择 `project.godot` 文件

3. **运行游戏**
   - 在 Godot 编辑器中点击"运行项目"按钮（F5）
   - 导出/打包请参考 `export_presets.cfg`（可在 Godot 的“项目 -> 导出”中操作）

## 🎯 游戏玩法

### 基本操作

- **WASD** - 移动角色
- **鼠标左键** - 攻击
  - 单击：第一段攻击（位移挥剑）
  - 按住：第二段攻击（原地剑花）
- **鼠标右键** - 闪避（如角色支持）
- **E / Q** - 技能（以角色实现为准）
- **ESC** - 暂停菜单
- **Y** - 保存调试日志（详见《调试日志系统使用说明》）

### 游戏流程

1. **选择角色** - 在主界面选择你喜欢的角色
2. **探索地图** - 在地图上选择要前往的节点
3. **战斗** - 击败敌人获得金币和经验
4. **升级** - 选择能力升级提升角色实力
5. **挑战BOSS** - 到达顶层挑战最终BOSS

## 📁 项目结构

```
genshin_tower/
├── scripts/                   # 游戏脚本
│   ├── autoload/              # 全局单例（GameManager/DataManager/RunManager/DebugLogger 等）
│   ├── battle/                # 战斗系统（BattleManager 等）
│   ├── characters/            # 角色系统
│   ├── enemies/               # 敌人系统
│   ├── events/                # 奇遇事件系统（EventRegistry 等）
│   ├── map/                   # 地图系统
│   ├── ui/                    # UI 脚本（地图/商店/设置/事件 UI 等）
│   └── upgrades/              # 升级系统（UpgradeRegistry 等）
├── scenes/                    # 游戏场景
│   ├── ui/                    # 主菜单/选角/地图/商店/事件/设置等 UI 场景
│   ├── battle/                # 战斗场景
│   ├── characters/            # 角色场景
│   └── enemies/               # 敌人场景
├── data/                      # 游戏数据（Resource/JSON）
│   ├── characters/            # 角色配置
│   ├── enemies/               # 敌人配置
│   ├── events/                # 事件配置
│   ├── upgrades/              # 升级配置
│   └── config/                # JSON 配置（地图等）
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
- 楼层数量（`floors` / `boss_floor`）
- 每层节点数量范围（`nodes_per_floor`）
- 节点类型与权重/最小楼层（`node_types`）
- 特殊楼层规则（`special_floors`）

## 🎨 技术栈

- **引擎**: Godot 4.5
- **语言**: GDScript
- **架构**: 模块化、数据驱动
- **设计模式**: 单例模式、基类继承、信号系统

## 📝 开发计划

> 说明：下面按优先级（P0/P1/P2）列出可验收的里程碑。更详细的系统拆解与代码入口请参考 [`DEVELOPER_README.md`](DEVELOPER_README.md)。

### P0（核心闭环：一局可顺畅跑完）

- [ ] **商店系统 MVP**
  - 验收：进入商店节点后可购买（或刷新）商品；与 `RunManager.gold` 结算一致；购买后有明确反馈并可返回地图。
- [ ] **休息处功能完善**
  - 验收：进入休息节点后可触发恢复/代价机制（至少 1 种）；结算后正确返回地图；与 `RunManager.health/max_health` 同步。
- [ ] **战斗/结算与地图推进稳定性**
  - 验收：普通战斗/事件/商店/休息/BOSS 节点在一次 Run 内切换稳定；不会出现卡死/无法返回地图；结算页统计数据可信。

### P1（内容扩展：可玩性与重复游玩）

- [ ] **更多奇遇事件（数据驱动）**
  - 验收：新增事件只需添加资源文件即可被系统加载；至少新增 5 个事件，覆盖奖励/选择/随机等类型（详见 `scripts/events/README.md`）。
- [ ] **升级系统扩充与平衡**
  - 验收：新增/调整升级不需要改核心逻辑；升级与角色属性联动正确；提供基础平衡参数（例如权重/楼层限制）。
- [ ] **敌人 AI 行为扩展**
  - 验收：至少新增 2 种可区分行为（远程/冲刺/召唤等其一即可）；战斗行为有清晰 telegraph/反馈。
- [ ] **更多角色/技能与差异化**
  - 验收：至少新增 1 名角色或 1 套技能变体；具备可区分的成长/战斗手感。

### P2（体验与工程化：发布质量）

- [ ] **音频与特效统一（BGM/SFX/反馈）**
  - 验收：关键交互（命中/受击/升级/购买/切场景）有音效或视觉反馈；音量可控。
- [ ] **设置菜单完善**
  - 验收：至少包含音量/显示/操作相关设置中的 1-2 项；设置可持久化（重启后保持）。
- [ ] **性能与兼容性（Windows 优先，移动端逐步）**
  - 验收：中低配机器运行稳定；关键场景无明显卡顿；导出流程可复现（见 `export_presets.cfg`）。
- [ ] **问题定位与日志体验优化**
  - 验收：玩家可一键导出诊断信息；日志路径与提示一致（详见《调试日志使用说明》与《运行时日志使用说明》）。

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

### 导出/资源加载注意事项（重要）

#### 1) GDScript `const` 的限制

- `const` 只能赋值为“常量表达式”（编译期可确定）。
- 不要把 `PackedStringArray([...])`、`Array(...)`、`Dictionary(...)`、`preload()` 结果拼装等“运行期构造”写进 `const`。
- 需要列表/字典常量时：
  - 使用 `var` 在脚本加载时初始化；或
  - 使用 `static func` 返回构造结果；或
  - 使用 `.tres/.res` 资源文件承载列表。

#### 2) 导出后避免依赖 `DirAccess` 枚举 `res://`

在编辑器里 `DirAccess.open("res://...")` 扫目录通常没问题，但导出后可能出现：

- 无法枚举到文件
- 枚举结果为空（尤其是图片/音频等导入资源）

因此：

- 不要把“核心功能资源”仅依赖运行时扫目录得到。
- 对于随机背景/随机语音/随机图片等功能：必须提供“导出兜底方案”。

本项目约定的兜底方案：

- 在代码里维护一份显式路径列表（如 `res://textures/...`、`res://voice/...`）。
- 用 `preload()` 显式引用这些资源，确保导出时一定会被打包。
- 运行时优先扫目录（方便开发期增删），扫不到/为空则回退到兜底列表。

示例位置：

- 主菜单背景：`scripts/ui/main_menu.gd`
- 角色语音：`scripts/autoload/bgm_manager.gd`

## 📄 许可证

本项目代码采用 Apache License 2.0 - 查看 [LICENSE](LICENSE) 文件了解详情。

第三方 IP/商标（如米哈游/原神）与可能存在的美术资源来源风险不在 Apache License 2.0 的授权范围内，详见 [NOTICE](NOTICE)。

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
