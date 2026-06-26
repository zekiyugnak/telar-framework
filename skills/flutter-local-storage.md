---
id: flutter-local-storage
category: skill
tags: [sqflite, path-provider, path, drift, hive, isar, sqlite, migrations, storage]
capabilities:
  - sqflite schema, migrations, transactions, parameterized queries
  - path_provider directory selection matrix (documents / support / cache / temp)
  - path for cross-platform file path manipulation
  - Decision framework sqflite vs drift vs hive vs isar
  - In-memory testing with sqflite_common_ffi
  - FTS5 full-text search in sqflite
useWhen:
  - Choosing a local database for a Flutter app
  - Designing schema and migrations for sqflite
  - Writing parameterized queries and transactions
  - Picking the right app directory for persistent vs cache data
  - Writing fast unit tests against SQLite without device dependencies
  - Adding full-text search to a local database
---

# Flutter Local Storage

`sqflite` + `path_provider` for relational storage, with a decision framework against `drift`, `hive`, and `isar`. For encrypted storage see `secure-storage`. For server-state caching (React Query / Riverpod `AsyncValue`) see state-management skills — this skill is about **persistent on-device data**.

## Decision: which database?

| Concern | `sqflite` | `drift` | `hive` | `isar` |
|---|---|---|---|---|
| SQL familiarity | Raw SQL | Type-safe DSL over SQL | Key-value (no SQL) | Query DSL (no SQL) |
| Migrations | Manual `onUpgrade` | Versioned schema codegen | Manual (schema-free per box) | Versioned schema codegen |
| Codegen required | No | Yes (`build_runner`) | Yes for typed boxes | Yes (`build_runner`) |
| Query power | Full SQL + FTS5 | Full SQL + type-safe | Basic filter/sort | Indexed queries, full-text |
| Maturity | Very mature, Dart team adjacent | Mature | Mature but less active | Active, newer |
| Platform reach | iOS/Android/macOS | Inherits sqflite | All (including web) | iOS/Android/macOS |

**Default: `sqflite`** — battle-tested, no codegen, direct SQL you can debug with any SQLite tool. Pick it unless one of the following applies:

- **Pick `drift`** if you want type-safe queries without hand-writing `Map<String, Object?>` — worth the `build_runner` overhead on non-trivial schemas
- **Pick `hive`** if your data is key-value or flat objects and you do not need relational queries
- **Pick `isar`** if you need embedded full-text, fast indexed queries, or want a non-SQL Dart-native API

**Don't mix.** Pick one and commit. Migrating between them later is a full schema rewrite.

## `path_provider` — which directory?

`sqflite` databases almost always live under `getApplicationDocumentsDirectory()`. But there are four meaningfully different dirs — pick the wrong one and the OS wipes your data.

| Getter | iOS | Android | Survives reboots? | Survives OS cleanup? | Use for |
|---|---|---|---|---|---|
| `getApplicationDocumentsDirectory` | `Documents/` (backs up to iCloud unless excluded) | `files/` | Yes | Yes | **User-generated data**, SQLite DBs, saved content |
| `getApplicationSupportDirectory` | `Library/Application Support/` (backed up) | `files/` | Yes | Yes | Config, state the user didn't create |
| `getApplicationCacheDirectory` | `Library/Caches/` | `cache/` | Yes | **No** — OS may purge under pressure | Image cache, downloaded thumbnails |
| `getTemporaryDirectory` | `tmp/` | `cache/` | **No, cleared on reboot on iOS** | No | Scratch files, current-session only |

```dart
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<String> databasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'app.db');
}
```

iOS note: files under `Documents/` back up to iCloud by default. If your DB can be re-downloaded from your server, **exclude it from backup** via `NSURLIsExcludedFromBackupKey` (use `file.setExtendedAttribute`). Uncontrolled DB growth counts against the user's iCloud storage.

## `path` — cross-platform path helpers

Never concatenate paths with `'/'` — use `package:path`:

```dart
import 'package:path/path.dart' as p;

p.join('/Users/me', 'docs', 'app.db');     // '/Users/me/docs/app.db'
p.basename('/Users/me/app.db');            // 'app.db'
p.basenameWithoutExtension('/a/app.db');   // 'app'
p.extension('/a/app.db');                  // '.db'
p.dirname('/Users/me/app.db');             // '/Users/me'
```

Do not import `package:path/path.dart` without the `as p` prefix — it shadows `Uri.path` and can cause subtle bugs.

## `sqflite` — the default path

### Opening a database with migrations

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;
  Database get db => _db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'app.db');

    final db = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id    TEXT PRIMARY KEY,
        name  TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title       TEXT NOT NULL,
        completed   INTEGER NOT NULL DEFAULT 0,
        due_date    INTEGER,
        created_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_user_id ON tasks(user_id)');
    await db.execute('CREATE INDEX idx_tasks_due_date ON tasks(due_date) WHERE due_date IS NOT NULL');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN due_date INTEGER');
      await db.execute('CREATE INDEX idx_tasks_due_date ON tasks(due_date) WHERE due_date IS NOT NULL');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN display_name TEXT');
    }
  }
}
```

### Rules of thumb

- **`PRAGMA foreign_keys = ON`** must be in `onConfigure`, not `onOpen` — SQLite has it off by default
- **Migrations are forward-only.** Never edit a past migration block. If `v2` shipped, write `v3`
- **Indexes on every foreign key and every column used in a `WHERE`** — the N+1 guard at the storage layer
- **Partial indexes** (`WHERE due_date IS NOT NULL`) are cheaper than full indexes for nullable columns
- **`ON DELETE CASCADE`** requires `foreign_keys = ON` — the pragma setting is per-connection

### Parameterized queries

Never string-interpolate values into SQL — it's a SQL-injection vector even for "trusted" data and breaks on quotes.

```dart
Future<List<Task>> tasksForUser(String userId) async {
  final rows = await _db.query(
    'tasks',
    where: 'user_id = ? AND completed = 0',
    whereArgs: [userId],
    orderBy: 'due_date ASC NULLS LAST, created_at DESC',
  );
  return rows.map(Task.fromRow).toList();
}

Future<void> insertTask(Task task) async {
  await _db.insert(
    'tasks',
    task.toRow(),
    conflictAlgorithm: ConflictAlgorithm.abort,
  );
}

Future<int> completeTask(String taskId) {
  return _db.update(
    'tasks',
    {'completed': 1},
    where: 'id = ?',
    whereArgs: [taskId],
  );
}
```

For joins and anything the `query` helper can't express, use `rawQuery` — still parameterized:

```dart
final rows = await _db.rawQuery('''
  SELECT t.*, u.name AS user_name
  FROM tasks t
  JOIN users u ON u.id = t.user_id
  WHERE t.due_date < ?
  ORDER BY t.due_date ASC
''', [DateTime.now().millisecondsSinceEpoch]);
```

### Transactions and batches

Wrap multi-statement writes in a transaction so partial failures don't leave the DB inconsistent:

```dart
Future<void> completeAllTasksForUser(String userId) async {
  await _db.transaction((txn) async {
    await txn.update(
      'tasks',
      {'completed': 1},
      where: 'user_id = ? AND completed = 0',
      whereArgs: [userId],
    );
    await txn.insert('user_events', {
      'user_id': userId,
      'event': 'completed_all',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  });
}
```

For bulk inserts use `batch` — it coalesces round-trips to the SQLite process:

```dart
Future<void> seedTasks(List<Task> tasks) async {
  final batch = _db.batch();
  for (final task in tasks) {
    batch.insert('tasks', task.toRow());
  }
  await batch.commit(noResult: true);
}
```

### FTS5 for search

SQLite has a built-in full-text engine. A single virtual table gets you ranked search across a column:

```dart
await db.execute('''
  CREATE VIRTUAL TABLE tasks_fts USING fts5(
    task_id UNINDEXED,
    title,
    content=tasks,
    content_rowid=rowid
  )
''');

// Triggers keep FTS index in sync with tasks table
await db.execute('''
  CREATE TRIGGER tasks_ai AFTER INSERT ON tasks BEGIN
    INSERT INTO tasks_fts(rowid, task_id, title) VALUES (new.rowid, new.id, new.title);
  END
''');

// Search
final hits = await db.rawQuery('''
  SELECT t.* FROM tasks t
  JOIN tasks_fts f ON f.rowid = t.rowid
  WHERE tasks_fts MATCH ?
  ORDER BY rank
''', ['buy*']);
```

Match syntax: `?` takes an FTS query (`buy*`, `"due soon"`, `NEAR(buy groceries)`). Wrap user input to prevent query-syntax errors.

## Testing with `sqflite_common_ffi`

The real `sqflite` binds to platform channels — useless in unit tests. `sqflite_common_ffi` runs the same SQLite engine in-process, so your queries execute against real SQLite.

```yaml
dev_dependencies:
  sqflite_common_ffi: ^2.3.3
```

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration from v2 to v3 adds display_name', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE users (id TEXT PRIMARY KEY)');
      },
    );
    await db.close();

    final upgraded = await openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onCreate: AppDatabase._onCreate,
      onUpgrade: AppDatabase._onUpgrade,
    );

    final cols = await upgraded.rawQuery('PRAGMA table_info(users)');
    expect(cols.any((c) => c['name'] == 'display_name'), isTrue);
  });
}
```

Use `inMemoryDatabasePath` so each test starts clean. `databaseFactory = databaseFactoryFfi` must be in `setUpAll` — not every test.

## When `hive` is the right call

For flat, schemaless key-value data (user preferences, offline-cached JSON responses, simple object graphs without joins) `hive` is faster to wire up than `sqflite`:

```dart
import 'package:hive_flutter/hive_flutter.dart';

await Hive.initFlutter();
final box = await Hive.openBox<String>('prefs');
await box.put('theme', 'dark');
final theme = box.get('theme', defaultValue: 'light');
```

Register typed adapters for custom classes. Hive has no relational queries — if you find yourself wanting joins, you picked the wrong tool; migrate to `sqflite` or `drift` before the data grows.

## Best Practices

- **Pick one database** and stick with it — migrations between storage engines cost more than any gain
- **Put the DB under `getApplicationDocumentsDirectory`** unless it's genuinely cache
- **Exclude large DBs from iCloud backup** on iOS if they can be regenerated
- **Index every foreign key and WHERE-column** from day one
- **Write migrations forward-only** — never edit a past `onUpgrade` block
- **Use transactions for multi-statement writes**, `batch` for bulk inserts
- **Use parameterized queries always** — even for internal values
- **Test migrations against `sqflite_common_ffi`** — catches schema regressions without a device

## Common Pitfalls

- **Foreign keys silently ignored** — forgot `PRAGMA foreign_keys = ON`
- **Migration ran twice** — `onCreate` runs only on a fresh DB; migrating an already-installed app runs `onUpgrade` instead. Don't put schema in both
- **DB file in `getTemporaryDirectory`** — lost on reboot, support cases you cannot debug
- **Unindexed `WHERE` clauses** — query scales linearly with row count, sluggish UI at ~10k rows
- **String-interpolated SQL** — SQL injection + breaks on apostrophes in data
- **Holding a `Database` reference across hot reloads** — the handle becomes stale; re-open on app resume or use a DI-scoped lifetime
- **Editing a shipped migration** — installed apps skip your edit; schemas diverge
- **FTS index out of sync with base table** — forgot the `ai`/`au`/`ad` triggers that keep it fresh
