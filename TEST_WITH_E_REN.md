# 使用 e_ren 工具测试 Admin Deletion 功能

## 快速开始

### 1. 启动 Docker 容器

```bash
cd ~/CSE4207/Project/e_ren_infra
e_ren up
```

这会启动 Rails 和 Postgres 容器。

### 2. 运行数据库迁移

```bash
# 在容器内运行迁移
e_ren shell
# 然后在容器内执行：
bin/rails db:migrate
exit
```

或者直接执行：

```bash
docker exec e_ren_rails bin/rails db:migrate
```

### 3. 设置测试数据

```bash
# 进入容器 shell
e_ren shell

# 运行设置脚本
bin/rails runner bin/setup_admin_test

# 或者手动创建管理员
bin/rails console
```

在 Rails console 中：

```ruby
# 创建管理员
admin = User.create!(
  email: "admin@wustl.edu",
  name: "Admin User",
  password: "password123",
  password_confirmation: "password123",
  role: :super_admin,
  confirmed_at: Time.current
)

# 创建测试用户
user1 = User.create!(
  email: "user1@wustl.edu",
  name: "Test User 1",
  password: "password123",
  password_confirmation: "password123",
  confirmed_at: Time.current
)

# 创建测试事件
category = EventCategory.first || EventCategory.create!(name: "General")
event = EventPost.create!(
  name: "Test Event",
  description: "Test event for deletion",
  event_category: category,
  organizer: user1,
  capacity: 20,
  event_time: 2.days.from_now,
  location_name: "Test Location"
)
```

### 4. 启动 Rails 服务器（在一个终端）

```bash
e_ren server
```

服务器会在 `http://localhost:3000` 启动。

### 5. 启动 Solid Queue Worker（在另一个终端）

```bash
# 进入容器
e_ren shell

# 启动 worker
bin/rails solid_queue:start
```

**重要**：删除操作是异步的，必须运行 worker 才能执行删除任务！

### 6. 测试功能

1. **访问 Admin 面板**
   - 打开浏览器：`http://localhost:3000`
   - 登录：`admin@wustl.edu` / `password123`
   - 访问：`http://localhost:3000/admin`

2. **测试删除用户**
   - 在 "Active Items" 标签页找到用户
   - 点击 "Delete" 按钮
   - 查看删除预览
   - 输入 "DELETE" 确认
   - 点击 "Confirm Deletion"
   - 等待几秒后刷新，用户应该出现在 "Deleted Items" 标签页

3. **测试删除事件**
   - 类似步骤，删除一个事件

4. **测试恢复功能**
   - 切换到 "Deleted Items" 标签页
   - 点击 "Restore" 按钮
   - 刷新页面，项目应该回到 "Active Items"

### 7. 运行测试套件

```bash
# 运行所有测试
e_ren test

# 运行特定的测试文件
e_ren test spec/models/user_spec.rb
e_ren test spec/models/event_post_spec.rb
e_ren test spec/requests/admin/deletions_spec.rb
```

## 常用命令

```bash
# 查看容器日志
e_ren logs

# 进入容器 shell
e_ren shell

# 停止容器
e_ren down

# 重启容器
e_ren down && e_ren up
```

## 验证异步删除

在 worker 终端中，你应该能看到类似这样的日志：

```
[SolidQueue] Processing AdminDeletionJob...
[SolidQueue] AdminDeletionJob completed
```

## 故障排除

### 容器没有运行
```bash
e_ren up
```

### 迁移失败
```bash
e_ren shell
bin/rails db:migrate:status  # 查看迁移状态
bin/rails db:migrate         # 运行迁移
```

### 无法访问 /admin
确保用户是 `super_admin` 角色：
```ruby
User.find_by(email: "admin@wustl.edu").role
# 应该是 "super_admin"
```

### 删除操作没有执行
确保 Solid Queue worker 正在运行：
```bash
e_ren shell
bin/rails solid_queue:start
```

