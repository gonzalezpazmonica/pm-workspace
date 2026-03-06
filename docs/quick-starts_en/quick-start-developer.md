# Quick Start — Developer

> 🦉 Hi, Developer. I'm Savia. I help you know what to do, implement specs, run tests, and stay focused. Your sprint, your code, your pace.

---

## First 10 minutes

```
/my-sprint
```
Your personal sprint view: assigned items, status, cycle time, and priority.

```
/my-focus
```
I identify your highest-priority item and load all its context (spec, related files, previous decisions).

```
/code-patterns
```
Project patterns with real code examples. Useful if you just joined the team.

---

## Your daily routine

**Starting the day** — `/my-focus` to know where to pick up. If there's an assigned SDD spec, I already have all the context loaded.

**When implementing** — `/spec-implement {spec}` launches the SDD flow: I implement handlers, repositories, and tests following the spec as contract. If you prefer to do it yourself, the spec tells you exactly which files to create and which interfaces to follow.

**After finishing a block** — `/spec-verify {spec}` verifies the implementation meets the spec. Pre-commit hooks validate size, schema, and domain rules automatically.

**If you're stuck** — `/memory-search {topic}` searches previous decisions. `/entity-recall {component}` retrieves everything I know about that component.

**Friday** — `/my-learning` analyzes your week's code and spots improvement opportunities.

---

## How to talk to me

| You say... | I run... |
|---|---|
| "What's assigned to me?" | `/my-sprint` |
| "What should I do now?" | `/my-focus` |
| "Implement this spec" | `/spec-implement {spec}` |
| "Do the tests pass?" | `/spec-verify {spec}` |
| "How do we do X in this project?" | `/code-patterns` + `/memory-search` |
| "What did we decide about the auth module?" | `/entity-recall auth-service` |
| "Review my code" | `/spec-review {file}` |

---

## Where your files are

```
output/
├── specs/              ← generated SDD specs (executable contracts)
├── implementations/    ← agent-generated code
└── .memory-store.jsonl ← memory with decisions and context

.claude/
├── agents/developer-*.md  ← implementation agents (use worktrees)
├── commands/spec-*.md     ← SDD commands
└── rules/language/        ← your project's language rules
```

Developer agents work in isolated worktrees (`isolation: worktree`). This means they can implement in parallel without merge conflicts. When done, code integrates via PR.

---

## How your work connects

Your code starts with a spec (`/spec-generate`). The spec defines the contract: what to do, which interfaces to follow, which tests to pass. When you implement (you or an agent), the automated code review checks against the rules. Tests update coverage. Coverage feeds the QA dashboard. Your items' cycle time feeds sprint velocity, which the PM uses for forecasting. If you log hours, those hours go to cost-management and from there to billing.

---

## Next steps

- [Spec-Driven Development](../readme_en/05-sdd.md)
- [Workspace structure](../readme_en/02-structure.md)
- [Data flow guide](../data-flow-guide-en.md)
- [Full commands](../readme/12-comandos-agentes.md)
