# Admin Deletion Feature - 本地测试指南

## 前置准备

### 1. 修复 Gemfile（如果还没修复）

如果遇到 `windows is not a valid platform` 错误，需要修复 Gemfile：

```ruby
# 第 27 行，将：
gem "tzinfo-data", platforms: %i[ windows jruby ]

# 改为：
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# 第 51 行，将：
gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

# 改为：
gem "debug", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"
```

### 2. 安装依赖

```bash
bundle install
```

### 3. 运行数据库迁移

```bash
# 运行所有新的迁移
bin/rails db:migrate

# 或者只运行特定的迁移
bin/rails db:migrate:up VERSION=20251201000001  # Add role to users
bin/rails db:migrate:up VERSION=20251201000002  # Add soft delete to users and event_posts
bin/rails db:migrate:up VERSION=20251201000003  # Add soft delete to event_registrations
bin/rails db:migrate:up VERSION=20251201000004  # Create admin_audit_logs
```

### 4. 确保 Solid Queue 已安装

```bash
# 如果还没安装 Solid Queue 表
bin/rails solid_queue:install
bin/rails db:migrate
```

## 测试步骤

### 步骤 1: 启动 Rails 服务器

在一个终端窗口：

```bash
bin/rails server
```

### 步骤 2: 启动 Solid Queue Worker（重要！）

在另一个终端窗口，启动后台任务处理器：

```bash
bin/rails solid_queue:start
```

**注意**：删除操作是异步的，必须运行 worker 才能执行删除任务！

### 步骤 3: 创建测试管理员用户

在 Rails console 中：

```bash
bin/rails console
```

然后执行：

```ruby
# 创建一个管理员用户
admin = User.create!(
  email: "admin@wustl.edu",
  name: "Admin User",
  password: "password123",
  password_confirmation: "password123",
  role: :super_admin,
  confirmed_at: Time.current
)

# 创建一些测试数据
user1 = User.create!(
  email: "user1@wustl.edu",
  name: "Test User 1",
  password: "password123",
  password_confirmation: "password123",
  confirmed_at: Time.current
)

user2 = User.create!(
  email: "user2@wustl.edu",
  name: "Test User 2",
  password: "password123",
  password_confirmation: "password123",
  confirmed_at: Time.current
)

# 创建一个事件
event = EventPost.create!(
  name: "Test Event",
  description: "This is a test event",
  event_category: EventCategory.first || EventCategory.create!(name: "Test Category"),
  organizer: user1,
  capacity: 20,
  event_time: 2.days.from_now,
  location_name: "Test Location"
)

# 创建一些注册
EventRegistration.create!(user: user2, event_post: event)
```

### 步骤 4: 登录并访问 Admin 面板

1. 打开浏览器，访问 `http://localhost:3000`
2. 使用管理员账号登录：
   - Email: `admin@wustl.edu`
   - Password: `password123`
3. 访问 Admin 面板：`http://localhost:3000/admin`

### 步骤 5: 测试删除功能

#### 测试删除用户：

1. 在 Admin 面板的 "Active Items" 标签页，找到 "Test User 1"
2. 点击 "Delete" 按钮
3. 查看删除预览（应该显示将删除的事件和注册）
4. 输入删除原因（可选）
5. 输入 "DELETE" 确认
6. 点击 "Confirm Deletion"
7. 应该看到成功消息："User deletion queued. It will be processed in the background."
8. 等待几秒钟，刷新页面
9. 用户应该出现在 "Deleted Items" 标签页

#### 测试删除事件：

1. 在 "Active Items" 标签页，找到 "Test Event"
2. 点击 "Delete" 按钮
3. 查看删除预览
4. 输入 "DELETE" 确认
5. 点击 "Confirm Deletion"
6. 等待几秒钟，刷新页面
7. 事件应该出现在 "Deleted Items" 标签页

#### 测试恢复功能：

1. 切换到 "Deleted Items" 标签页
2. 找到已删除的用户或事件
3. 点击 "Restore" 按钮
4. 确认恢复
5. 刷新页面，项目应该回到 "Active Items" 标签页

### 步骤 6: 验证异步删除

1. 查看 Solid Queue worker 的终端输出，应该看到任务执行日志
2. 在 Rails console 中检查：

```ruby
# 检查已删除的用户
User.with_deleted.where.not(deleted_at: nil)

# 检查审计日志
AdminAuditLog.all

# 检查后台任务
# 如果使用 Solid Queue，可以在 Rails console 中查看
```

## 测试检查清单

- [ ] 数据库迁移成功运行
- [ ] Solid Queue worker 正在运行
- [ ] 可以访问 `/admin` 页面（需要管理员权限）
- [ ] 可以查看删除预览
- [ ] 删除操作立即返回（不阻塞）
- [ ] 删除操作在后台执行（查看 worker 日志）
- [ ] 已删除的项目出现在 "Deleted Items" 标签页
- [ ] 可以恢复已删除的项目
- [ ] 审计日志记录了所有操作
- [ ] 级联删除正常工作（删除用户时，其事件也被删除）

## 常见问题

### Q: 删除后项目没有消失？

**A**: 确保 Solid Queue worker 正在运行。删除是异步的，需要 worker 处理任务。

### Q: 无法访问 `/admin`？

**A**: 确保用户是 `super_admin` 角色。检查用户角色：
```ruby
User.find_by(email: "admin@wustl.edu").role
# 应该是 "super_admin"
```

### Q: 删除操作报错？

**A**: 检查：
1. 所有迁移是否已运行
2. 数据库连接是否正常
3. Solid Queue worker 是否在运行
4. 查看 Rails 日志：`tail -f log/development.log`

### Q: 如何查看后台任务状态？

**A**: 在 Rails console 中：
```ruby
# 查看 Solid Queue 任务（如果使用 Solid Queue）
# 或者查看日志
tail -f log/development.log
```

## 测试 API 端点（可选）

如果需要直接测试 API：

```bash
# 获取删除预览
curl -X GET http://localhost:3000/admin/users/1/deletion_preview \
  -H "Cookie: _session_id=YOUR_SESSION_ID"

# 删除用户（需要先登录获取 session）
curl -X DELETE http://localhost:3000/admin/users/1 \
  -H "Content-Type: application/json" \
  -H "Cookie: _session_id=YOUR_SESSION_ID" \
  -d '{"confirmation": "DELETE", "reason": "Test deletion"}'

# 恢复用户
curl -X POST http://localhost:3000/admin/restore/user/1 \
  -H "Cookie: _session_id=YOUR_SESSION_ID"
```

## 运行测试套件

```bash
# 运行所有测试
bundle exec rspec

# 运行特定的测试文件
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/models/event_post_spec.rb
bundle exec rspec spec/requests/admin/deletions_spec.rb
```

