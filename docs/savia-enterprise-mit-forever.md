# Savia Enterprise is MIT — forever

> Public statement · 2026-04-11 · SE-008

Savia Enterprise is released under the MIT License. Every module, every
adapter, every extension point. Not "open core". Not "BSL with a grace
period". Not "free tier with a locked enterprise edition". MIT. The same
terms as Savia Core. Forever.

This is an engineering decision, not a marketing one. Here is the reasoning.

## The seven principles decide

Savia is built on seven foundational principles that never move:

1. **Data sovereignty** — `.md` is truth. Everything else is derived.
2. **Vendor independence** — adapters, not couplings, to every runtime.
3. **Radical honesty** — failures are documented, not hidden.
4. **Absolute privacy** — client data never leaves the client.
5. **The human decides** — no autonomous merges, no autonomous deploys.
6. **Equality shield** — bias-checked assignments and evaluations.
7. **Identity protection** — Savia stays Savia under any brand.

A dual-license model fails principle #2 the moment it ships. An Open Core
model creates an incentive to move valuable features behind the paywall,
violating #1 and #2. BSL violates #2 during the license period and #3 in
spirit (temporary lock-in is still lock-in). AGPL forces the downstream to
publish code that, in regulated sectors, cannot legally be published,
violating #5. A SaaS-hosted model puts client data in our hands, violating
#1 and #4. A pay-per-agent model gates capabilities behind payment,
violating #7 (the identity of Savia is its full capability set).

Every proprietary model we examined contradicts at least one principle. MIT
contradicts none.

## What we monetize (if we do)

Code is not the product. Services are. Support with SLA, implantation,
training, custom spec development, sovereignty audits, hardware integration.
All of it is labor, not license fees. Organizations that want the code can
have the code. Organizations that want labor pay for labor. The line is
bright, and it never moves.

## What the clone-your-own-instance test means

If you clone this repository today, run `/sprint-status`, run
`/dev-session start`, activate the Enterprise manifest, and never speak to
the upstream again — you have a fully functional, fully auditable, fully
sovereign system. That is the test Savia Enterprise must pass on every
release. No module, no spec, no PR may ship if it breaks the test.

## What happens if we fail

If we fail this commitment, the right response is to fork the repository,
remove the violation, and ship it elsewhere under the original MIT license.
That is what MIT allows and what the principles demand. The commitment is
not a promise of good behavior; it is an architectural guarantee.

## Reference

- Spec: `docs/propuestas/savia-enterprise/SPEC-SE-008-licensing-distribution.md`
- License text: `LICENSE-ENTERPRISE.md`
- Trademark: `TRADEMARK.md`
- Services offered: `docs/support-offering.md`
- Foundational principles: `docs/rules/domain/savia-foundational-principles.md`
