# 战术动画工厂 / TACTICAL ANIMATION FACTORY

## Input
User provides a tactical-animation prompt and, when available, a reference animation sample.

## Production flow
1. Treat the newest user prompt as the current Production Master.
2. Compile it into executable tactical events, camera logic, visual hierarchy, graphics timing, and hard acceptance constraints.
3. Render the full animation.
4. Read the actual Actions result, artifact, execution report, key frames, and full video.
5. Reopen the user's exact reference animation sample whenever comparison is required.
6. Compare the rendered output against the exact sample.
7. If similarity is below 99%, identify only real visible/directorial gaps, create the next version, and render again.
8. Preserve every already-passed element. Never rewrite locked tactical semantics just to create a new version.
9. Continue iterating until the 99% target is reached or a genuine user-decision blocker exists.

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

## Stop rule
A green GitHub Action is NOT completion.
valid=true is NOT completion.
0 errors / 0 warnings is NOT completion.
A higher version number is NOT completion.

The factory stops only when:
- the actual rendered video reaches 99% against the user's exact reference sample under the defined comparison dimensions, or
- there is a genuine blocker that requires a user decision.

Otherwise: continue upgrading automatically.
