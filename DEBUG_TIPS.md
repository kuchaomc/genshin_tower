# 调试提示

## 如果选择角色后游戏闪退

### 1. 检查控制台输出
在Godot编辑器中运行游戏，查看"输出"面板的错误信息。常见问题：

- **资源加载失败**：检查`.tres`文件路径是否正确
- **场景加载失败**：检查场景文件是否存在
- **单例未初始化**：确保`project.godot`中配置了Autoload

### 2. 检查Autoload配置
确保`project.godot`中有以下配置：
```ini
[autoload]

BGMManager="*res://scripts/autoload/bgm_manager.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
DataManager="*res://scripts/autoload/data_manager.gd"
RunManager="*res://scripts/autoload/run_manager.gd"
UpgradeRegistry="*res://scripts/upgrades/upgrade_registry.gd"
EventRegistry="*res://scripts/events/event_registry.gd"
EventBus="*res://scripts/core/event_bus.gd"
TransitionManager="*res://scripts/ui/transition_manager.gd"
DamageNumberManager="*res://scripts/autoload/damage_number_manager.gd"
PostProcessManager="*res://scripts/autoload/post_process_manager.gd"
DebugLogger="*res://scripts/autoload/debug_logger.gd"
```

### 3. 检查资源文件
确保以下文件存在：
- `res://data/characters/kamisato_ayaka_character.tres`
- `res://data/enemies/normal_enemy.tres`
- `res://data/config/map_config.json`

### 4. 检查场景文件
确保以下场景文件存在：
- `res://scenes/ui/main_menu.tscn`
- `res://scenes/ui/character_select.tscn`
- `res://scenes/ui/map_view.tscn`
- `res://scenes/battle/battle_scene.tscn`

### 5. 常见错误和解决方案

#### 错误：Cannot get class 'CharacterData'
- **原因**：Resource类未正确注册
- **解决**：在Godot编辑器中重新导入资源（右键资源文件 → 重新导入）

#### 错误：场景加载失败
- **原因**：场景文件路径错误或文件不存在
- **解决**：检查`GameManager`中的场景路径常量是否正确

#### 错误：单例未找到
- **原因**：Autoload未正确配置
- **解决**：检查`project.godot`中的Autoload配置，确保路径正确

### 6. 调试步骤

1. **启用详细日志**：
   - 在Godot编辑器中，打开"项目设置" → "调试" → "设置"
   - 启用"打印错误"和"打印警告"

2. **检查数据加载**：
   - 在`DataManager._ready()`中添加`print("数据管理器初始化")`
   - 检查控制台是否输出"数据管理器：所有数据加载完成"

3. **检查角色选择**：
   - 在`character_select.gd`的`_on_confirm_pressed()`中添加更多print语句
   - 确认`selected_character`不为null

4. **检查场景切换**：
   - 在`GameManager.change_scene_to()`中添加print语句
   - 确认场景文件能够成功加载

### 7. 临时解决方案

如果问题持续存在，可以尝试：

1. **直接进入战斗场景**（跳过地图）：
   - 修改`character_select.gd`的`_on_confirm_pressed()`：
   ```gdscript
   GameManager.start_battle()
   ```

2. **使用默认角色**：
   - 在`character_select.gd`中创建默认角色时，确保所有属性都正确设置

3. **简化地图生成**：
   - 在`map_view.gd`中，暂时注释掉地图生成代码，只显示一个简单的按钮

### 8. 获取详细错误信息

如果游戏闪退，检查以下位置：
- Godot编辑器底部的"输出"面板
- Windows事件查看器（如果是在Windows上）
- 游戏日志文件（如果有）

将错误信息发送给开发者以便进一步调试。
