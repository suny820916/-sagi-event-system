# 战术动画工厂 / TACTICAL ANIMATION FACTORY

## Input
User provides a tactical-animation prompt and, when available, a reference animation sample.

## Duration authority
Animation duration is determined by the current Production Master prompt, never by the reference sample.

Rules:
- If the prompt specifies a fixed duration, use that duration exactly.
- If the prompt specifies section timestamps, those timestamps define the production timeline.
- If the prompt does not specify a duration, derive duration from the tactical content, causal sequence and reading needs.
- Never stretch or compress the new animation simply to match the reference sample's runtime.
- Never inherit the reference video's total duration unless the user explicitly says to match it.
- The reference sample is used for visual language, camera grammar, composition, scale, rhythm, hierarchy and tactical readability — not as a duration template.

Example:
A 71-second reference sample can be used to direct a 35-second, 50-second, 70-second or 120-second tactical animation if the Production Master calls for that duration.

## Production flow
1. Treat the newest user prompt as the current Production Master.
2. Resolve the production duration from the Production Master before building the timeline.
3. Compile it into executable tactical events, camera logic, visual hierarchy, graphics timing, and hard acceptance constraints.
4. Render the full animation at the Production Master duration.
5. Read the actual Actions result, artifact, execution report, key frames, and full video.
6. Reopen the user's exact reference animation sample whenever comparison is required.
7. Compare the rendered output against the exact sample without forcing runtime equality.
8. If similarity is below 99%, identify only real visible/directorial gaps, create the next version, and render again.
9. Preserve every already-passed element. Never rewrite locked tactical semantics just to create a new version.
10. Continue iterating until the 99% target is reached or a genuine user-decision blocker exists.

## 99% acceptance dimensions
- overall composition
- pitch scale and floating-board placement
- camera height, depth and oblique angle
- longitudinal vs lateral camera language
- camera timing and transition timing
- tactical readability
- FOCAL / SUPPORT / CONTEXT hierarchy
- player scale and body readability
- ball readability
- pass / run / shot timing
- tactical graphics timing and restraint
- tactical reading holds
- transition rhythm
- attack / defence completeness
- text/title compliance
- every hard constraint in the current Production Master

## Similarity interpretation
The 99% target refers to visual and directorial language, not identical runtime or identical football content.

Do not penalize a production for having a different total duration when that duration follows the Production Master.

Compare like-for-like tactical moments and director decisions rather than matching timestamps one-to-one across videos with different runtimes.

## Stop rule
A green GitHub Action is NOT completion.
valid=true is NOT completion.
0 errors / 0 warnings is NOT completion.
A higher version number is NOT completion.
Matching the reference runtime is NOT completion.

The factory stops only when:
- the actual rendered video reaches 99% against the user's exact reference sample under the defined comparison dimensions while respecting the Production Master's own duration, or
- there is a genuine blocker that requires a user decision.

Otherwise: continue upgrading automatically.
