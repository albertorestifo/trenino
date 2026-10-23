# Release readiness improvements

The user authorized implementing the findings from the October 23 review, using
subagents, without further design/permission interruptions. Preserve Trenino's
existing Phoenix/LiveView architecture and PRODUCT.md/DESIGN.md visual language.

## Outcomes
- Lever writes never spin while disconnected and recover after task failure.
- Display-only configurations deploy; display values recover after reconnect;
  invalid format strings cannot crash preview or runtime.
- Display settings survive validation and are accessible by keyboard and labels.
- Train identifiers use available width, explain prefix matching, and offer the
  current simulator identifier when available.
- Display prerequisites are visible and actionable before entering a wizard.
- Joystick starts with assigned mappings and capacity summaries, supports offline
  configuration explicitly, and gives honest disconnected preview guidance.
- Small windows retain navigation and accessible binding actions.
- Display setup reveals advanced options progressively; empty sections are compact.
- Settings offers accurate platform instructions and meaningful connection feedback.
- Prepare consistent 0.8.0 metadata and documentation; triage dependency advisories.

## Approach
Use focused fixes and refinements to existing components. A visual rewrite would
add release risk without addressing the reported failures; cosmetic-only fixes
would leave broken behavior. Backend failure paths get regression tests first.
UI behavior gets LiveView coverage and screenshot/keyboard checks. Keep custom
formatting and full joystick capacity available through progressive disclosure.

## Constraints
No publishing, tagging, driver installation, destructive data changes, or remote
push. Preserve existing profile/configuration data and compatibility except the
already documented identifier API change. Real Windows/hardware verification is
reported as unperformed when this host cannot provide it. New screens must use
plain language and existing components. No decorative assets are needed.
