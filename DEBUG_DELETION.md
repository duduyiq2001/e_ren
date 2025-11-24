# 删除功能调试指南

## 问题排查步骤

### 1. 检查用户是否存在

在 Rails console 中：
```ruby
# 查看所有用户
User.all.each { |u| puts "#{u.id}: #{u.email}, role: #{u.role}, deleted: #{u.discarded?}" }

# 查看特定用户
user = User.find_by(email: 'user1@wustl.edu')
puts user.inspect
puts "Discarded? #{user.discarded?}"
```

### 2. 检查路由

```bash
docker exec e_ren_rails bin/rails routes | grep admin
```

应该看到：
- `DELETE /admin/users/:id` → `admin/deletions#destroy`
- `DELETE /admin/event_posts/:id` → `admin/deletions#destroy`

### 3. 检查请求参数

在浏览器开发者工具中：
1. 打开 Network 标签
2. 点击删除按钮
3. 查看 DELETE 请求
4. 检查：
   - URL: 应该是 `/admin/users/2` 或 `/admin/event_posts/1`
   - Request Body: 应该包含 `{"confirmation": "DELETE", "reason": "..."}`
   - Response: 查看返回的错误信息

### 4. 检查 Controller 日志

在 Rails 日志中查看：
```bash
docker exec e_ren_rails tail -f log/development.log
```

然后尝试删除，查看日志输出。

### 5. 测试 API 端点

使用 curl 直接测试：
```bash
# 先登录获取 session
# 然后测试删除预览
curl -X GET http://localhost:3000/admin/users/2/deletion_preview \
  -H "Cookie: _session_id=YOUR_SESSION"

# 测试删除
curl -X DELETE http://localhost:3000/admin/users/2 \
  -H "Content-Type: application/json" \
  -H "Cookie: _session_id=YOUR_SESSION" \
  -d '{"confirmation": "DELETE", "reason": "Test"}'
```

### 6. 常见问题

#### 问题：找不到用户
- **原因1**: 用户已被删除（discarded）
- **解决**: 使用 `User.with_discarded.find(id)` 查找

#### 问题：路由不匹配
- **原因**: 路由参数名称不匹配
- **解决**: 检查 `set_deletable` 方法中的参数识别逻辑

#### 问题：权限不足
- **原因**: 当前用户不是 super_admin
- **解决**: 检查用户角色：`User.find_by(email: 'admin@wustl.edu').role`

## 调试代码位置

1. **Controller**: `app/controllers/admin/deletions_controller.rb`
   - `set_deletable` 方法：负责查找要删除的记录
   - `destroy` 方法：处理删除请求

2. **JavaScript**: `app/javascript/controllers/deletion_modal_controller.js`
   - `confirmDelete` 方法：发送删除请求
   - 检查 URL 构建是否正确

3. **Routes**: `config/routes.rb`
   - 检查 admin 命名空间的路由配置

