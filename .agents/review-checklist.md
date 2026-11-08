# Review checklist: what not to forget

Use this when implementing or reviewing UI changes. These are checks to perform, not a list of current bugs or a prescribed architecture.

## Navigation

- [ ] Links push values compatible with their navigation stack's path and registered destinations.
- [ ] Back, Finish, section changes, and dismissal leave the feature in a defined state, including while work is pending.

## Async work and ownership

- [ ] Each operation has an explicit lifetime policy: who owns it, whether it survives navigation, and where its result goes.
- [ ] Leaving during save, retry, or finish cannot hide an unsaved answer or its recovery action.
- [ ] Late completions cannot dismiss an unrelated screen or update obsolete UI. Cancellation is not assumed to undo a committed write.

## Failure and recovery

- [ ] Loading, empty content, and failed loading are distinct states.
- [ ] Recoverable failures offer a reachable retry or an intentional fallback; audio and observation errors are not silently discarded.
- [ ] Required repairs remain discoverable after navigation or relaunch, rather than existing only in view state.

## Focused data access

- [ ] Opening one item reads that item; counts use aggregates rather than loading entire histories unnecessarily.
- [ ] Views receive the data they need, not whole collections by default.
- [ ] Performance claims have evidence. Add caches or abstractions only for a demonstrated need, with clear invalidation ownership.

## Content and accessibility

- [ ] Long content remains readable at the largest accessibility text sizes and in compact layouts.
- [ ] Height caps and fixed layouts have an adaptive or scrolling fallback; primary actions stay reachable.
- [ ] VoiceOver can identify controls, reach recovery actions, and access only the currently visible card side.

## Behavioral verification

- [ ] Cover failed saves, retries, leaving during work, and relaunch—not just the successful journey. Prefer focused model/store tests where possible.
- [ ] Exercise navigation and long-content accessibility layouts in the app; source inspection alone does not prove usability.
- [ ] Test gates verify that required tests actually ran and passed, not merely that some tests passed.
- [ ] Report separately what was source-reviewed, built, tested, or manually exercised, and what remains unverified.

## Keep the scope honest

Check API availability against the actual SDK and iOS 26 deployment target. Do not adopt newer skill examples blindly. Prefer the existing presentation, domain, and store boundaries over adding a framework to satisfy this checklist.

See [the way](../docs/the_way.md) for verification strategy and [data management](../docs/data_management.md) for persistence and recovery decisions. Record concrete defects and acceptance criteria in tasks, not in this checklist. (../docs/README.md)
