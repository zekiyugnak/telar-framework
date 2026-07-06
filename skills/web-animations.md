---
id: web-animations
category: skill
impact: MEDIUM
impactDescription: "Eliminates jank from layout-animating properties and ensures reduced-motion compliance while unlocking fluid, accessible 60fps interactions"
tags: [animations, framer-motion, css-transitions, view-transitions, reduced-motion, web]
capabilities:
  - GPU-accelerated CSS transitions and keyframes using compositor-only properties
  - Framer Motion variants, layout animations, and AnimatePresence for enter/exit
  - View Transitions API for route and state change crossfades
  - Scroll-driven animations with animation-timeline (scroll() and view())
  - Spring vs tween selection and stagger orchestration
  - prefers-reduced-motion enforcement at every layer
  - will-change discipline to avoid memory and compositing overhead
useWhen:
  - Adding enter/exit transitions to a modal, toast, or popover
  - Animating list items when they reorder or are removed
  - Wiring a route transition that needs to feel like a native navigation
  - Deciding between CSS transitions, CSS keyframes, and Framer Motion for a given case
  - A scroll-linked animation (progress indicator, parallax header, reveal-on-scroll)
  - Diagnosing animation jank or unexpected layout reflows
---

# GPU-Accelerated Web Animations, Framer Motion, and prefers-reduced-motion

Web animations fall into three layers: CSS (fastest, zero JS overhead), Framer Motion (richer orchestration over the same compositor layer), and the View Transitions API (route/state crossfades managed by the browser). Picking the wrong layer—or animating the wrong property—is the root cause of nearly every animation jank complaint. This skill covers which layer to reach for, how to wire `prefers-reduced-motion` at each layer, and the anti-patterns that push work off the GPU.

## Problem

Animating layout properties causes the browser to run style, layout, and paint on every frame. Even one animated `width` or `height` inside a complex component tree can drop a 60fps interaction to sub-30fps on mid-range hardware.

```tsx
// BAD: animating layout properties triggers full pipeline on every frame
<div
  style={{
    transition: 'width 300ms, height 300ms, top 300ms',
    width: isOpen ? 400 : 0,
    height: isOpen ? 300 : 0,
  }}
/>

// BAD: entering elements appear instantly with no reduced-motion fallback
function Toast({ message }: { message: string }) {
  return <div className="toast">{message}</div>
}
```

```css
/* BAD: animating margin instead of transform — triggers layout + paint */
.card:hover {
  margin-top: -4px;
  box-shadow: 0 8px 24px rgba(0,0,0,.2);
}
```

## Solution

### CSS-first: compositor-only transitions

The only properties the browser can animate entirely on the GPU compositor thread are `transform`, `opacity`, and `filter`. Everything else triggers at least a paint; `width`/`height`/`top`/`left`/`margin` trigger a full layout pass.

```css
/* GOOD: hover lift using transform only — stays on compositor */
.card {
  transition: transform 200ms ease-out, box-shadow 200ms ease-out;
  will-change: transform; /* hint compositor before the interaction starts */
}
.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgb(0 0 0 / 0.15);
}

/* GOOD: keyframe entrance — opacity + transform only */
@keyframes slideInUp {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}
.toast {
  animation: slideInUp 250ms ease-out both;
}

/* GOOD: global reduced-motion kill-switch */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Framer Motion: variants, AnimatePresence, layout animations

Use Framer Motion when you need stagger, orchestration, gesture-driven animations, or `AnimatePresence` (enter/exit for unmounting components). It uses the Web Animations API under the hood and stays compositor-safe as long as you animate `x`/`y`/`scale`/`opacity`—never `width`/`height`/`left`/`top`.

```tsx
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion'

const itemVariants = {
  hidden:  { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0 },
  exit:    { opacity: 0, y: -8 },
}

const listVariants = {
  visible: {
    transition: { staggerChildren: 0.06, delayChildren: 0.1 },
  },
}

// GOOD: staggered list with enter/exit + reduced-motion guard
function NotificationList({ items }: { items: string[] }) {
  const reduced = useReducedMotion()

  return (
    <motion.ul variants={listVariants} initial="hidden" animate="visible">
      <AnimatePresence>
        {items.map((item) => (
          <motion.li
            key={item}
            variants={reduced ? undefined : itemVariants}
            exit={reduced ? { opacity: 0 } : itemVariants.exit}
            transition={{ type: 'spring', stiffness: 300, damping: 30 }}
            layout // reflows list positions without animating width/height
          >
            {item}
          </motion.li>
        ))}
      </AnimatePresence>
    </motion.ul>
  )
}
```

### View Transitions API for route changes

The View Transitions API crossfades (or morphs) between two DOM states with a single `document.startViewTransition()` call. It is the right tool for page/route transitions in SPAs—no Framer Motion needed at the routing layer.

```tsx
// src/router/transitions.ts
export function navigateWithTransition(navigate: () => void) {
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (!document.startViewTransition || reduced) {
    navigate()
    return
  }
  document.startViewTransition(navigate)
}
```

```css
/* Customize the crossfade (browser default: 250ms opacity fade) */
::view-transition-old(root) { animation: 200ms ease-out both fade-out; }
::view-transition-new(root) { animation: 200ms ease-in  both fade-in;  }

/* Named transition for a shared element (hero image morph) */
.product-thumbnail { view-transition-name: product-hero; }
```

### Scroll-driven animations

Native scroll-linked progress via `animation-timeline` runs entirely on the compositor—no `scroll` event listener, no `requestAnimationFrame` loop.

```css
/* GOOD: scroll-progress bar — zero JS, fully compositor */
@keyframes progress {
  from { transform: scaleX(0); }
  to   { transform: scaleX(1); }
}
.progress-bar {
  transform-origin: left;
  animation: progress linear both;
  animation-timeline: scroll(root block);
}

/* GOOD: reveal-on-scroll with view() timeline */
.reveal-card {
  animation: slideInUp linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 30%;
}

@media (prefers-reduced-motion: reduce) {
  .reveal-card { animation: none; opacity: 1; }
}
```

## Which Tool When

| Scenario | Reach for |
|---|---|
| Simple hover/focus state change | CSS `transition` on `transform`/`opacity` |
| Repeating decorative animation | CSS `@keyframes` |
| Enter/exit of a mounted component | Framer Motion `AnimatePresence` |
| List reorder / shared-element position change | Framer Motion `layout` prop |
| Staggered list entrance | Framer Motion `staggerChildren` variant |
| Drag/swipe gesture animation | Framer Motion `drag` + `useMotionValue` |
| Route/page transition crossfade | View Transitions API |
| Scroll-progress bar or reveal-on-scroll | CSS `animation-timeline: scroll()` / `view()` |

## Anti-Patterns

- **Animating `width`, `height`, `top`, `left`, `margin`, `padding`**: triggers style + layout + paint on every frame. Use `transform: scale()` or `transform: translate()` instead—they stay on the compositor.
- **Putting `will-change` on every element**: promotes every element to its own GPU layer, exploding VRAM and actually slowing compositing. Add it only immediately before an animation starts (e.g., on `:hover` rule) and never globally.
- **Ignoring `prefers-reduced-motion`**: vestibular disorder sufferers can experience nausea from screen motion. Every animation must degrade gracefully—either disable entirely or substitute a simple opacity fade.
- **AnimatePresence without a stable `key` on exiting children**: without a stable key, Framer Motion cannot track which element is leaving and will skip the exit animation silently.
- **Mixing Framer Motion `x`/`y` with CSS `left`/`top` on the same element**: both offsets apply simultaneously, producing visual doubling.

## Verification

```bash
# Chrome DevTools → Rendering panel → Frame Rendering Stats
# Green = compositor-only, yellow = paint, red = layout
npm run dev
```

- [ ] Open DevTools Performance panel, record 2s of the animation — confirm no purple (layout) bars in the flame chart.
- [ ] Enable "Emulate CSS media feature prefers-reduced-motion: reduce" in DevTools → Rendering — confirm all animations either stop or reduce to a simple opacity fade.
- [ ] Toggle list add/remove — confirm exit animations fully complete before the element leaves the DOM (AnimatePresence gate working).
- [ ] Check `chrome://gpu` GPU memory before and after `will-change` — confirm no unexpected VRAM spike.

## References

- [MDN — CSS animations](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_animations/Using_CSS_animations)
- [MDN — View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API)
- [MDN — animation-timeline: scroll()](https://developer.mozilla.org/en-US/docs/Web/CSS/animation-timeline/scroll)
- [Framer Motion — Variants](https://www.framer.com/motion/variants/)
- [Framer Motion — AnimatePresence](https://www.framer.com/motion/animate-presence/)
- [Framer Motion — useReducedMotion](https://www.framer.com/motion/use-reduced-motion/)
- [web.dev — Animations performance guide](https://web.dev/articles/animations-overview)
