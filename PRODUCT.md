# Product

## Register

product

## Users

Hardware makers comfortable with electronics and Arduino but not software development. They're building custom train cockpits: physical throttle levers, brake handles, switches, and gauges wired to real hardware. When the app is open, they're typically at a desk with a half-assembled rig, possibly cross-referencing wiring diagrams or watching a tutorial. They can solder confidently but don't want to touch a terminal. The app must feel immediately legible and guide them through complex processes without assuming software literacy.

## Product Purpose

Trenino bridges custom Arduino hardware to Train Sim World. It handles the hard parts: flashing firmware, guiding calibration, auto-detecting the active train, mapping inputs to simulator controls, and running Lua scripts for advanced behavior. The goal is that a maker with a freshly-built lever panel can go from "hardware connected" to "driving" in a single session, with no code required.

## Brand Personality

Approachable, clear, purposeful. The tool should feel like a knowledgeable friend who speaks plainly, not a product trying to impress. Confidence without jargon.

## Anti-references

- **Arduino IDE** — cluttered, text-heavy, intimidating to non-developers. Avoid information overload and raw technical output in primary flows.
- **SCADA / industrial HMIs** — functional but cold, dense with data, no hierarchy. Avoid dashboard-for-dashboard's-sake layouts.
- **Gamer RGB aesthetic** — neon accents, gradient overload, synthetic dark mode. The dark theme should be calm and purposeful, not a gaming rig screensaver.
- **Overcrowded config panels** — settings exposed all at once. Prefer progressive disclosure and wizards over walls of options.

## Design Principles

1. **Legibility first** — every screen should be instantly scannable by someone who is anxious about breaking their hardware. If it takes effort to find the next step, simplify.
2. **Confidence through clarity** — use plain language, obvious affordances, and unambiguous state. Never leave the user wondering if something worked.
3. **Earn complexity gradually** — surface the simple path first, reveal advanced options only when needed. Wizards before forms.
4. **Hardware-aware context** — the user is not just clicking through software; they're holding a screwdriver. Large tap targets, strong contrast, and forgiving interactions matter.
5. **Calm over clever** — restraint over decoration. Every visual element should reduce cognitive load, not add to it.

## Accessibility & Inclusion

WCAG AA minimum. High contrast is a first-class requirement, not an afterthought. Usability comes before aesthetics. Support reduced motion where animations are non-essential. Users may be colorblind; never rely on color alone to convey state.
