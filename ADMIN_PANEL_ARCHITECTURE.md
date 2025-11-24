# Admin Panel 架构文档

## 概述

Admin Panel 是一个基于角色的访问控制（RBAC）系统，允许超级管理员（super_admin）管理平台上的用户和事件。系统采用软删除机制，所有删除操作都是异步执行的，确保不会阻塞用户请求。

## 核心组件

### 1. 角色系统 (Role System)

#### 用户角色
- **student** (0): 普通学生用户，默认角色
- **club_admin** (1): 俱乐部管理员
- **super_admin** (2): 超级管理员，拥有删除权限

#### 权限检查
```ruby
# User 模型中的权限方法
def admin?
  super_admin?
end

def can_delete_user?(target_user)
  super_admin? && target_user.id != id # 不能删除自己
end

def can_delete_event?(event_post)
  super_admin?
end
```

### 2. 软删除机制 (Soft Delete)

#### 技术实现
- **Gem**: `discard` (Rails 8.1 兼容)
- **列名**: `deleted_at` (datetime)
- **元数据**: 
  - `deleted_by_id`: 执行删除的管理员 ID
  - `deletion_reason`: 删除原因（可选）

#### 模型配置
```ruby
# User, EventPost, EventRegistration 模型
include Discard::Model
self.discard_column = :deleted_at
```

#### 查询方法
- `User.all` - 只返回未删除的记录（默认）
- `User.discarded` - 只返回已删除的记录
- `User.with_discarded` - 返回所有记录（包括已删除）
- `user.discarded?` - 检查是否已删除
- `user.discard` - 软删除
- `user.undiscard` - 恢复

### 3. 异步删除流程 (Async Deletion Flow)

#### 架构设计
```
用户请求 → Controller → 立即返回 → 后台任务队列 → Worker 处理
```

#### 详细流程

**步骤 1: 用户发起删除请求**
```ruby
DELETE /admin/users/:id
{
  confirmation: "DELETE",
  reason: "Spam account"
}
```

**步骤 2: Controller 处理（立即返回）**
```ruby
# Admin::DeletionsController#destroy
1. 验证确认字符串（必须是 "DELETE"）
2. 检查权限（can_delete_user? / can_delete_event?）
3. 记录审计日志（立即记录，标记为 async: true）
4. 将删除任务加入队列（AdminDeletionJob.perform_later）
5. 立即返回成功响应（不等待删除完成）
```

**步骤 3: 后台任务执行**
```ruby
# AdminDeletionJob#perform
1. 查找要删除的记录
2. 调用 soft_delete_with_cascade! 方法
3. 执行级联软删除
4. 记录完成日志
```

**步骤 4: 级联删除逻辑**
```ruby
# User#soft_delete_with_cascade!
1. 更新删除元数据（deleted_by_id, deletion_reason）
2. 软删除用户的所有事件（organized_events）
3. 软删除用户的所有注册（event_registrations）
4. 软删除用户本身
5. 所有操作在事务中执行
```

#### 为什么使用异步删除？

1. **性能**: 删除大量关联数据时不会阻塞 HTTP 请求
2. **用户体验**: 用户立即得到响应，不需要等待
3. **可扩展性**: 可以处理大量删除操作而不影响服务器响应时间
4. **错误处理**: 后台任务可以重试，不会影响用户

### 4. 级联删除规则 (Cascading Deletion Rules)

#### 删除用户时的级联
```
User (被删除)
├── organized_events (用户创建的所有事件)
│   └── event_registrations (这些事件的所有注册)
├── event_registrations (用户的直接注册)
└── 用户本身
```

#### 删除事件时的级联
```
EventPost (被删除)
├── event_registrations (事件的所有注册)
└── 事件本身
```

#### 实现细节
- 使用 `dependent: :destroy_async` 确保关联记录异步删除
- 所有删除操作在数据库事务中执行，保证数据一致性
- 软删除不会真正删除数据，只是标记 `deleted_at`

### 5. 删除预览 (Deletion Preview)

#### 功能
在删除前显示将被删除的数据统计，帮助管理员了解删除的影响范围。

#### API
```
GET /admin/users/:id/deletion_preview
GET /admin/event_posts/:id/deletion_preview
```

#### 返回数据
```json
{
  "type": "User",
  "id": 123,
  "title": "John Doe",
  "will_delete": {
    "organized_events": 5,
    "event_registrations": 12,
    "e_score": 150
  },
  "confirmation_required": true
}
```

### 6. 恢复机制 (Restore Mechanism)

#### 功能
管理员可以在 30 天宽限期内恢复已删除的记录。

#### API
```
POST /admin/restore/:type/:id
```

#### 恢复逻辑
```ruby
# 恢复用户时
1. 恢复用户本身
2. 恢复用户的所有事件（organized_events）
3. 恢复用户的所有注册（event_registrations）

# 恢复事件时
1. 恢复事件本身
2. 恢复事件的所有注册（event_registrations）
```

### 7. 审计日志 (Audit Log)

#### 目的
记录所有管理员操作，用于：
- 追踪谁执行了删除/恢复操作
- 记录操作时间和原因
- 合规性要求（GDPR 等）

#### 数据结构
```ruby
AdminAuditLog
- admin_user_id: 执行操作的管理员
- action: 'delete' | 'restore'
- target_type: 'User' | 'EventPost'
- target_id: 被操作记录的 ID
- metadata: JSON 格式的额外信息
  - reason: 删除原因
  - preview: 删除预览数据
  - async: 是否异步执行
  - queued_at: 任务入队时间
- ip_address: 请求 IP
- user_agent: 用户代理
- created_at: 操作时间
```

### 8. 安全机制 (Security)

#### 权限控制
- **多层验证**: Controller 层 + Model 层
- **Base Controller**: `Admin::AdminBaseController` 统一处理认证
- **方法级权限**: `can_delete_user?`, `can_delete_event?`

#### 确认机制
- 必须输入 "DELETE" 字符串才能确认删除
- 防止误操作

#### 自我保护
- 管理员不能删除自己
- 防止系统完全锁定

### 9. 前端实现 (Frontend)

#### 技术栈
- **Stimulus**: JavaScript 框架
- **Tailwind CSS**: 样式框架
- **Turbo**: 页面加速

#### 组件
1. **DeletionModalController**: 处理删除模态框
   - 获取删除预览
   - 验证确认输入
   - 提交删除请求
   - 显示成功/错误消息

2. **RestoreButtonController**: 处理恢复按钮
   - 确认恢复操作
   - 提交恢复请求
   - 显示结果

#### 用户界面
- **三个标签页**:
  - Active Items: 显示活跃的用户和事件
  - Deleted Items: 显示已删除的项目
  - Audit Log: 显示操作历史

### 10. 数据库架构 (Database Schema)

#### 新增字段

**users 表**:
- `role` (integer, default: 0): 用户角色
- `deleted_at` (datetime): 软删除时间戳
- `deleted_by_id` (bigint): 执行删除的管理员 ID
- `deletion_reason` (text): 删除原因

**event_posts 表**:
- `deleted_at` (datetime)
- `deleted_by_id` (bigint)
- `deletion_reason` (text)

**event_registrations 表**:
- `deleted_at` (datetime)

**admin_audit_logs 表** (新建):
- `admin_user_id` (references users)
- `action` (string): 'delete' | 'restore'
- `target_type` (string): 'User' | 'EventPost'
- `target_id` (integer)
- `metadata` (jsonb)
- `ip_address` (string)
- `user_agent` (string)
- `created_at`, `updated_at`

## API 端点

### 删除预览
```
GET /admin/users/:id/deletion_preview
GET /admin/event_posts/:id/deletion_preview
```

### 删除操作
```
DELETE /admin/users/:id
DELETE /admin/event_posts/:id

请求体:
{
  "confirmation": "DELETE",
  "reason": "Optional deletion reason"
}
```

### 恢复操作
```
POST /admin/restore/:type/:id

参数:
- type: 'user' | 'event_post'
- id: 记录 ID
```

### Dashboard
```
GET /admin
```

## 工作流程示例

### 删除用户流程

1. **管理员点击删除按钮**
   - 前端调用 `GET /admin/users/:id/deletion_preview`
   - 显示删除预览模态框

2. **管理员确认删除**
   - 输入 "DELETE" 确认
   - 可选输入删除原因
   - 前端调用 `DELETE /admin/users/:id`

3. **Controller 处理**
   - 验证确认字符串
   - 检查权限
   - 记录审计日志
   - 将任务加入队列
   - 立即返回成功

4. **后台任务执行**（异步）
   - `AdminDeletionJob` 被 worker 处理
   - 调用 `soft_delete_with_cascade!`
   - 软删除用户及其所有关联数据
   - 记录完成日志

5. **结果**
   - 用户出现在 "Deleted Items" 标签页
   - 可以在 30 天内恢复

### 恢复用户流程

1. **管理员查看已删除项目**
   - 切换到 "Deleted Items" 标签页
   - 找到要恢复的用户

2. **点击恢复按钮**
   - 前端调用 `POST /admin/restore/user/:id`
   - 显示确认对话框

3. **Controller 处理**
   - 恢复用户本身
   - 恢复用户的所有事件
   - 恢复用户的所有注册
   - 记录审计日志

4. **结果**
   - 用户回到 "Active Items" 标签页
   - 所有关联数据也被恢复

## 技术细节

### 后台任务系统
- **队列**: Solid Queue (Rails 内置)
- **Worker**: 需要运行 `bin/rails solid_queue:start`
- **重试机制**: 任务失败会自动重试

### 性能考虑
- **异步处理**: 删除操作不阻塞 HTTP 请求
- **事务保护**: 级联删除在事务中执行
- **索引优化**: `deleted_at` 字段已建立索引

### 数据完整性
- **外键约束**: `deleted_by_id` 有外键约束
- **事务保证**: 所有删除操作在事务中
- **软删除**: 数据不会真正丢失，可以恢复

## 测试策略

### 单元测试
- 模型方法测试（`soft_delete_with_cascade!`, `deletion_preview`）
- 权限方法测试（`can_delete_user?`, `can_delete_event?`）

### 集成测试
- API 端点测试
- 权限验证测试
- 级联删除测试
- 恢复功能测试

### 异步测试
- 后台任务执行测试
- 队列处理测试

## 未来增强

1. **批量操作**: 支持批量删除多个用户/事件
2. **永久删除**: 30 天后自动永久删除
3. **导出功能**: 删除前导出用户数据（GDPR 要求）
4. **通知系统**: 删除时通知相关用户
5. **统计面板**: 显示删除统计和趋势

