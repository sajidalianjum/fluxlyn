# Design System Documentation

## Overview

Fluxlyn uses **Material 3** design system with support for both **Light and Dark themes**.

---

## Theme Support

**⚠️ CRITICAL: Always implement theme-aware UI components**

The app supports both light and dark themes. Never hardcode colors that only work in one theme.

### Common Mistakes to Avoid

```dart
// ❌ WRONG - Hardcoded dark theme colors
backgroundColor: const Color(0xFF1E293B),  // Only works in dark mode
color: Colors.white,  // Poor contrast in light mode

// ❌ WRONG - Using Colors.red without theme consideration
color: Colors.red,  // Use theme.colorScheme.error instead
```

```dart
// ✅ CORRECT - Theme-aware colors
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

backgroundColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
color: theme.colorScheme.onSurface,
color: isDark ? Colors.red : theme.colorScheme.error,
```

---

## Theme-Aware Pattern

Always use this pattern for any widget that has custom colors:

```dart
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

// Backgrounds
backgroundColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,

// Text
color: theme.colorScheme.onSurface,

// Error states
color: isDark ? Colors.red : theme.colorScheme.error,

// Secondary text
color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
```

---

## Color Scheme

### Dark Theme (Default)

```dart
Background:    0xFF0F172A (Slate 900)
Card:          0xFF1E293B (Slate 800)
Primary:       0xFF3B82F6 (Blue 500)
Text Primary:  Colors.white
Text Secondary: Colors.grey
Error:         Colors.red
```

### Light Theme

```dart
Background:    theme.colorScheme.surface
Card:          theme.colorScheme.surfaceContainerHighest
Primary:       theme.colorScheme.primary
Text Primary:  theme.colorScheme.onSurface
Text Secondary: theme.colorScheme.onSurface.withValues(alpha: 0.6)
Error:         theme.colorScheme.error
```

---

## UI Components

### SnackBar

```dart
void _showErrorSnackBar(BuildContext context, String error) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor:
          isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? Colors.red : theme.colorScheme.error,
          width: 1,
        ),
      ),
      content: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red : theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}
```

### Dialogs

```dart
class MyDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor:
          isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: // ... dialog content
      ),
    );
  }
}
```

### Cards

```dart
Card(
  color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
  child: // ... card content
)
```

---

## Checklist

When creating any UI component with custom colors:

- [ ] Import and use `Theme.of(context)`
- [ ] Check `theme.brightness` for dark/light mode
- [ ] Use `theme.colorScheme.surface` for light theme backgrounds
- [ ] Use `theme.colorScheme.onSurface` for text
- [ ] Use `theme.colorScheme.error` for errors in light theme
- [ ] Test in both light and dark modes

---

## Last Updated

2026-04-29 - Added theme-aware guidelines for light/dark mode support
