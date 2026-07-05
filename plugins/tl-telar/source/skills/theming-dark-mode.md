---
id: theming-dark-mode
category: skill
tags: [theming, dark-mode, colors, design-system, dynamic-theme]
capabilities:
  - System theme detection
  - Custom theme implementation
  - Dynamic theming
  - Color scheme management
useWhen:
  - Implementing dark mode
  - Creating custom themes
  - Building design systems
---

# Theming & Dark Mode

Implementing theme systems with dark mode support.

## React Native

```typescript
import { useColorScheme } from 'react-native'

const themes = {
  light: {
    background: '#FFFFFF',
    surface: '#F5F5F5',
    text: '#000000',
    primary: '#007AFF',
  },
  dark: {
    background: '#000000',
    surface: '#1C1C1E',
    text: '#FFFFFF',
    primary: '#0A84FF',
  },
}

const ThemeContext = createContext(themes.light)

function ThemeProvider({ children }) {
  const systemTheme = useColorScheme()
  const theme = themes[systemTheme ?? 'light']

  return (
    <ThemeContext.Provider value={theme}>
      {children}
    </ThemeContext.Provider>
  )
}

const useTheme = () => useContext(ThemeContext)
```

## Flutter

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system, // or .light, .dark
)

// Usage
final colorScheme = Theme.of(context).colorScheme;
Container(color: colorScheme.surface)
```

## Color Best Practices

```text
Light Mode:
- Background: #FFFFFF
- Surface: #F5F5F5 to #FAFAFA
- Text: #000000 (primary), #666666 (secondary)

Dark Mode:
- Background: #000000 to #121212
- Surface: #1C1C1E to #2C2C2E
- Text: #FFFFFF (primary), #8E8E93 (secondary)

Ensure 4.5:1 contrast ratio for accessibility
```

## Best Practices

- Follow system preference by default
- Allow user override
- Test both themes thoroughly
- Use semantic color names (primary, surface, etc.)
