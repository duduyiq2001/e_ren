# Admin Panel Architecture Documentation

## Overview

The Admin Panel is a Role-Based Access Control (RBAC) system that allows super administrators (super_admin) to manage users and events on the platform. The system uses soft deletion, and all deletion operations are executed asynchronously to ensure they don't block user requests.

## Core Components

### 1. Role System

#### User Roles
- **student** (0): Regular student user, default role
- **club_admin** (1): Club administrator
- **super_admin** (2): Super administrator with deletion permissions

#### Permission Checks
```ruby
# Permission methods in User model
def admin?
  super_admin?
end

def can_delete_user?(target_user)
  super_admin? && target_user.id != id # Cannot delete self
end

def can_delete_event?(event_post)
  super_admin?
end
```

### 2. Soft Delete Mechanism

#### Technical Implementation
- **Gem**: `discard` (Rails 8.1 compatible)
- **Column**: `deleted_at` (datetime)
- **Metadata**: 
  - `deleted_by_id`: ID of the admin who performed the deletion
  - `deletion_reason`: Reason for deletion (optional)

#### Model Configuration
```ruby
# User, EventPost, EventRegistration models
include Discard::Model
self.discard_column = :deleted_at
```

#### Query Methods
- `User.all` - Returns only non-deleted records (default)
- `User.discarded` - Returns only deleted records
- `User.with_discarded` - Returns all records (including deleted)
- `user.discarded?` - Check if deleted
- `user.discard` - Soft delete
- `user.undiscard` - Restore

### 3. Async Deletion Flow

#### Architecture Design
```
User Request → Controller → Immediate Response → Background Job Queue → Worker Processing
```

#### Detailed Flow

**Step 1: User Initiates Deletion Request**
```ruby
DELETE /admin/users/:id
{
  confirmation: "DELETE",
  reason: "Spam account"
}
```

**Step 2: Controller Processing (Immediate Response)**
```ruby
# Admin::DeletionsController#destroy
1. Validate confirmation string (must be "DELETE")
2. Check permissions (can_delete_user? / can_delete_event?)
3. Log audit entry (immediately, marked as async: true)
4. Enqueue deletion job (AdminDeletionJob.perform_later)
5. Return success response immediately (without waiting for deletion to complete)
```

**Step 3: Background Job Execution**
```ruby
# AdminDeletionJob#perform
1. Find the record to delete
2. Call soft_delete_with_cascade! method
3. Execute cascading soft deletion
4. Log completion
```

**Step 4: Cascading Deletion Logic**
```ruby
# User#soft_delete_with_cascade!
1. Update deletion metadata (deleted_by_id, deletion_reason)
2. Soft delete all user's events (organized_events)
3. Soft delete all user's registrations (event_registrations)
4. Soft delete the user itself
5. All operations executed within a transaction
```

#### Why Use Async Deletion?

1. **Performance**: Deleting large amounts of associated data doesn't block HTTP requests
2. **User Experience**: Users get immediate responses without waiting
3. **Scalability**: Can handle large deletion operations without affecting server response times
4. **Error Handling**: Background jobs can retry without affecting users

### 4. Cascading Deletion Rules

#### Cascading When Deleting a User
```
User (being deleted)
├── organized_events (all events created by user)
│   └── event_registrations (all registrations for these events)
├── event_registrations (user's direct registrations)
└── User itself
```

#### Cascading When Deleting an Event
```
EventPost (being deleted)
├── event_registrations (all registrations for the event)
└── Event itself
```

#### Implementation Details
- Uses `dependent: :destroy_async` to ensure associated records are deleted asynchronously
- All deletion operations execute within database transactions to ensure data consistency
- Soft deletion doesn't actually delete data, only marks `deleted_at`

### 5. Deletion Preview

#### Functionality
Displays statistics of data that will be deleted before deletion, helping administrators understand the scope of deletion impact.

#### API
```
GET /admin/users/:id/deletion_preview
GET /admin/event_posts/:id/deletion_preview
```

#### Response Data
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

### 6. Restore Mechanism

#### Functionality
Administrators can restore deleted records within a 30-day grace period.

#### API
```
POST /admin/restore/:type/:id
```

#### Restore Logic
```ruby
# When restoring a user
1. Restore the user itself
2. Restore all user's events (organized_events)
3. Restore all user's registrations (event_registrations)

# When restoring an event
1. Restore the event itself
2. Restore all event's registrations (event_registrations)
```

### 7. Audit Log

#### Purpose
Records all administrator operations for:
- Tracking who performed delete/restore operations
- Recording operation time and reason
- Compliance requirements (GDPR, etc.)

#### Data Structure
```ruby
AdminAuditLog
- admin_user_id: Administrator who performed the operation
- action: 'delete' | 'restore'
- target_type: 'User' | 'EventPost'
- target_id: ID of the record being operated on
- metadata: Additional information in JSON format
  - reason: Deletion reason
  - preview: Deletion preview data
  - async: Whether executed asynchronously
  - queued_at: Job enqueue time
- ip_address: Request IP
- user_agent: User agent
- created_at: Operation time
```

### 8. Security Mechanisms

#### Access Control
- **Multi-layer Validation**: Controller layer + Model layer
- **Base Controller**: `Admin::AdminBaseController` handles authentication uniformly
- **Method-level Permissions**: `can_delete_user?`, `can_delete_event?`

#### Confirmation Mechanism
- Must type "DELETE" string to confirm deletion
- Prevents accidental operations

#### Self-Protection
- Administrators cannot delete themselves
- Prevents complete system lockout

### 9. Frontend Implementation

#### Technology Stack
- **Stimulus**: JavaScript framework
- **Tailwind CSS**: Styling framework
- **Turbo**: Page acceleration

#### Components
1. **DeletionModalController**: Handles deletion modal
   - Fetch deletion preview
   - Validate confirmation input
   - Submit deletion request
   - Display success/error messages

2. **RestoreButtonController**: Handles restore button
   - Confirm restore operation
   - Submit restore request
   - Display results

#### User Interface
- **Three Tabs**:
  - Active Items: Display active users and events
  - Deleted Items: Display deleted items
  - Audit Log: Display operation history

### 10. Database Schema

#### New Fields

**users table**:
- `role` (integer, default: 0): User role
- `deleted_at` (datetime): Soft deletion timestamp
- `deleted_by_id` (bigint): ID of admin who performed deletion
- `deletion_reason` (text): Deletion reason

**event_posts table**:
- `deleted_at` (datetime)
- `deleted_by_id` (bigint)
- `deletion_reason` (text)

**event_registrations table**:
- `deleted_at` (datetime)

**admin_audit_logs table** (new):
- `admin_user_id` (references users)
- `action` (string): 'delete' | 'restore'
- `target_type` (string): 'User' | 'EventPost'
- `target_id` (integer)
- `metadata` (jsonb)
- `ip_address` (string)
- `user_agent` (string)
- `created_at`, `updated_at`

## API Endpoints

### Deletion Preview
```
GET /admin/users/:id/deletion_preview
GET /admin/event_posts/:id/deletion_preview
```

### Deletion Operation
```
DELETE /admin/users/:id
DELETE /admin/event_posts/:id

Request Body:
{
  "confirmation": "DELETE",
  "reason": "Optional deletion reason"
}
```

### Restore Operation
```
POST /admin/restore/:type/:id

Parameters:
- type: 'user' | 'event_post'
- id: Record ID
```

### Dashboard
```
GET /admin
```

## Workflow Examples

### User Deletion Flow

1. **Administrator Clicks Delete Button**
   - Frontend calls `GET /admin/users/:id/deletion_preview`
   - Display deletion preview modal

2. **Administrator Confirms Deletion**
   - Type "DELETE" to confirm
   - Optionally enter deletion reason
   - Frontend calls `DELETE /admin/users/:id`

3. **Controller Processing**
   - Validate confirmation string
   - Check permissions
   - Log audit entry
   - Enqueue job
   - Return success immediately

4. **Background Job Execution** (async)
   - `AdminDeletionJob` processed by worker
   - Call `soft_delete_with_cascade!`
   - Soft delete user and all associated data
   - Log completion

5. **Result**
   - User appears in "Deleted Items" tab
   - Can be restored within 30 days

### User Restore Flow

1. **Administrator Views Deleted Items**
   - Switch to "Deleted Items" tab
   - Find user to restore

2. **Click Restore Button**
   - Frontend calls `POST /admin/restore/user/:id`
   - Display confirmation dialog

3. **Controller Processing**
   - Restore user itself
   - Restore all user's events
   - Restore all user's registrations
   - Log audit entry

4. **Result**
   - User returns to "Active Items" tab
   - All associated data also restored

## Technical Details

### Background Job System
- **Queue**: Solid Queue (Rails built-in)
- **Worker**: Need to run `bin/rails solid_queue:start`
- **Retry Mechanism**: Failed jobs automatically retry

### Performance Considerations
- **Async Processing**: Deletion operations don't block HTTP requests
- **Transaction Protection**: Cascading deletions execute within transactions
- **Index Optimization**: `deleted_at` field has index

### Data Integrity
- **Foreign Key Constraints**: `deleted_by_id` has foreign key constraint
- **Transaction Guarantee**: All deletion operations within transactions
- **Soft Deletion**: Data not actually lost, can be restored

## Testing Strategy

### Unit Tests
- Model method tests (`soft_delete_with_cascade!`, `deletion_preview`)
- Permission method tests (`can_delete_user?`, `can_delete_event?`)

### Integration Tests
- API endpoint tests
- Permission validation tests
- Cascading deletion tests
- Restore functionality tests

### Async Tests
- Background job execution tests
- Queue processing tests

## Future Enhancements

1. **Batch Operations**: Support batch deletion of multiple users/events
2. **Permanent Deletion**: Automatic permanent deletion after 30 days
3. **Export Functionality**: Export user data before deletion (GDPR requirement)
4. **Notification System**: Notify related users when deletion occurs
5. **Statistics Dashboard**: Display deletion statistics and trends
