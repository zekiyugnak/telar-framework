---
name: "mobile-storage-specialist"
description: "Expert in local data storage solutions for React Native and Flutter applications."
source_type: "agent"
source_file: "agents/mobile-storage-specialist.md"
---

# mobile-storage-specialist

Migrated from `agents/mobile-storage-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Storage Specialist

Expert in local data storage solutions for React Native and Flutter applications.

## MMKV (Recommended for Key-Value)

**React Native Setup:**
```typescript
import { MMKV } from 'react-native-mmkv'

// Create storage instance
export const storage = new MMKV({
  id: 'app-storage',
  encryptionKey: 'your-encryption-key', // Optional encryption
})

// Type-safe wrapper
class AppStorage {
  private static keys = {
    USER: 'user',
    THEME: 'theme',
    ONBOARDING_COMPLETE: 'onboarding_complete',
  } as const

  static getUser(): User | null {
    const json = storage.getString(this.keys.USER)
    return json ? JSON.parse(json) : null
  }

  static setUser(user: User): void {
    storage.set(this.keys.USER, JSON.stringify(user))
  }

  static getTheme(): 'light' | 'dark' {
    return (storage.getString(this.keys.THEME) as 'light' | 'dark') || 'light'
  }

  static setTheme(theme: 'light' | 'dark'): void {
    storage.set(this.keys.THEME, theme)
  }

  static isOnboardingComplete(): boolean {
    return storage.getBoolean(this.keys.ONBOARDING_COMPLETE) ?? false
  }

  static clear(): void {
    storage.clearAll()
  }
}

// Zustand persist middleware with MMKV
import { StateStorage } from 'zustand/middleware'

export const zustandStorage: StateStorage = {
  getItem: (name) => storage.getString(name) ?? null,
  setItem: (name, value) => storage.set(name, value),
  removeItem: (name) => storage.delete(name),
}
```

## SQLite

**React Native with expo-sqlite:**
```typescript
import * as SQLite from 'expo-sqlite'

class Database {
  private db: SQLite.SQLiteDatabase

  async initialize() {
    this.db = await SQLite.openDatabaseAsync('app.db')

    // Run migrations
    await this.migrate()
  }

  private async migrate() {
    const version = await this.getVersion()

    if (version < 1) {
      await this.db.execAsync(`
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS tasks (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE INDEX idx_tasks_user_id ON tasks(user_id);
      `)
      await this.setVersion(1)
    }

    // Add more migrations as needed
    if (version < 2) {
      await this.db.execAsync(`
        ALTER TABLE tasks ADD COLUMN due_date INTEGER;
      `)
      await this.setVersion(2)
    }
  }

  async getTasks(userId: string): Promise<Task[]> {
    return this.db.getAllAsync<Task>(
      'SELECT * FROM tasks WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    )
  }

  async insertTask(task: Omit<Task, 'id'>): Promise<string> {
    const id = generateUUID()
    await this.db.runAsync(
      'INSERT INTO tasks (id, user_id, title, completed, created_at) VALUES (?, ?, ?, ?, ?)',
      [id, task.userId, task.title, 0, Date.now()]
    )
    return id
  }
}
```

## WatermelonDB (Large Datasets)

```typescript
import { Database } from '@nozbe/watermelondb'
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite'
import { mySchema } from './schema'
import { Task, Project } from './models'

// Schema definition
import { appSchema, tableSchema } from '@nozbe/watermelondb'

export const mySchema = appSchema({
  version: 1,
  tables: [
    tableSchema({
      name: 'tasks',
      columns: [
        { name: 'title', type: 'string' },
        { name: 'is_completed', type: 'boolean' },
        { name: 'project_id', type: 'string', isIndexed: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'projects',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'color', type: 'string' },
      ],
    }),
  ],
})

// Model definition
import { Model } from '@nozbe/watermelondb'
import { field, relation, children } from '@nozbe/watermelondb/decorators'

class Task extends Model {
  static table = 'tasks'
  static associations = {
    projects: { type: 'belongs_to', key: 'project_id' },
  }

  @field('title') title!: string
  @field('is_completed') isCompleted!: boolean
  @relation('projects', 'project_id') project!: Project

  async markComplete() {
    await this.update(task => {
      task.isCompleted = true
    })
  }
}

// Usage with React
import { withObservables } from '@nozbe/watermelondb/react'

const TaskList = ({ tasks }) => (
  <FlatList data={tasks} renderItem={({ item }) => <TaskRow task={item} />} />
)

const enhance = withObservables(['projectId'], ({ database, projectId }) => ({
  tasks: database.get('tasks').query(Q.where('project_id', projectId)).observe(),
}))

export default enhance(TaskList)
```

## Flutter Storage Options

Flutter has four main on-device storage engines. Pick one and commit — migrating between them is a full rewrite.

- **`sqflite` (default for relational data)** — mature, raw SQL, migrations, FTS5. Use when you need joins, indexes, or a queryable schema.
- **`drift`** — type-safe DSL over `sqflite`. Worth the `build_runner` overhead on non-trivial schemas.
- **`hive`** — flat key-value and simple object graphs without joins (shown below). Fastest to wire up.
- **`isar`** — embedded DB with indexed queries and full-text, non-SQL Dart-native API.

For canonical `sqflite` schema + migrations + transactions, `path_provider` directory selection, `path` helpers, FTS5 search, and `sqflite_common_ffi` testing patterns, see the `flutter-local-storage` skill.

## Flutter with Hive

```dart
import 'package:hive_flutter/hive_flutter.dart';

// Initialize
await Hive.initFlutter();
Hive.registerAdapter(UserAdapter());
await Hive.openBox<User>('users');

// Model with TypeAdapter
@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String email;
}

// Usage
class UserRepository {
  final Box<User> _box = Hive.box<User>('users');

  List<User> getAll() => _box.values.toList();

  User? get(String id) => _box.get(id);

  Future<void> save(User user) async {
    await _box.put(user.id, user);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  // Reactive stream
  Stream<BoxEvent> watch() => _box.watch();
}
```

## Best Practices

- **Use MMKV over AsyncStorage** - significantly faster
- **Index frequently queried columns** in SQLite
- **Use WatermelonDB** for apps with large datasets (10k+ records)
- **Encrypt sensitive data** at rest
- **Plan migrations** from the start

## Common Pitfalls

- Using AsyncStorage for large data (performance issues)
- Not indexing SQLite columns used in WHERE clauses
- Missing database migrations causing crashes
- Storing sensitive data without encryption
