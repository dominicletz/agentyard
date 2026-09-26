# AgentYard style guide

AgentYard is a calm, compact control plane for people supervising coding
agents. The interface uses a light work surface with an indigo action color
and a deep slate navigation rail. Prefer small, deliberate changes that keep
the product legible at a glance.

## Design tokens

The canonical tokens live in `priv/static/css/app.css`. Use the variables
below instead of introducing one-off colors:

| Token | Value | Use |
| --- | --- | --- |
| `--bg` | `#f6f7f9` | Page background |
| `--surface` | `#fff` | Cards, panels, and controls |
| `--surface-2` | `#f0f2f5` | Subtle fills and secondary states |
| `--border` | `#e5e7eb` | Dividers and control borders |
| `--text` | `#111827` | Primary text |
| `--muted` | `#6b7280` | Supporting text |
| `--accent` / `--accent-2` | `#4f46e5` / `#6366f1` | Primary actions and active states |
| `--ok` / `--warn` / `--err` | `#059669` / `#d97706` / `#dc2626` | Status feedback |
| `--sidebar` | `#0f172a` | App navigation |
| `--run` | `#2563eb` | Running-state emphasis |
| `--radius` | `10px` | Standard cards and panels |
| `--shadow` | `0 1px 2px rgba(15,23,42,.06), 0 1px 3px rgba(15,23,42,.04)` | Elevation |

Do not use color alone to communicate a status; pair it with a label or
icon. `priv/static/css/polish.css` contains small cross-cutting refinements
such as focus rings and the auth divider.

## Type, space, and shape

- Use the system sans stack in `--font` for interface text and `--mono` for
  identifiers, branches, timestamps, and event payloads.
- The default text size is 14px with a 1.45 line height. Page titles are
  compact and use a slight negative letter spacing; labels and eyebrows are
  small and semibold.
- Use the existing 8px control radius, 10px panel radius, and 999px pill
  radius. Common spacing steps are 4px, 8px, 12px, 16px, and 24px.
- Keep borders quiet and shadows subtle. Add density with spacing and grouping,
  not heavy decoration.

## Brand mark

The square mark is `priv/static/images/agentyard-mark.svg`. It represents a
branching control path: agents enter from the two upper nodes and converge on
the yard below. Use the SVG rather than recreating the old `AY` text mark.

- Render it at 28px in the sidebar and 32px on auth pages.
- It is designed to remain recognizable at favicon and 16px sizes and uses
  indigo plus white/slate-friendly contrast.
- Keep the visible wordmark `AgentYard` next to it. Logo images use
  `alt="AgentYard"`; brand links should retain an `AgentYard` accessible name.
- The root layout links the same mark as the SVG favicon. Keep brand assets in
  `priv/static/images/`, which is already an allowed static path.

## Buttons and forms

Use `.button` for all actions:

- `.button-primary` is for the main action on a page and uses `--accent`.
- `.button-secondary` is for a lower-emphasis action with a surface fill.
- `.button-danger` is reserved for destructive actions.

Buttons should have a clear verb, remain keyboard-focusable, and not be
replaced with unlabelled icon-only controls. Forms use stacked labels,
8px-radius inputs, visible required fields, and the existing indigo focus
ring. Use `.stack-form`, `.form-grid`, and `.check-row` before adding a new
layout pattern. Browser forms that post to Phoenix include the hidden CSRF
field.

## Auth page

Login, registration, and magic-link confirmation use the shared centered
`.auth-page` / `.auth-card` treatment: a `410px` maximum card width, a
14px card radius, a concise title, muted explanatory copy, and one primary
path. Alternate sign-in options are separated with `.auth-divider`; errors
use `.flash flash-error`. Keep the page usable on narrow screens by relying on
the card's `calc(100% - 32px)` width.

## App shell and sidebar

The authenticated shell is a 232px dark slate sidebar beside the flexible
content area. The sidebar contains the mark and wordmark, a small uppercase
workspace label, grouped navigation, and a footer team card. Active and hover
states use a translucent white fill and white text; keep navigation labels
visible rather than relying on symbols alone.

The main area uses a 52px white top bar, a subtle bottom border, and page
content with a maximum width. Panels, metric cards, tables, and forms should
share the surface, border, radius, and shadow tokens so the shell feels like
one system.
