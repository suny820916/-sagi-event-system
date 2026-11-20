# Release Policy

## Channels

### Dev
Active development. Breaking changes allowed.

### Beta
Feature-complete candidate. Used for controlled tests only.

### Stable
Certified for live match use. No unverified feature lands directly here.

## Promotion gates

Dev -> Beta requires:

- automated smoke tests pass
- match state persistence test pass
- phone / desktop synchronization pass
- vMix disconnected-mode pass
- refresh / reconnect recovery pass
- no known score corruption defect

Beta -> Stable additionally requires:

- long-duration soak test
- full match simulation
- penalty shootout simulation
- replay workflow simulation
- crash recovery test
- rollback test
- clean install / upgrade test
- Chinese UI verification

## Stable protection

Commercial Stable must never be used as the development branch.

If a Stable defect affects live scoring, clock, event state or vMix safety, issue a hotfix branch and preserve rollback capability.

## Versioning

Commercial releases use semantic product versions:

- 1.0.0
- 1.0.1 hotfix
- 1.1.0 feature release

Internal SAGI V4.x development history remains traceable but is not exposed as the customer product version.
