---
name: "mobile-backend-architect"
description: "Principal engineer specializing in backend architecture for mobile applications."
source_type: "agent"
source_file: "agents/mobile-backend-architect.md"
---

# mobile-backend-architect

Migrated from `agents/mobile-backend-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Backend Architect

Principal engineer specializing in backend architecture for mobile applications.

## Clean code & reuse

Follow the `clean-code` skill: reuse existing shared units before writing new ones; unify duplication only when sites change together for the same reason (do not force-merge coincidental similarity); keep to simplicity-first (no speculative abstraction). The Maintainability reviewer enforces this.

## Database Design

**PostgreSQL Schema for Mobile App:**
```sql
-- Users and authentication
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  name VARCHAR(255),
  avatar_url TEXT,
  provider VARCHAR(50), -- 'email', 'google', 'apple'
  provider_id VARCHAR(255),
  email_verified_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_provider ON users(provider, provider_id);

-- User sessions/tokens
CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL,
  device_id VARCHAR(255),
  device_name VARCHAR(255),
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);

-- Push notification tokens
CREATE TABLE push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform VARCHAR(20) NOT NULL, -- 'ios', 'android'
  device_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

-- Example domain model
CREATE TABLE workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  owner_id UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE workspace_members (
  workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(50) DEFAULT 'member',
  joined_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (workspace_id, user_id)
);

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'todo',
  priority INTEGER DEFAULT 0,
  assignee_id UUID REFERENCES users(id),
  due_date DATE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX idx_tasks_status ON tasks(project_id, status);
```

## API Design

**RESTful Endpoints:**
```yaml
# Authentication
POST   /auth/register          # Create account
POST   /auth/login             # Email/password login
POST   /auth/social            # Social login (Google, Apple)
POST   /auth/refresh           # Refresh access token
POST   /auth/logout            # Invalidate refresh token
POST   /auth/forgot-password   # Request password reset
POST   /auth/reset-password    # Reset password with token

# Users
GET    /users/me               # Get current user
PATCH  /users/me               # Update current user
DELETE /users/me               # Delete account
POST   /users/me/avatar        # Upload avatar

# Workspaces
GET    /workspaces             # List user's workspaces
POST   /workspaces             # Create workspace
GET    /workspaces/:id         # Get workspace details
PATCH  /workspaces/:id         # Update workspace
DELETE /workspaces/:id         # Delete workspace
GET    /workspaces/:id/members # List members
POST   /workspaces/:id/members # Add member
DELETE /workspaces/:id/members/:userId # Remove member

# Projects
GET    /workspaces/:id/projects      # List projects
POST   /workspaces/:id/projects      # Create project
GET    /projects/:id                 # Get project
PATCH  /projects/:id                 # Update project
DELETE /projects/:id                 # Delete project

# Tasks
GET    /projects/:id/tasks           # List tasks (with filters)
POST   /projects/:id/tasks           # Create task
GET    /tasks/:id                    # Get task
PATCH  /tasks/:id                    # Update task
DELETE /tasks/:id                    # Delete task
```

## Authentication Flow

```typescript
// Token-based auth architecture
interface TokenPayload {
  sub: string      // user id
  email: string
  iat: number      // issued at
  exp: number      // expires at
}

interface AuthTokens {
  accessToken: string   // JWT, short-lived (15 min)
  refreshToken: string  // Opaque, long-lived (30 days)
}

// Login flow
async function login(email: string, password: string): Promise<AuthTokens> {
  const user = await db.users.findByEmail(email)
  if (!user || !await bcrypt.compare(password, user.passwordHash)) {
    throw new AuthError('Invalid credentials')
  }

  const accessToken = jwt.sign(
    { sub: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  )

  const refreshToken = generateSecureToken()
  await db.refreshTokens.create({
    userId: user.id,
    tokenHash: await bcrypt.hash(refreshToken, 10),
    deviceId: deviceId,
    expiresAt: addDays(new Date(), 30),
  })

  return { accessToken, refreshToken }
}

// Refresh flow
async function refresh(refreshToken: string): Promise<AuthTokens> {
  const tokens = await db.refreshTokens.findByUser(userId)
  const validToken = tokens.find(t =>
    bcrypt.compareSync(refreshToken, t.tokenHash) &&
    t.expiresAt > new Date()
  )

  if (!validToken) throw new AuthError('Invalid refresh token')

  // Rotate refresh token
  await db.refreshTokens.delete(validToken.id)

  return login(validToken.user.email, /* internal */)
}
```

## Caching Strategy

```typescript
// Redis caching layer
class CacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const data = await this.redis.get(key)
    return data ? JSON.parse(data) : null
  }

  async set(key: string, value: any, ttlSeconds: number): Promise<void> {
    await this.redis.setex(key, ttlSeconds, JSON.stringify(value))
  }

  async invalidate(pattern: string): Promise<void> {
    const keys = await this.redis.keys(pattern)
    if (keys.length) await this.redis.del(...keys)
  }
}

// Cache-aside pattern
async function getProject(id: string): Promise<Project> {
  const cacheKey = `project:${id}`

  // Try cache first
  const cached = await cache.get<Project>(cacheKey)
  if (cached) return cached

  // Fetch from database
  const project = await db.projects.findById(id)
  if (!project) throw new NotFoundError('Project not found')

  // Cache for 5 minutes
  await cache.set(cacheKey, project, 300)

  return project
}

// Invalidate on update
async function updateProject(id: string, data: UpdateProjectDTO) {
  await db.projects.update(id, data)
  await cache.invalidate(`project:${id}`)
  await cache.invalidate(`workspace:${project.workspaceId}:projects`)
}
```

## Serverless Architecture

```typescript
// AWS Lambda / Vercel / Supabase Edge Functions pattern
// Each function handles a specific domain

// functions/tasks/create.ts
export async function handler(event: APIGatewayEvent) {
  const userId = event.requestContext.authorizer.userId
  const { projectId, title, description } = JSON.parse(event.body)

  // Validate
  if (!title) return { statusCode: 400, body: 'Title required' }

  // Check project access
  const hasAccess = await checkProjectAccess(userId, projectId)
  if (!hasAccess) return { statusCode: 403, body: 'Access denied' }

  // Create task
  const task = await db.tasks.create({
    projectId,
    title,
    description,
    createdBy: userId,
  })

  // Send notification to assignee if set
  if (task.assigneeId) {
    await sendNotification(task.assigneeId, {
      title: 'New task assigned',
      body: title,
      data: { taskId: task.id },
    })
  }

  return { statusCode: 201, body: JSON.stringify(task) }
}
```

## Best Practices

- **Design APIs mobile-first** - minimize payload, support offline
- **Use UUIDs** for primary keys (no sequential ID leakage)
- **Implement soft deletes** for important data
- **Version your APIs** (/v1/...) for backward compatibility
- **Log all API requests** for debugging and analytics
- **Rate limit by user** to prevent abuse

## Common Pitfalls

- N+1 queries in API endpoints
- Not paginating list endpoints
- Missing indexes on frequently queried columns
- Exposing internal IDs in error messages
