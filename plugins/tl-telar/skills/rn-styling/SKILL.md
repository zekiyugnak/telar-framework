---
name: "rn-styling"
description: "Styling patterns and libraries for React Native applications."
source_type: "skill"
source_file: "skills/rn-styling.md"
---

# rn-styling

Migrated from `skills/rn-styling.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# React Native Styling

Styling patterns and libraries for React Native applications.

## StyleSheet Patterns

```typescript
import { StyleSheet, useWindowDimensions } from 'react-native'

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  text: {
    fontSize: 16,
    fontWeight: '500',
  },
  shadow: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3, // Android
  },
})

// Dynamic styles
const createStyles = (theme: Theme) => StyleSheet.create({
  container: {
    backgroundColor: theme.background,
  },
})
```

## NativeWind (Tailwind)

```typescript
// tailwind.config.js
module.exports = {
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#007AFF',
      },
    },
  },
}

// Component
import { View, Text } from 'react-native'

function Card({ title }) {
  return (
    <View className="bg-white rounded-lg p-4 shadow-md">
      <Text className="text-lg font-semibold text-gray-900">{title}</Text>
    </View>
  )
}
```

## Responsive Design

```typescript
function useResponsive() {
  const { width } = useWindowDimensions()
  return {
    isPhone: width < 768,
    isTablet: width >= 768,
    columns: width >= 768 ? 3 : width >= 480 ? 2 : 1,
  }
}
```

## Best Practices

- Extract styles outside components
- Use theme context for colors
- Prefer flexbox for layouts
- Test on multiple screen sizes
