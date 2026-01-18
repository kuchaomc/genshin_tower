# 贡献指南

感谢你对 Genshin Roguelike Game 项目的兴趣！我们欢迎各种形式的贡献。

## 如何贡献

### 报告 Bug

如果你发现了 Bug，请：

1. 检查 [Issues](https://github.com/yourusername/genshin_game/issues) 确认是否已经有人报告
2. 如果没有，创建一个新的 Issue
3. 提供以下信息：
   - 详细的 Bug 描述
   - 重现步骤
   - 预期行为 vs 实际行为
   - 截图或错误日志（如果有）
   - 你的环境信息（操作系统、Godot 版本等）

### 提出新功能

如果你有好的想法：

1. 先查看现有的 Issues 和 Discussions
2. 创建一个 Feature Request Issue
3. 详细描述：
   - 功能的目的和用途
   - 为什么这个功能对项目有价值
   - 可能的实现方式（可选）

### 提交代码

1. **Fork 仓库**
   ```bash
   git clone https://github.com/yourusername/genshin_game.git
   cd genshin_game
   ```

2. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/bug-description
   ```

3. **进行修改**
   - 编写清晰的代码
   - 添加必要的注释
   - 确保代码可以正常运行
   - 遵循项目的代码风格

4. **测试**
   - 在 Godot 编辑器中测试你的更改
   - 确保没有引入新的 Bug
   - 测试相关功能是否正常工作

5. **提交更改**
   ```bash
   git add .
   git commit -m "描述你的更改"
   git push origin feature/your-feature-name
   ```

6. **创建 Pull Request**
   - 在 GitHub 上创建 Pull Request
   - 详细描述你的更改
   - 链接相关的 Issues（如果有）

## 代码规范

### GDScript 风格

- 使用有意义的变量和函数名
- 函数名使用 `snake_case`
- 类名使用 `PascalCase`
- 常量使用 `UPPER_SNAKE_CASE`

### 注释规范

- 使用 `##` 为公共函数和类添加文档注释
- 使用 `#` 为复杂逻辑添加解释性注释
- 保持注释简洁明了

### 示例

```gdscript
## 角色基类
## 包含所有角色的通用逻辑
class_name BaseCharacter extends CharacterBody2D

# 最大血量
@export var max_health: float = 100.0

## 受到伤害
func take_damage(damage_amount: float) -> void:
	# 检查是否处于无敌状态
	if is_invincible:
		return
	
	current_health -= damage_amount
```

## 项目结构规范

### 添加新功能

- **角色**: 放在 `scripts/characters/` 和 `data/characters/`
- **敌人**: 放在 `scripts/enemies/` 和 `data/enemies/`
- **UI界面**: 放在 `scripts/ui/` 和 `scenes/`
- **地图相关**: 放在 `scripts/map/` 和 `scenes/map/`

### 文件命名

- 脚本文件: `snake_case.gd`
- 场景文件: `snake_case.tscn` 或中文描述性名称
- Resource 文件: `snake_case.tres`

## 提交信息规范

使用清晰的提交信息：

- `feat: 添加新角色系统`
- `fix: 修复地图节点位置异常`
- `docs: 更新 README`
- `refactor: 重构战斗管理器`
- `style: 格式化代码`
- `test: 添加单元测试`

## 审查流程

1. 提交 Pull Request 后，维护者会进行审查
2. 可能需要根据反馈进行修改
3. 审查通过后，代码会被合并到主分支

## 问题？

如果你有任何问题，可以：

- 查看 [Issues](https://github.com/yourusername/genshin_game/issues)
- 在 [Discussions](https://github.com/yourusername/genshin_game/discussions) 中提问
- 联系项目维护者

感谢你的贡献！🎉
