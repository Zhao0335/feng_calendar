# 前端集成指南 - Flutter App

## 一、项目现状

### 已有功能 ✅
- 文字/图片/文件提取日程
- 本地SQLite存储
- 认证系统（Bearer Token）
- 云同步功能
- Provider状态管理
- dio HTTP客户端封装

### 技术栈
- **Flutter 3.x** + Material 3
- **Provider** - 状态管理
- **dio** - HTTP客户端
- **sqflite** - 本地存储

### 现有文件结构
```
lib/
├── main.dart                    # 入口
├── models/models.dart           # 数据模型
├── providers/app_provider.dart  # 全局状态
├── services/
│   ├── api_service.dart         # HTTP请求封装
│   └── storage_service.dart     # SQLite CRUD
├── screens/
│   ├── home_screen.dart         # 主页
│   ├── input_screen.dart        # 输入页
│   ├── items_screen.dart        # 日程列表
│   └── settings_screen.dart     # 设置页
└── widgets/
    ├── event_card.dart          # 日程卡片
    └── todo_card.dart           # 待办卡片
```

---

## 二、新增功能需求

### 1. 圆形悬浮窗组件 ⭕

**功能要求**：
- 圆形悬浮窗，位于屏幕右下角
- 视觉吸引力（图标 + 半透明 + 阴影）
- 可拖拽调整位置
- 点击打开AI聊天

**技术实现**：
```dart
// lib/widgets/floating_chat_button.dart

import 'package:flutter/material.dart';

class FloatingChatButton extends StatefulWidget {
  @override
  _FloatingChatButtonState createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> {
  Offset _position = Offset(20, 20); // 初始位置
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      bottom: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy - details.delta.dy,
            );
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onTap: _isDragging ? null : () => _openChat(context),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatPlanningScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
```

**使用方式**：
在 `home_screen.dart` 中使用 `Stack` 包裹主内容：
```dart
Stack(
  children: [
    // 原有内容
    _buildMainContent(),
    // 悬浮窗
    FloatingChatButton(),
  ],
)
```

---

### 2. AI聊天功能 💬

**功能要求**：
- 平滑过渡动画
- 消息输入框 + 发送按钮
- 消息历史记录
- 发送/接收消息
- 关闭返回主界面

**API调用**：
```dart
// 在 lib/services/api_service.dart 添加

class ApiService {
  // ... 现有代码 ...

  /// 开始AI规划对话
  Future<Map<String, dynamic>> startChatPlanning(String userRequest) async {
    try {
      final response = await _dio.post(
        '/chat/start',
        data: {'user_request': userRequest},
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 继续对话
  Future<Map<String, dynamic>> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/message',
        data: {
          'session_id': sessionId,
          'message': message,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建规划草稿
  Future<Map<String, dynamic>> createDraft({
    required String sessionId,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/draft',
        data: {
          'session_id': sessionId,
          'message': message,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 确认草稿
  Future<Map<String, dynamic>> confirmDraft({
    required int draftId,
    required bool confirm,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/confirm/$draftId',
        data: {
          'draft_id': draftId,
          'confirm': confirm,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取对话历史
  Future<List<dynamic>> getChatHistory(String sessionId) async {
    try {
      final response = await _dio.get('/chat/history/$sessionId');
      return response.data['messages'];
    } catch (e) {
      throw _handleError(e);
    }
  }
}
```

**聊天界面**：
```dart
// lib/screens/chat_planning_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatPlanningScreen extends StatefulWidget {
  @override
  _ChatPlanningScreenState createState() => _ChatPlanningScreenState();
}

class _ChatPlanningScreenState extends State<ChatPlanningScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI规划助手'),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, provider, __) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: provider.chatHistory.length,
                  itemBuilder: (context, index) {
                    final message = provider.chatHistory[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          // 输入框
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser 
            ? Theme.of(context).primaryColor
            : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message['content'],
          style: TextStyle(
            color: isUser ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '输入您的需求...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              maxLines: null,
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            child: _isLoading
              ? CircularProgressIndicator(color: Colors.white)
              : Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.sendChatMessage(message);
      
      // 滚动到底部
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

---

### 3. 用户画像设置功能 👤

**功能要求**：
- 在设置页面添加用户画像模块
- 基本信息 + 偏好设置
- AI聊天可读取画像数据
- 本地存储 + 同步

**API调用**：
```dart
// 在 lib/services/api_service.dart 添加

class ApiService {
  // ... 现有代码 ...

  /// 获取用户兴趣列表
  Future<List<dynamic>> getInterests({String? category}) async {
    try {
      final response = await _dio.get(
        '/profile/interests',
        queryParameters: category != null ? {'category': category} : null,
      );
      return response.data['interests'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 添加兴趣标签
  Future<Map<String, dynamic>> addInterest({
    required String category,
    required String tag,
    required List<String> keywords,
    double weight = 1.0,
  }) async {
    try {
      final response = await _dio.post(
        '/profile/interests',
        data: {
          'category': category,
          'tag': tag,
          'keywords': keywords,
          'weight': weight,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新兴趣标签
  Future<Map<String, dynamic>> updateInterest({
    required int interestId,
    List<String>? keywords,
    double? weight,
  }) async {
    try {
      final response = await _dio.put(
        '/profile/interests/$interestId',
        data: {
          if (keywords != null) 'keywords': keywords,
          if (weight != null) 'weight': weight,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除兴趣标签
  Future<void> deleteInterest(int interestId) async {
    try {
      await _dio.delete('/profile/interests/$interestId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取用户画像摘要
  Future<Map<String, dynamic>> getProfileSummary() async {
    try {
      final response = await _dio.get('/profile/summary');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }
}
```

**用户画像页面**：
```dart
// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.loadInterests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('用户画像'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddInterestDialog(),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (_, provider, __) {
          if (provider.interests.isEmpty) {
            return Center(
              child: Text('暂无兴趣标签，点击右上角添加'),
            );
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildCategorySection('research', '研究领域', provider.interests),
              _buildCategorySection('project', '项目类型', provider.interests),
              _buildCategorySection('skill', '技术技能', provider.interests),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    String title,
    List<dynamic> interests,
  ) {
    final categoryInterests = interests
      .where((i) => i['category'] == category)
      .toList();

    if (categoryInterests.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categoryInterests.map((interest) {
            return Chip(
              label: Text(interest['tag']),
              onDeleted: () => _deleteInterest(interest['id']),
            );
          }).toList(),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  void _showAddInterestDialog() {
    showDialog(
      context: context,
      builder: (context) => AddInterestDialog(),
    );
  }

  Future<void> _deleteInterest(int interestId) async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.deleteInterest(interestId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }
}

class AddInterestDialog extends StatefulWidget {
  @override
  _AddInterestDialogState createState() => _AddInterestDialogState();
}

class _AddInterestDialogState extends State<AddInterestDialog> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'skill';
  String _tag = '';
  String _keywords = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('添加兴趣标签'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              items: [
                DropdownMenuItem(value: 'research', child: Text('研究领域')),
                DropdownMenuItem(value: 'project', child: Text('项目类型')),
                DropdownMenuItem(value: 'skill', child: Text('技术技能')),
              ],
              onChanged: (value) => setState(() => _category = value!),
              decoration: InputDecoration(labelText: '分类'),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: '标签名称'),
              onSaved: (value) => _tag = value!,
              validator: (value) => value?.isEmpty ?? true ? '请输入标签名称' : null,
            ),
            TextFormField(
              decoration: InputDecoration(
                labelText: '关键词',
                hintText: '用逗号分隔，如：python, programming',
              ),
              onSaved: (value) => _keywords = value!,
              validator: (value) => value?.isEmpty ?? true ? '请输入关键词' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text('添加'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.addInterest(
        category: _category,
        tag: _tag,
        keywords: _keywords.split(',').map((k) => k.trim()).toList(),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败: $e')),
      );
    }
  }
}
```

---

### 4. 推荐系统功能 📊

**API调用**：
```dart
// 在 lib/services/api_service.dart 添加

class ApiService {
  // ... 现有代码 ...

  /// 获取推荐列表
  Future<Map<String, dynamic>> getRecommendations({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/recommendations/feed',
        queryParameters: {
          'unread_only': unreadOnly,
          'limit': limit,
          'offset': offset,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 标记已读
  Future<void> markAsRead(int contentId) async {
    try {
      await _dio.post('/recommendations/$contentId/read');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 收藏内容
  Future<void> saveContent(int contentId) async {
    try {
      await _dio.post('/recommendations/$contentId/save');
    } catch (e) {
      throw _handleError(e);
    }
  }
}
```

---

### 5. arXiv日报功能 📰

**API调用**：
```dart
// 在 lib/services/api_service.dart 添加

class ApiService {
  // ... 现有代码 ...

  /// 获取今日日报
  Future<Map<String, dynamic>> getTodayReport() async {
    try {
      final response = await _dio.get('/arxiv/report/today');
      return response.data['report'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取日报列表
  Future<List<dynamic>> getReports({int limit = 30}) async {
    try {
      final response = await _dio.get(
        '/arxiv/reports',
        queryParameters: {'limit': limit},
      );
      return response.data['reports'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新日报偏好
  Future<void> updateReportPreference({
    String pushTime = '09:00',
    int paperCount = 5,
    List<String>? categories,
  }) async {
    try {
      await _dio.post(
        '/arxiv/preference',
        data: {
          'push_time': pushTime,
          'paper_count': paperCount,
          if (categories != null) 'categories': categories,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
}
```

---

## 三、状态管理扩展

### 在 `app_provider.dart` 添加：

```dart
// lib/providers/app_provider.dart

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // ... 现有代码 ...

  // ============ AI规划状态 ============
  String? _currentSessionId;
  List<Map<String, dynamic>> _chatHistory = [];
  Map<String, dynamic>? _currentDraft;

  String? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get chatHistory => _chatHistory;
  Map<String, dynamic>? get currentDraft => _currentDraft;

  /// 开始AI规划对话
  Future<void> startChatPlanning(String request) async {
    final result = await _apiService.startChatPlanning(request);
    
    _currentSessionId = result['session_id'];
    _chatHistory = [
      {'role': 'user', 'content': request},
      {'role': 'assistant', 'content': result['ai_response']},
    ];
    
    notifyListeners();
  }

  /// 发送消息
  Future<void> sendChatMessage(String message) async {
    if (_currentSessionId == null) {
      await startChatPlanning(message);
      return;
    }

    _chatHistory.add({'role': 'user', 'content': message});
    notifyListeners();

    final result = await _apiService.sendMessage(
      sessionId: _currentSessionId!,
      message: message,
    );

    _chatHistory.add({'role': 'assistant', 'content': result['ai_response']});
    notifyListeners();
  }

  /// 创建规划草稿
  Future<void> createDraft(String message) async {
    if (_currentSessionId == null) return;

    final result = await _apiService.createDraft(
      sessionId: _currentSessionId!,
      message: message,
    );

    _currentDraft = result['draft'];
    notifyListeners();
  }

  /// 确认草稿
  Future<void> confirmDraft(bool confirm) async {
    if (_currentDraft == null) return;

    await _apiService.confirmDraft(
      draftId: _currentDraft!['id'],
      confirm: confirm,
    );

    _currentDraft = null;
    _currentSessionId = null;
    _chatHistory = [];
    
    notifyListeners();
  }

  /// 清空对话
  void clearChat() {
    _currentSessionId = null;
    _chatHistory = [];
    _currentDraft = null;
    notifyListeners();
  }

  // ============ 用户画像状态 ============
  List<Map<String, dynamic>> _interests = [];
  Map<String, dynamic>? _profileSummary;

  List<Map<String, dynamic>> get interests => _interests;
  Map<String, dynamic>? get profileSummary => _profileSummary;

  /// 加载兴趣列表
  Future<void> loadInterests() async {
    _interests = await _apiService.getInterests();
    notifyListeners();
  }

  /// 添加兴趣
  Future<void> addInterest({
    required String category,
    required String tag,
    required List<String> keywords,
    double weight = 1.0,
  }) async {
    await _apiService.addInterest(
      category: category,
      tag: tag,
      keywords: keywords,
      weight: weight,
    );
    await loadInterests();
  }

  /// 删除兴趣
  Future<void> deleteInterest(int interestId) async {
    await _apiService.deleteInterest(interestId);
    await loadInterests();
  }

  /// 加载画像摘要
  Future<void> loadProfileSummary() async {
    _profileSummary = await _apiService.getProfileSummary();
    notifyListeners();
  }

  // ============ 推荐状态 ============
  List<Map<String, dynamic>> _recommendations = [];
  int _recommendationTotal = 0;

  List<Map<String, dynamic>> get recommendations => _recommendations;
  int get recommendationTotal => _recommendationTotal;

  /// 加载推荐
  Future<void> loadRecommendations({bool unreadOnly = false}) async {
    final result = await _apiService.getRecommendations(unreadOnly: unreadOnly);
    _recommendations = result['items'];
    _recommendationTotal = result['total'];
    notifyListeners();
  }

  /// 标记已读
  Future<void> markRecommendationRead(int contentId) async {
    await _apiService.markAsRead(contentId);
    await loadRecommendations();
  }

  /// 收藏内容
  Future<void> saveRecommendation(int contentId) async {
    await _apiService.saveContent(contentId);
    await loadRecommendations();
  }

  // ============ 日报状态 ============
  Map<String, dynamic>? _todayReport;
  List<Map<String, dynamic>> _reportHistory = [];

  Map<String, dynamic>? get todayReport => _todayReport;
  List<Map<String, dynamic>> get reportHistory => _reportHistory;

  /// 加载今日日报
  Future<void> loadTodayReport() async {
    try {
      _todayReport = await _apiService.getTodayReport();
      notifyListeners();
    } catch (e) {
      _todayReport = null;
      notifyListeners();
    }
  }

  /// 加载日报历史
  Future<void> loadReportHistory() async {
    _reportHistory = await _apiService.getReports();
    notifyListeners();
  }
}
```

---

## 四、导航更新

### 在 `home_screen.dart` 添加新导航项：

```dart
// 更新底部导航栏或侧边栏
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: '主页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today),
      label: '日程',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: '画像',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.recommend),
      label: '推荐',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.article),
      label: '日报',
    ),
  ],
  onTap: (index) {
    switch (index) {
      case 0:
        // 主页
        break;
      case 1:
        // 日程
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecommendationsScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DailyReportScreen()),
        );
        break;
    }
  },
)
```

---

## 五、错误处理

### 统一错误处理：

```dart
// 在 api_service.dart

Exception _handleError(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('连接超时，请检查网络');
      case DioExceptionType.sendTimeout:
        return Exception('发送超时');
      case DioExceptionType.receiveTimeout:
        return Exception('响应超时，AI推理可能需要较长时间');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 503) {
          return Exception('Ollama服务不可用，请确保服务已启动');
        } else if (statusCode == 504) {
          return Exception('AI推理超时，请稍后重试');
        } else if (statusCode == 401) {
          return Exception('未授权，请重新登录');
        }
        return Exception('服务器错误: $statusCode');
      default:
        return Exception('网络错误: ${error.message}');
    }
  }
  return Exception('未知错误: $error');
}
```

---

## 六、实现优先级

### 第一阶段（核心功能）⭐⭐⭐
1. **圆形悬浮窗** - 入口组件
2. **AI聊天界面** - 核心交互
3. **用户画像管理** - 个性化基础

### 第二阶段（增强功能）⭐⭐
4. **推荐系统** - 依赖用户画像
5. **arXiv日报** - 可选功能

### 第三阶段（优化完善）⭐
6. 性能优化
7. 动画优化
8. 错误处理完善

---

## 七、设计规范

### 1. 统一设计语言
- 使用 Material 3 设计系统
- 遵循 Flutter 设计规范
- 保持一致的间距和圆角

### 2. 过渡动画
```dart
// 使用 PageRouteBuilder 实现平滑过渡
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (_, animation, __) => NewScreen(),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
    transitionDuration: Duration(milliseconds: 300),
  ),
);
```

### 3. 响应式设计
```dart
// 使用 LayoutBuilder 适配不同屏幕
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      // 平板布局
      return _buildTabletLayout();
    } else {
      // 手机布局
      return _buildMobileLayout();
    }
  },
)
```

---

## 八、测试要点

### 功能测试
- [ ] 悬浮窗拖拽功能
- [ ] AI对话完整流程
- [ ] 用户画像CRUD
- [ ] 推荐内容展示
- [ ] 日报查看

### 性能测试
- [ ] 悬浮窗不卡顿
- [ ] 对话流畅
- [ ] 长列表滚动流畅
- [ ] 动画流畅

### 兼容性测试
- [ ] iOS设备
- [ ] Android设备
- [ ] 不同屏幕尺寸
- [ ] 深色模式

---

## 九、注意事项

### 1. 认证
所有新API都需要Bearer Token，确保：
```dart
_dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = // 从本地存储获取token
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
  ),
);
```

### 2. 加载状态
AI推理可能需要5-30秒，务必：
- 显示加载动画
- 禁用输入框
- 提供取消按钮

### 3. 数据缓存
推荐和日报可以本地缓存：
```dart
// 使用 shared_preferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('cached_recommendations', jsonEncode(recommendations));
```

### 4. 错误提示
友好的错误提示：
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('操作失败'),
    action: SnackBarAction(
      label: '重试',
      onPressed: () => _retry(),
    ),
  ),
);
```

---

## 十、完整API文档参考

详见：[API_DOCUMENTATION.md](./API_DOCUMENTATION.md)

---

**祝开发顺利！如有问题请随时沟通。** 🚀
