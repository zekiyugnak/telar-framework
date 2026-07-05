---
name: "flutter-styling"
description: "Material 3 theming and responsive design patterns."
source_type: "skill"
source_file: "skills/flutter-styling.md"
---

# flutter-styling

Migrated from `skills/flutter-styling.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Styling & Theming

Material 3 theming and responsive design patterns.

## Material 3 Theme

```dart
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.interTextTheme(),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.dark,
  ),
);

// Usage
MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ThemeMode.system,
)
```

## Responsive Layouts

```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200 && desktop != null) return desktop!;
        if (constraints.maxWidth >= 768 && tablet != null) return tablet!;
        return mobile;
      },
    );
  }
}

// Responsive padding
EdgeInsets.symmetric(
  horizontal: MediaQuery.sizeOf(context).width > 768 ? 32 : 16,
)
```

## Google Fonts

`google_fonts` has two modes. The default is **runtime fetch on first launch**, cached to the app's documents dir. This fails silently offline, and app-store reviewers often hit it cold. For production apps ship fonts as bundled assets instead.

### Bundled (recommended for production)

1. Download `.ttf` files from [fonts.google.com](https://fonts.google.com) (commit the licence file alongside — SIL OFL for most fonts).
2. Drop them under `assets/fonts/` and declare in `pubspec.yaml`:

   ```yaml
   flutter:
     fonts:
       - family: Inter
         fonts:
           - asset: assets/fonts/Inter-Regular.ttf
           - asset: assets/fonts/Inter-Medium.ttf
             weight: 500
           - asset: assets/fonts/Inter-SemiBold.ttf
             weight: 600
   ```

3. Disable runtime fetching so a missing asset fails loudly in dev instead of hitting the network in production:

   ```dart
   void main() {
     GoogleFonts.config.allowRuntimeFetching = false;
     runApp(const MyApp());
   }
   ```

4. Compose the theme from the bundled family:

   ```dart
   textTheme: GoogleFonts.interTextTheme(
     Theme.of(context).textTheme,
   ).apply(bodyColor: colorScheme.onSurface),
   ```

### Runtime fetch (prototypes only)

`GoogleFonts.inter()` with default config will fetch on first use and cache thereafter. Fine for prototypes; not fine for apps that must work offline on first launch or that want predictable first-paint timing.

### Licensing

Google Fonts ship under SIL OFL / Apache 2.0. Include the licence file in your app's licence screen — use `LicenseRegistry.addLicense` at startup to surface it in `showLicensePage`.

```dart
LicenseRegistry.addLicense(() async* {
  final license = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(['google_fonts'], license);
});
```

## Custom Components

```dart
class AppButton extends StatelessWidget {
  const AppButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
      child: Text(label),
    );
  }
}
```

## Best Practices

- Use ColorScheme.fromSeed for consistent colors
- Prefer const constructors
- Use Theme.of(context) for dynamic colors
- Test on multiple screen sizes
