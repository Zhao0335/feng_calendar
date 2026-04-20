# Schedule Extractor — Flutter App

## 项目概述
从文字、截图、文件中提取日程和待办事项的跨平台 App。
前端 Flutter（macOS + iOS），后端 FastAPI + Ollama（本地 4090D 服务器）。

## 架构

```
lib/
  main.dart                  # 入口，Provider 注入
  providers/
    app_provider.dart        # 全局状态（ChangeNotifier）
  models/
    models.dart              # Event, Todo, ExtractionResult
  services/
    api_service.dart         # HTTP → 后端
    storage_service.dart     # SQLite 本地持久化
  screens/
    home_screen.dart         # 自适应 Scaffold（Mac 侧边栏 / iOS 底栏）
    input_screen.dart        # 输入页：文字/图片/文件
    items_screen.dart        # 列表页：日程 + 待办
    settings_screen.dart     # 设置页：服务器 URL、模型名
  widgets/
    event_card.dart          # 日程卡片
    todo_card.dart           # 待办卡片（可勾选）
    empty_state.dart         # 空状态占位
```

## 依赖（pubspec.yaml 已写好）
- `dio` — HTTP
- `sqflite` + `path_provider` — 本地存储
- `image_picker` — 选图片/截图
- `file_picker` — 选 PDF/TXT
- `provider` — 状态管理
- `shared_preferences` — 设置存储
- `intl` — 日期格式化
- `home_widget` — Flutter ↔ WidgetKit 桥接（后期 Widget 用）

## API 接口约定

### POST /extract
```json
// 请求（三选一字段）
{
  "text": "粘贴的文字内容",
  "image_base64": "base64编码的图片",
  "file_base64": "base64编码的PDF/TXT",
  "file_type": "pdf" // 或 "txt"
}

// 响应
{
  "events": [
    {
      "title": "事件标题",
      "date": "2026-04-26",
      "time": "08:30",
      "location": "11-100",
      "notes": "备注"
    }
  ],
  "todos": [
    {
      "title": "待办标题",
      "deadline": "2026-05-10",
      "priority": "high",
      "notes": "备注"
    }
  ]
}
```

### GET /health
返回 `{"status": "ok"}` 用于连接检测。

## 功能规格

### 输入页（InputScreen）
- Tab 1：文字输入（TextField，多行，placeholder 提示支持中英文混排）
- Tab 2：图片选择（image_picker，支持相册和相机）
- Tab 3：文件选择（file_picker，accept: pdf/txt/md）
- 提取按钮：loading 状态，禁止重复点击
- 提取完成后自动跳转到列表页并展示结果

### 列表页（ItemsScreen）
- 顶部 SegmentedButton：全部 / 日程 / 待办
- 日程卡片：标题 + 日期时间 badge（蓝色）+ 地点（灰色）
- 待办卡片：勾选框 + 标题 + 截止日期 badge（橙色 high → 红色）
- 下拉刷新（载入本地历史）
- 长按删除

### 设置页（SettingsScreen）
- 服务器地址（默认 http://192.168.1.x:8000）
- 模型名（默认 qwen2.5:72b）
- 连接测试按钮（GET /health）
- 清除本地数据

### 自适应布局
- macOS：NavigationDrawer（永久侧边栏，宽度 200）+ 内容区
- iOS：NavigationBar（底部三 tab：输入 / 列表 / 设置）
- 用 `defaultTargetPlatform` 或 MediaQuery 宽度判断（>= 600 用侧边栏）

## 设计规范
- Material 3，seedColor `Color(0xFF5B4CF5)`（紫色）
- 跟随系统深色/浅色模式
- 卡片用 `Card.filled` + `shape: RoundedRectangleBorder(borderRadius: 12)`
- 日程 badge：`Colors.blue.shade100` / `Colors.blue.shade800`
- 待办 deadline badge：medium → `Colors.orange`，high → `Colors.red`
- 完成的待办：title 加删除线，整体透明度 0.5

## 本地存储 schema（SQLite）

```sql
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  date TEXT,
  time TEXT,
  location TEXT,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE todos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  deadline TEXT,
  priority TEXT DEFAULT 'medium',
  notes TEXT,
  is_done INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);
```

## Widget 桥接（home_widget，后期实现）
提取完成后，用 `HomeWidget.saveWidgetData` 写入：
```dart
await HomeWidget.saveWidgetData('events_json', jsonEncode(todayEvents));
await HomeWidget.saveWidgetData('todos_json', jsonEncode(pendingTodos));
await HomeWidget.updateWidget(
  iOSName: 'ScheduleWidget',
  androidName: 'ScheduleWidgetProvider', // 不需要，留空
);
```

## TODO（让 Claude Code 实现）
- [ ] 补全 `providers/app_provider.dart`：状态、提取方法、历史加载
- [ ] 补全 `services/api_service.dart`：dio 实例、提取请求、health check
- [ ] 补全 `services/storage_service.dart`：初始化、CRUD
- [ ] 实现 `screens/home_screen.dart`：自适应 Scaffold
- [ ] 实现 `screens/input_screen.dart`：三 tab 输入
- [ ] 实现 `screens/items_screen.dart`：列表 + 过滤
- [ ] 实现 `screens/settings_screen.dart`
- [ ] 实现 `widgets/event_card.dart` + `todo_card.dart`
- [ ] macOS entitlements：添加网络访问权限
- [ ] iOS Info.plist：添加 NSPhotoLibraryUsageDescription
