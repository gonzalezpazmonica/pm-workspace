---
version_bump: minor
section: Changed
---

### Changed

- SE-299 optimized model tiers for extraction agents: archive-digest mid→fast, pptx-digest heavy→mid, visual-digest heavy→mid, word-digest heavy→mid. ~60% inference cost reduction for extraction workloads. No logic changes, only model tier metadata.
