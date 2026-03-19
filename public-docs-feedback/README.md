# Doc Quality Feedback — Agent Ratings

This directory stores feedback from agents about documentation quality.

Each `.jsonl` file corresponds to one document. Each line is a JSON rating:
```json
{"doc":"path","agent":"name","rating":"clear|confusing|incomplete|outdated|wrong","note":"...","ts":"ISO"}
```

Run `/docs-quality-audit` to aggregate ratings and identify docs needing rewrite.
