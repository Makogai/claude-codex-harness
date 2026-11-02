# codex-harness icon

A bold orange terminal chevron flows directly into a cyan document outline, capturing the handoff from a coding agent to a finished markdown asset; the heavy strokes, simple fold, and short content lines remain clear at plugin-listing sizes.

## Palette

- `#0B1530` — deep navy background
- `#FF9F43` — warm orange terminal prompt
- `#25D0C8` — teal handoff transition
- `#55E6E1` — cyan document and markdown lines

## SVG

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="handoff" x1="365" y1="512" x2="490" y2="512" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FF9F43"/>
      <stop offset="1" stop-color="#25D0C8"/>
    </linearGradient>
  </defs>

  <rect width="1024" height="1024" rx="220" fill="#0B1530"/>

  <polyline
    points="210,330 365,512 210,694"
    fill="none"
    stroke="#FF9F43"
    stroke-width="72"
    stroke-linecap="round"
    stroke-linejoin="round"
  />

  <line
    x1="365"
    y1="512"
    x2="490"
    y2="512"
    stroke="url(#handoff)"
    stroke-width="64"
    stroke-linecap="round"
  />

  <path
    d="M458 456 V272 H690 L820 402 V752 Q820 784 788 784 H490 Q458 784 458 752 V568"
    fill="none"
    stroke="#55E6E1"
    stroke-width="64"
    stroke-linecap="round"
    stroke-linejoin="round"
  />

  <polyline
    points="690,272 690,402 820,402"
    fill="none"
    stroke="#55E6E1"
    stroke-width="64"
    stroke-linecap="round"
    stroke-linejoin="round"
  />

  <line x1="568" y1="512" x2="716" y2="512" stroke="#55E6E1" stroke-width="56" stroke-linecap="round"/>
  <line x1="568" y1="616" x2="724" y2="616" stroke="#55E6E1" stroke-width="56" stroke-linecap="round"/>
  <line x1="568" y1="700" x2="668" y2="700" stroke="#55E6E1" stroke-width="56" stroke-linecap="round"/>
</svg>
```
