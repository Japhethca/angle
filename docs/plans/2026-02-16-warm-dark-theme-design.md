# Warm Dark Theme Background Design

## Problem

The current dark mode uses pure neutral grays (`#0A0A0A` base) that feel too dark/harsh for an auction marketplace. The platform needs a warmer, more inviting dark theme that connects to the `#F56600` orange brand identity.

## Approach: Warm-Tinted Neutrals

Add a subtle amber/brown undertone (oklch hue 60, chroma 0.005) to all dark surfaces. Barely perceptible in isolation but creates cohesive warmth across the UI. Also lifts the base from near-black to a softer dark.

## Token Changes

### Semantic surface tokens (`.dark`)

| Token | Current | New |
|---|---|---|
| `--surface` | `#0A0A0A` | `#141210` |
| `--surface-secondary` | `#141414` | `#1C1916` |
| `--surface-muted` | `#1A1A1A` | `#23201C` |
| `--surface-inset` | `#262626` | `#2E2A25` |
| `--surface-emphasis` | `#404040` | `#4A4540` |

### Semantic border tokens (`.dark`)

| Token | Current | New |
|---|---|---|
| `--border-subtle` | `#262626` | `#2E2A25` |
| `--border-strong` | `#404040` | `#4A4540` |

### shadcn/ui tokens (`.dark`)

Add `0.005` chroma at hue `60` to all surface-like oklch values:

| Token | Current | New |
|---|---|---|
| `--background` | `oklch(0.145 0 0)` | `oklch(0.145 0.005 60)` |
| `--card` | `oklch(0.205 0 0)` | `oklch(0.205 0.005 60)` |
| `--popover` | `oklch(0.269 0 0)` | `oklch(0.269 0.005 60)` |
| `--muted` | `oklch(0.269 0 0)` | `oklch(0.269 0.005 60)` |
| `--accent` | `oklch(0.371 0 0)` | `oklch(0.371 0.005 60)` |
| `--secondary` | `oklch(0.269 0 0)` | `oklch(0.269 0.005 60)` |
| `--sidebar` | `oklch(0.205 0 0)` | `oklch(0.205 0.005 60)` |
| `--sidebar-accent` | `oklch(0.269 0 0)` | `oklch(0.269 0.005 60)` |

### Unchanged

- Content/text tokens (no warming needed)
- Foreground tokens
- Feedback tokens (success, warning, error, info)
- All light mode (`:root`) tokens

## File

Single file change: `assets/css/app.css` — `.dark` block only.
