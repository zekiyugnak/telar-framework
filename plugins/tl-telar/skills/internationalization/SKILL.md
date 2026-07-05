---
name: "internationalization"
description: "Multi-language and localization support."
source_type: "skill"
source_file: "skills/internationalization.md"
---

# internationalization

Migrated from `skills/internationalization.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Internationalization (i18n)

Multi-language and localization support.

## React Native

```typescript
// Using i18next
import i18n from 'i18next'
import { initReactI18next, useTranslation } from 'react-i18next'

i18n.use(initReactI18next).init({
  resources: {
    en: { translation: { welcome: 'Welcome', items: '{{count}} item', items_plural: '{{count}} items' } },
    es: { translation: { welcome: 'Bienvenido', items: '{{count}} artículo', items_plural: '{{count}} artículos' } },
  },
  lng: 'en',
  fallbackLng: 'en',
})

// Usage
function WelcomeScreen() {
  const { t, i18n } = useTranslation()

  return (
    <View>
      <Text>{t('welcome')}</Text>
      <Text>{t('items', { count: 5 })}</Text>
    </View>
  )
}

// RTL support
import { I18nManager } from 'react-native'
I18nManager.forceRTL(isRTL)
```

## Flutter

```dart
// Using flutter_localizations
MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: [Locale('en'), Locale('es'), Locale('ar')],
)

// arb files: lib/l10n/app_en.arb
{
  "welcome": "Welcome",
  "itemCount": "{count, plural, =1{1 item} other{{count} items}}"
}

// Usage
Text(AppLocalizations.of(context)!.welcome)
```

## Date/Number Formatting

```typescript
// React Native
import { format } from 'date-fns'
import { enUS, es } from 'date-fns/locale'

format(date, 'PPP', { locale: es }) // "25 de diciembre de 2024"

// Number formatting
new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' })
  .format(1234.56) // "1.234,56 €"
```

## Best Practices

- Extract all strings to translation files
- Support pluralization from the start
- Test RTL layouts thoroughly
- Use ICU message format for complex strings
