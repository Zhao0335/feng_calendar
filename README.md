# 枫枫子的备忘录

从文字、截图、文件中自动提取日程和待办事项的跨平台 App，支持 AI 对话规划、用户画像、个性化推荐和 arXiv 学术日报。

## 功能

### 核心功能
- **文字提取**：粘贴任意中英文文字，AI 自动识别日程与待办
- **图片提取**：选择截图或照片，OCR + AI 解析
- **文件提取**：上传 PDF / TXT / MD，批量提取
- **本地持久化**：SQLite 存储所有历史记录

### 新增功能
- **AI 聊天规划**：可拖拽悬浮按钮，对话式规划日程，支持草稿预览和一键导入
- **用户画像**：管理兴趣标签（研究领域/项目类型/技术技能），支持 CRUD
- **个性化推荐**：基于用户画像的推荐内容流，支持已读/收藏标记
- **arXiv 日报**：自动生成学术日报，支持偏好设置（领域、数量、推送时间）

### 体验优化
- **自适应布局**：宽屏侧边栏 / 窄屏底部导航栏
- **深色模式**：跟随系统自动切换
- **错误重试**：网络失败时 SnackBar 提供重试按钮
- **AI 思考提示**：聊天时显示进度条和取消按钮

## 技术栈

| 层 | 技术 |
| --- | --- |
| 前端 | Flutter 3.x，Material 3，Provider |
| 本地存储 | sqflite，shared_preferences |
| HTTP | dio（连接超时 30s，响应超时 180s）|
| 后端 | FastAPI + Ollama（本地服务器）|
| AI 模型 | qwen2.5:72b（可在设置页更换）|

## 目录结构

```text
lib/
├── main.dart                  # 入口，Provider 注入，主题配置
├── models/models.dart         # ScheduleEvent, Todo, ChatMessage, Interest, RecommendationItem, ArxivReport...
├── providers/app_provider.dart # 全局状态（ChangeNotifier）
├── services/
│   ├── api_service.dart       # HTTP 请求封装（含统一错误处理）
│   ├── auth_service.dart      # 认证服务
│   └── storage_service.dart   # SQLite CRUD
├── screens/
│   ├── home_screen.dart       # 自适应 Scaffold + 悬浮按钮
│   ├── input_screen.dart      # 文字/图片/文件输入
│   ├── items_screen.dart      # 日程+待办列表
│   ├── chat_planning_screen.dart  # AI 聊天规划界面
│   ├── profile_screen.dart    # 用户画像管理
│   ├── recommendations_screen.dart # 推荐内容列表
│   ├── daily_report_screen.dart   # arXiv 日报
│   └── settings_screen.dart   # 服务器配置
└── widgets/
    ├── floating_chat_button.dart  # 可拖拽悬浮按钮
    ├── event_card.dart        # 日程卡片
    ├── todo_card.dart         # 待办卡片
    └── empty_state.dart       # 空状态占位
```

## 后端 API

### POST `/extract`

```json
// 请求（三选一）
{
  "text": "明天下午 3 点在 11-100 开组会",
  "image_base64": "<base64>",
  "file_base64": "<base64>",
  "file_type": "pdf"
}

// 响应
{
  "events": [
    { "title": "...", "date": "2026-04-26", "time": "15:00", "location": "...", "notes": "..." }
  ],
  "todos": [
    { "title": "...", "deadline": "2026-05-10", "priority": "high", "notes": "..." }
  ]
}
```

### GET `/health`

返回 `{"status": "ok"}`，用于设置页连接检测。

### AI 聊天规划

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/chat/start` | 开始规划会话 |
| POST | `/chat/message` | 发送消息 |
| POST | `/chat/draft` | 生成规划草稿 |
| POST | `/chat/confirm/{draft_id}` | 确认/取消草稿 |
| GET | `/chat/history/{session_id}` | 获取聊天历史 |

### 用户画像

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/profile/interests` | 获取兴趣标签列表 |
| POST | `/profile/interests` | 添加兴趣标签 |
| PUT | `/profile/interests/{id}` | 更新兴趣标签 |
| DELETE | `/profile/interests/{id}` | 删除兴趣标签 |
| GET | `/profile/summary` | 获取画像摘要 |

### 推荐系统

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/recommendations/feed` | 获取推荐内容流 |
| POST | `/recommendations/{id}/read` | 标记已读 |
| POST | `/recommendations/{id}/save` | 收藏内容 |
| GET | `/recommendations/stats/summary` | 获取推荐统计 |

### arXiv 日报

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/arxiv/preference` | 获取日报偏好 |
| POST | `/arxiv/preference` | 更新日报偏好 |
| POST | `/arxiv/report/generate` | 生成日报 |
| GET | `/arxiv/report/today` | 获取今日日报 |
| GET | `/arxiv/reports` | 获取历史日报列表 |

## 快速开始

### 环境要求

- Flutter 3.x SDK
- Visual Studio Build Tools（Windows 桌面）或 Xcode（macOS/iOS）
- 后端服务运行中

### 安装与运行

```bash
# 安装依赖
flutter pub get

# 生成图标（需要 assets/icon.png）
dart run flutter_launcher_icons

# 运行（开发模式）
flutter run -d windows
flutter run -d macos
flutter run -d <iOS设备UDID>

# 打包（发布模式）
flutter build windows --release
flutter build macos --release
flutter build ipa --release          # 需要 Apple Developer 证书
```

### 构建产物

- Windows: `build\windows\x64\runner\Release\feng_calendar.exe`
- macOS: `build\macos\Build\Products\Release\feng_calendar.app`

## 配置

在 App 设置页修改，或直接编辑 `lib/services/api_service.dart`：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| 服务器地址 | `http://101.37.80.57:5522` | 后端 FastAPI 地址 |
| 模型名 | `qwen2.5:72b` | Ollama 模型 |
| 连接超时 | 30 秒 | dio connectTimeout |
| 响应超时 | 180 秒 | dio receiveTimeout |

## 错误处理

所有 API 请求经过统一错误处理，用户友好的错误提示：

| 错误类型 | 提示信息 |
| --- | --- |
| 连接超时 | 连接超时，请检查网络 |
| 响应超时 | 响应超时，AI推理可能需要较长时间 |
| 503 | Ollama服务不可用，请确保服务已启动 |
| 504 | AI推理超时，请稍后重试 |
| 401 | 未授权，请重新登录 |
| 网络错误 | 网络连接失败，请检查网络设置 |

---

## 待实现 TODO

### iOS/macOS 主屏幕小组件（WidgetKit）

Flutter 侧桥接代码已通过 `home_widget` 包准备好，但 WidgetKit 原生侧尚未实现。

#### Flutter 侧（已写好，提取完成后调用）

```dart
import 'package:home_widget/home_widget.dart';

// 在 AppProvider._extract() 成功后调用
await HomeWidget.saveWidgetData('events_json', jsonEncode(todayEvents));
await HomeWidget.saveWidgetData('todos_json', jsonEncode(pendingTodos));
await HomeWidget.updateWidget(
  iOSName: 'ScheduleWidget',
);
```

#### 原生侧待办清单

- [ ] **Xcode：添加 Widget Extension Target**
  - File → New → Target → Widget Extension
  - Product Name: `ScheduleWidget`
  - 取消勾选 "Include Configuration App Intent"

- [ ] **配置 App Group**（Flutter ↔ WidgetKit 共享数据）
  - Runner target → Signing & Capabilities → + App Groups
  - 添加 `group.com.example.fengCalendar`
  - ScheduleWidget target 同样添加该 App Group
  - Flutter 侧调用 `HomeWidget.setAppGroupId('group.com.example.fengCalendar')`

- [ ] **实现 `ScheduleWidget.swift`**（SwiftUI）

  ```swift
  import WidgetKit
  import SwiftUI

  struct ScheduleEntry: TimelineEntry {
      let date: Date
      let events: [[String: String]]
      let todos: [[String: String]]
  }

  struct ScheduleProvider: TimelineProvider {
      func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
          completion(makeEntry())
      }
      func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
          let entry = makeEntry()
          completion(Timeline(entries: [entry], policy: .atEnd))
      }
      func placeholder(in context: Context) -> ScheduleEntry { makeEntry() }

      private func makeEntry() -> ScheduleEntry {
          let defaults = UserDefaults(suiteName: "group.com.example.fengCalendar")
          let eventsJson = defaults?.string(forKey: "events_json") ?? "[]"
          let todosJson  = defaults?.string(forKey: "todos_json")  ?? "[]"
          let events = (try? JSONSerialization.jsonObject(with: Data(eventsJson.utf8))) as? [[String: String]] ?? []
          let todos  = (try? JSONSerialization.jsonObject(with: Data(todosJson.utf8)))  as? [[String: String]] ?? []
          return ScheduleEntry(date: .now, events: events, todos: todos)
      }
  }

  struct ScheduleWidgetView: View {
      let entry: ScheduleEntry
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              Text("今日日程").font(.caption).foregroundStyle(.secondary)
              ForEach(entry.events.prefix(3), id: \.self) { e in
                  Label(e["title"] ?? "", systemImage: "calendar")
                      .font(.caption2).lineLimit(1)
              }
          }
          .padding()
      }
  }

  @main
  struct ScheduleWidget: Widget {
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: "ScheduleWidget", provider: ScheduleProvider()) { entry in
              ScheduleWidgetView(entry: entry)
          }
          .configurationDisplayName("枫枫子的备忘录")
          .description("今日日程速览")
          .supportedFamilies([.systemSmall, .systemMedium])
      }
  }
  ```

- [ ] **macOS Widget Extension**（可选，步骤同 iOS，Target 选 macOS）

- [ ] **测试**：在模拟器主屏幕长按 → 添加小组件 → 验证数据更新
