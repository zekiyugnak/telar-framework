---
name: "component-scaffolding"
description: "Scaffold production-quality mobile components from design specifications with complete file structure, type safety, accessibility, and test coverage."
source_type: "skill"
source_file: "skills/component-scaffolding.md"
---

# component-scaffolding

Migrated from `skills/component-scaffolding.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Component Scaffolding

Scaffold production-quality mobile components from design specifications with complete file structure, type safety, accessibility, and test coverage.

## Problem

Developers creating mobile components from scratch waste time on repetitive boilerplate: writing prop interfaces, setting up style objects, adding accessibility attributes, creating test files, and building story files. Worse, without a standard pattern, each developer structures components differently, leading to inconsistent codebases that are hard to maintain.

## Solution

### 1. File Structure Convention

Every component generates a directory with four files:

```text
src/components/
  Button/
    Button.tsx          # Component implementation
    useButton.ts        # Hook for component logic
    Button.test.tsx     # Unit tests
    Button.stories.tsx  # Storybook story
    index.ts            # Barrel export
```

Flutter equivalent:

```text
lib/widgets/
  button/
    button.dart         # Widget implementation
    button_controller.dart  # Logic separation
    button_test.dart    # Widget tests (in test/)
```

### 2. React Native Component Template

```typescript
// Button/Button.tsx
import React, { memo } from 'react';
import { Pressable, Text, StyleSheet, ViewStyle, TextStyle } from 'react-native';
import { useButton } from './useButton';

export interface ButtonProps {
  /** Button label text */
  label: string;
  /** Visual variant */
  variant?: 'primary' | 'secondary' | 'ghost';
  /** Size preset */
  size?: 'sm' | 'md' | 'lg';
  /** Disabled state */
  disabled?: boolean;
  /** Loading state - shows spinner and disables interaction */
  loading?: boolean;
  /** Press handler */
  onPress: () => void;
  /** Override accessibility label when label text is insufficient */
  accessibilityLabel?: string;
  /** Test identifier */
  testID?: string;
}

const Button = memo<ButtonProps>(function Button({
  label,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  onPress,
  accessibilityLabel,
  testID,
}) {
  const { handlePress, isDisabled, containerStyle, labelStyle } = useButton({
    variant,
    size,
    disabled,
    loading,
    onPress,
  });

  return (
    <Pressable
      style={({ pressed }) => [
        styles.base,
        containerStyle,
        pressed && !isDisabled && styles.pressed,
        isDisabled && styles.disabled,
      ]}
      onPress={handlePress}
      disabled={isDisabled}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled: isDisabled, busy: loading }}
      testID={testID}
    >
      {loading ? (
        <ActivityIndicator
          color={variant === 'primary' ? '#FFFFFF' : '#007AFF'}
          size="small"
        />
      ) : (
        <Text style={[styles.label, labelStyle]}>{label}</Text>
      )}
    </Pressable>
  );
});

const styles = StyleSheet.create({
  base: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 10,
    minHeight: 44, // iOS minimum touch target
    minWidth: 44,
  },
  pressed: {
    opacity: 0.7,
  },
  disabled: {
    opacity: 0.4,
  },
  label: {
    fontWeight: '600',
    textAlign: 'center',
  },
});

export default Button;
```

### 3. Companion Hook Template

```typescript
// Button/useButton.ts
import { useMemo, useCallback } from 'react';
import { ViewStyle, TextStyle } from 'react-native';
import { useTheme } from '../../theme';
import { ButtonProps } from './Button';

type UseButtonParams = Pick<ButtonProps, 'variant' | 'size' | 'disabled' | 'loading' | 'onPress'>;

export function useButton({ variant, size, disabled, loading, onPress }: UseButtonParams) {
  const theme = useTheme();
  const isDisabled = disabled || loading;

  const handlePress = useCallback(() => {
    if (!isDisabled) onPress();
  }, [isDisabled, onPress]);

  const containerStyle = useMemo<ViewStyle>(() => {
    const variantStyles: Record<string, ViewStyle> = {
      primary:   { backgroundColor: theme.primary },
      secondary: { backgroundColor: 'transparent', borderWidth: 1, borderColor: theme.primary },
      ghost:     { backgroundColor: 'transparent' },
    };
    const sizeStyles: Record<string, ViewStyle> = {
      sm: { paddingVertical: 6,  paddingHorizontal: 12 },
      md: { paddingVertical: 12, paddingHorizontal: 24 },
      lg: { paddingVertical: 16, paddingHorizontal: 32 },
    };
    return { ...variantStyles[variant!], ...sizeStyles[size!] };
  }, [variant, size, theme]);

  const labelStyle = useMemo<TextStyle>(() => {
    const colorMap: Record<string, string> = {
      primary:   '#FFFFFF',
      secondary: theme.primary,
      ghost:     theme.primary,
    };
    const sizeMap: Record<string, number> = { sm: 14, md: 16, lg: 18 };
    return { color: colorMap[variant!], fontSize: sizeMap[size!] };
  }, [variant, size, theme]);

  return { handlePress, isDisabled, containerStyle, labelStyle };
}
```

### 4. Test Template

```typescript
// Button/Button.test.tsx
import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import Button from './Button';

describe('Button', () => {
  const defaultProps = { label: 'Press me', onPress: jest.fn() };

  beforeEach(() => jest.clearAllMocks());

  it('renders label text', () => {
    const { getByText } = render(<Button {...defaultProps} />);
    expect(getByText('Press me')).toBeTruthy();
  });

  it('calls onPress when pressed', () => {
    const { getByRole } = render(<Button {...defaultProps} />);
    fireEvent.press(getByRole('button'));
    expect(defaultProps.onPress).toHaveBeenCalledTimes(1);
  });

  it('does not call onPress when disabled', () => {
    const { getByRole } = render(<Button {...defaultProps} disabled />);
    fireEvent.press(getByRole('button'));
    expect(defaultProps.onPress).not.toHaveBeenCalled();
  });

  it('shows loading indicator when loading', () => {
    const { queryByText, getByRole } = render(<Button {...defaultProps} loading />);
    expect(queryByText('Press me')).toBeNull();
    expect(getByRole('button').props.accessibilityState.busy).toBe(true);
  });

  it('has correct accessibility attributes', () => {
    const { getByRole } = render(<Button {...defaultProps} />);
    const btn = getByRole('button');
    expect(btn.props.accessibilityLabel).toBe('Press me');
  });

  it.each(['primary', 'secondary', 'ghost'] as const)('renders %s variant', (variant) => {
    const { getByRole } = render(<Button {...defaultProps} variant={variant} />);
    expect(getByRole('button')).toBeTruthy();
  });
});
```

### 5. Story Template

```typescript
// Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react-native';
import Button from './Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  argTypes: {
    variant: { control: 'select', options: ['primary', 'secondary', 'ghost'] },
    size: { control: 'select', options: ['sm', 'md', 'lg'] },
    disabled: { control: 'boolean' },
    loading: { control: 'boolean' },
  },
};
export default meta;

type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: { label: 'Primary Button', variant: 'primary', onPress: () => {} },
};
export const Secondary: Story = {
  args: { label: 'Secondary', variant: 'secondary', onPress: () => {} },
};
export const Ghost: Story = {
  args: { label: 'Ghost', variant: 'ghost', onPress: () => {} },
};
export const Loading: Story = {
  args: { label: 'Loading', loading: true, onPress: () => {} },
};
export const Disabled: Story = {
  args: { label: 'Disabled', disabled: true, onPress: () => {} },
};
```

### 6. Flutter Widget Template

```dart
// lib/widgets/button/button.dart
import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, ghost }
enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool disabled;
  final bool loading;
  final VoidCallback onPressed;
  final String? semanticsLabel;

  const AppButton({
    super.key,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.disabled = false,
    this.loading = false,
    required this.onPressed,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      enabled: !disabled && !loading,
      child: SizedBox(
        height: _height,
        child: ElevatedButton(
          onPressed: (disabled || loading) ? null : onPressed,
          style: _buttonStyle(theme),
          child: loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label, style: TextStyle(fontSize: _fontSize)),
        ),
      ),
    );
  }

  double get _height => switch (size) { ButtonSize.sm => 36, ButtonSize.md => 48, ButtonSize.lg => 56 };
  double get _fontSize => switch (size) { ButtonSize.sm => 14, ButtonSize.md => 16, ButtonSize.lg => 18 };

  ButtonStyle _buttonStyle(ThemeData theme) => switch (variant) {
    ButtonVariant.primary => ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
    ButtonVariant.secondary => OutlinedButton.styleFrom().copyWith(),
    ButtonVariant.ghost => TextButton.styleFrom().copyWith(),
  };
}
```

## Why This Works

The four-file pattern (component, hook, test, story) enforces separation of concerns at the file system level. Logic lives in the hook so the component file is purely declarative. Memoization and typed props prevent unnecessary re-renders. Generating all four files simultaneously means tests and stories are never an afterthought -- they ship with the component from day one.

## Edge Cases

- **Compound components** (e.g., Accordion with AccordionItem): scaffold a shared context and child components within the same directory
- **Platform-specific components**: generate `.ios.tsx` and `.android.tsx` files when behavior diverges significantly
- **Controlled vs uncontrolled**: when a component can be either, the hook should accept optional `value`/`onChange` and fall back to internal state
- **Forwarded refs**: wrap the component in `React.forwardRef` when consumers need imperative handles (e.g., TextInput focus)
- **Animation-heavy components**: co-locate a `useAnimations.ts` hook alongside the main hook

## Verification

1. **TypeScript strict mode**: component compiles with `strict: true` and no `any` types
2. **No inline styles**: grep for `style={{` in the component file; should return zero matches
3. **Accessibility**: every interactive element has `accessibilityRole`, `accessibilityLabel`, and appropriate `accessibilityState`
4. **Test coverage**: test file covers render, interaction, disabled state, loading state, and accessibility attributes
5. **Story coverage**: at least one story per variant and one per state (loading, disabled)

## References

- React Native Testing Library: https://callstack.github.io/react-native-testing-library/
- Storybook for React Native: https://storybook.js.org/tutorials/intro-to-storybook/react-native/en/get-started/
- Flutter Widget Testing: https://docs.flutter.dev/cookbook/testing/widget/introduction
- WCAG Touch Target Size: https://www.w3.org/WAI/WCAG21/Understanding/target-size.html
