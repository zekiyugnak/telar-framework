---
name: "rn-new-architecture"
description: "Understanding and migrating to React Native's new architecture (Fabric & TurboModules)."
source_type: "skill"
source_file: "skills/rn-new-architecture.md"
---

# rn-new-architecture

Migrated from `skills/rn-new-architecture.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# React Native New Architecture

Understanding and migrating to React Native's new architecture (Fabric & TurboModules).

## Architecture Overview

```text
Old Architecture:
JS Thread → Bridge (JSON) → Native Thread

New Architecture:
JS Thread → JSI (C++ bindings) → Native Thread
         → Codegen (Type safety)
         → Fabric (Concurrent rendering)
```

## TurboModule Spec

```typescript
// NativeCalendar.ts
import type { TurboModule } from 'react-native'
import { TurboModuleRegistry } from 'react-native'

export interface Spec extends TurboModule {
  // Synchronous methods (use sparingly)
  getConstants(): { defaultCalendarId: string }

  // Async methods
  createEvent(title: string, date: number): Promise<string>
  getEvents(startDate: number, endDate: number): Promise<Event[]>
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeCalendar')
```

## Codegen Configuration

```json
// package.json
{
  "codegenConfig": {
    "name": "RNCalendarSpec",
    "type": "modules",
    "jsSrcsDir": "src/native",
    "android": {
      "javaPackageName": "com.myapp.calendar"
    }
  }
}
```

## Enabling New Architecture

```ruby
# ios/Podfile
ENV['RCT_NEW_ARCH_ENABLED'] = '1'
```

```groovy
// android/gradle.properties
newArchEnabled=true
```

## Migration Steps

1. Enable Hermes engine
2. Update to React Native 0.71+
3. Enable new architecture flags
4. Migrate native modules to TurboModules
5. Update native views to Fabric components

## Best Practices

- Start with Hermes enabled
- Migrate one module at a time
- Use Codegen for type safety
- Test thoroughly on both platforms
