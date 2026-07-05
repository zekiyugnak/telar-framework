---
id: rn-new-architecture
category: skill
tags: [fabric, turbomodules, jsi, codegen, new-architecture]
capabilities:
  - Fabric renderer understanding
  - TurboModules migration
  - JSI direct native access
  - Codegen for type-safe modules
useWhen:
  - Migrating to React Native new architecture
  - Creating TurboModules
  - Understanding Fabric renderer
---

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
