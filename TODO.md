# TODO

## Angry Keystones compatibility

Angry Keystones is not a standalone Mythic+ timer provider. It modifies Blizzard's
`ScenarioObjectiveTracker.ChallengeModeBlock`, while BetterQuestList renders its own
scenario category and hides the native Objective Tracker.

- Investigate whether the original `ChallengeModeBlock`, with Angry Keystones hooks
  already applied, can be hosted safely inside the BetterQuestList Mythic+ category.
- Do not expose Angry Keystones as a separate timer source and do not recreate its UI.
- Avoid reparenting or mutating protected Blizzard state in a way that causes taint.
- Ensure the native Objective Tracker cannot appear behind BetterQuestList during
  movement, refreshes, or Edit Mode.
- Prevent duplicate scenario and Mythic+ blocks.
- Verify behavior with Angry Keystones enabled and disabled, during `/reload`, key
  start, death-count updates, timer completion, zone changes, and Edit Mode.

Done when BetterQuestList can display the standard Mythic+ scenario block with Angry
Keystones enhancements in the configured category without taint, duplicate trackers,
anchor jumps, or a separately emulated Angry Keystones timer.
