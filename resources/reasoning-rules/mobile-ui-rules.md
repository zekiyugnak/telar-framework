# Mobile UI Reasoning Rules

50 prioritized rules for mobile UI/UX decisions. Apply in order of priority.

## CRITICAL (Rules 1-12) - Must always follow

**Rule 1: Touch Target Minimum**
All interactive elements must be at minimum 44x44pt (iOS) / 48x48dp (Android). If the visual element is smaller, extend the hit area with padding.

**Rule 2: Safe Area Compliance**
All content must respect device safe areas (notch, dynamic island, home indicator, status bar). Use SafeAreaView (RN) or SafeArea (Flutter). Never place interactive elements under system UI.

**Rule 3: Accessibility Labels**
Every interactive element must have an accessibility label. Images need alt text or decorative marking. Screen readers must be able to navigate the entire app.

**Rule 4: Color Contrast**
Text must meet WCAG AA minimum: 4.5:1 for normal text, 3:1 for large text (18pt+). Non-text elements (icons, borders) must meet 3:1 ratio. Test in both light and dark mode.

**Rule 5: Loading State Feedback**
Every async operation must show loading feedback within 100ms. Use skeleton screens for content loading, spinners for actions, progress bars for uploads. Never show blank screens.

**Rule 6: Error State Visibility**
Errors must be visible, specific, and actionable. Use color + icon + text (never color alone). Position error messages near the source. Provide retry actions.

**Rule 7: Keyboard Avoidance**
Forms must remain visible and interactive when the keyboard appears. Use KeyboardAvoidingView (RN) or Scaffold resizeToAvoidBottomInset (Flutter). Test on all device sizes.

**Rule 8: Text Scaling Support**
App must remain usable at 200% text scale. No text clipping, overlapping, or horizontal scrolling. Test with iOS Dynamic Type and Android font scaling.

**Rule 9: Offline State Communication**
When offline, clearly indicate what's unavailable. Show cached content with staleness indicator. Queue actions for sync. Never silently fail.

**Rule 10: Prevent Double Submission**
Disable submit buttons during async operations. Prevent double-tap form submissions. Show loading state on the button itself.

**Rule 11: Destructive Action Confirmation**
Require confirmation for destructive actions (delete, cancel, discard). Use platform-appropriate dialogs. Make the destructive option visually distinct (red).

**Rule 12: Scroll Content Reachability**
Bottom-anchored actions (FAB, submit button) must not cover scrollable content. Add bottom padding equal to the action bar height. Content must be fully scrollable.

## HIGH (Rules 13-26) - Follow unless strong reason not to

**Rule 13: Platform Navigation Conventions**
iOS: back swipe from left edge, bottom tabs, large titles. Android: gesture/button back, bottom nav (Material 3), top app bar. Don't use hamburger menus as primary navigation.

**Rule 14: Platform Button Styles**
iOS: rounded rectangles, SF Symbols. Android: Material 3 filled/outlined/text buttons. Don't use iOS-style buttons on Android or vice versa.

**Rule 15: Responsive Layout**
Support portrait and landscape where meaningful. Use relative sizing (flex, %). Test on smallest (iPhone SE/4") and largest (tablet) supported screens.

**Rule 16: Dark Mode Support**
Support both light and dark mode. Use semantic colors (surface, onSurface) not hardcoded values. Test all screens in both modes. Respect system preference.

**Rule 17: List Performance**
Lists with 20+ items must use virtualized components (FlatList/FlashList, ListView.builder). Memoize list items. Provide key extractors.

**Rule 18: Image Optimization**
Use appropriate image sizes (don't load 4K for thumbnails). Use WebP format. Show placeholders during loading. Cache aggressively. Use progressive loading for large images.

**Rule 19: Tab Bar Icons**
Tab icons must have labels. Active/inactive states must be visually distinct. Maximum 5 tabs. Use standard platform icons where applicable.

**Rule 20: Form Input Design**
Use appropriate keyboard types (email, phone, number). Show/hide password toggle. Clear button for text fields. Auto-focus first field. Progress through fields with Next/Done buttons.

**Rule 21: Pull-to-Refresh**
Scrollable content that can be stale should support pull-to-refresh. Use platform-standard refresh indicator. Show last-updated timestamp if relevant.

**Rule 22: Empty States**
Empty lists/screens must show helpful empty states. Include illustration, message, and action button. "No results found" should suggest broadening search.

**Rule 23: Search UX**
Search should be instant (debounced, not on submit). Show recent searches. Support search suggestions. Clear button visible. Cancel/dismiss accessible.

**Rule 24: Bottom Sheet Usage**
Use bottom sheets for contextual actions and forms on mobile. Partial sheets for options (3-5 items). Full sheets for complex forms. Swipe to dismiss.

**Rule 25: Navigation Depth Indicator**
Users should always know where they are. Show back button with previous screen title. Use breadcrumbs for deep navigation. Avoid nesting more than 4 levels.

**Rule 26: Consistent Spacing System**
Use 4pt/8pt spacing grid. Define spacing tokens (xs: 4, sm: 8, md: 16, lg: 24, xl: 32). Apply consistently across all screens.

## MEDIUM (Rules 27-40) - Recommended for polish

**Rule 27: Animation Duration**
Micro-interactions: 100-200ms. Page transitions: 200-350ms. Complex animations: 300-500ms. Use ease-in-out curves for most animations. Match platform defaults.

**Rule 28: Animation Purpose**
Every animation must serve a purpose: guide attention, show relationship, provide feedback, or reduce perceived wait time. Remove purely decorative animations.

**Rule 29: Haptic Feedback**
Use haptics for: toggle switches (light impact), destructive actions (notification warning), success (notification success), selection changes (selection). Don't overuse.

**Rule 30: Micro-interaction Feedback**
Button press: subtle scale (0.97) or opacity (0.7). Toggle: smooth transition. Like button: satisfying animation. Save: checkmark confirmation.

**Rule 31: Skeleton Screens**
Use skeleton screens instead of spinners for content loading. Match the layout of actual content. Animate with subtle shimmer. Show within 100ms.

**Rule 32: Card Design**
Cards should have consistent padding (16pt), subtle shadow (elevation 2-4), rounded corners (8-12pt). Don't nest cards inside cards.

**Rule 33: Typography Hierarchy**
Use maximum 3 font sizes per screen. Clear hierarchy: title, body, caption. Use weight for emphasis before size. Maintain consistent line heights.

**Rule 34: Icon Consistency**
Use one icon library throughout the app. Consistent size (24dp for actions, 20dp for inline). Consistent stroke width. Don't mix filled and outlined in same context.

**Rule 35: Gradient Usage**
Use gradients sparingly. Subtle backgrounds only. Never on text (accessibility). Ensure contrast with overlaid content. Match brand colors.

**Rule 36: Status Bar Style**
Match status bar style to screen background. Dark content on light backgrounds, light content on dark backgrounds. Handle per-screen if backgrounds differ.

**Rule 37: Snackbar/Toast**
Use for non-critical, temporary feedback. Show at bottom (above tab bar). Auto-dismiss after 3-4 seconds. Include undo action for reversible operations.

**Rule 38: Date/Time Input**
Use platform date/time pickers (iOS wheel, Android Material picker). Don't make users type dates. Default to sensible values. Support relative display ("2 hours ago").

**Rule 39: Number Formatting**
Format large numbers (1,234 not 1234). Currency with proper locale symbols. Percentages with appropriate precision. Use abbreviated forms (1.2K, 3.5M) for display.

**Rule 40: Placeholder Text**
Placeholder text is not a label. Always have a visible label above or beside the field. Placeholder for format hints only ("MM/DD/YYYY"). Gray but readable contrast.

## LOW (Rules 41-50) - Nice-to-have polish

**Rule 41: Advanced Gestures**
Support pinch-to-zoom for images. Long press for context menus. Swipe actions on list items (with button alternatives).

**Rule 42: Custom Page Transitions**
Match platform defaults first. Custom transitions for special flows (onboarding, media viewer). Shared element transitions for visual continuity.

**Rule 43: Parallax Effects**
Subtle only. Reduce or disable when `prefers-reduced-motion`. Header parallax on scroll for visual depth. Don't use for critical content.

**Rule 44: Blur Effects**
Use for modal backgrounds and navigation bars. Platform blur (iOS UIBlurEffect, Android RenderScript). Fallback to semi-transparent overlay on low-end devices.

**Rule 45: Scroll-Linked Animations**
Header collapse on scroll. Fab hide on scroll down, show on scroll up. Tab bar hide on scroll in content-heavy screens. Keep smooth (native driver).

**Rule 46: Custom Refresh Indicators**
Brand-specific pull-to-refresh animations. Keep under 1 second total animation. Fall back to platform default if complex animation causes jank.

**Rule 47: Onboarding Flow**
Maximum 3-4 screens. Skip button always visible. Progress dots. Swipeable. Don't block app access for too long. Store completion state.

**Rule 48: Splash Screen Branding**
Splash screen matches app icon. Transition smoothly to first screen. Keep under 2 seconds. Use for initialization, not marketing.

**Rule 49: Widget/Watch Companion**
iOS widgets: use SwiftUI. Android widgets: use Glance or RemoteViews. Show key data only. Deep link into app.

**Rule 50: Easter Eggs**
Hidden features for delight (shake for feedback, pull past threshold for fun animation). Never required for functionality. Don't affect performance.
