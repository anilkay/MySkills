---
name: "mercek-feature-delivery"
description: "Use when adding or changing a feature in the Mercek (EconomyAgent) repo: shared-checkout git rules, push to main, changelog line, migrations, verification."
---

# Mercek feature delivery

Repo: github.com/anilkay/EconomyAgent (.NET API in src/KapAgent.Api with static wwwroot, PostgreSQL). Owner anil writes Turkish; reply to him in Turkish.

## Workflow
1. Read AGENTS.md and the neighbouring code first; match its style.
2. Build (`dotnet build`, `npm run css:build` if styles changed). anil prefers speed: skip browser checks, he tests in the browser. Say plainly that it was not browser-tested.
3. Add one line at the top of `src/KapAgent.Api/Admin/features.json` (date + short Turkish text, newest first) in the same commit for any user-visible feature.
4. Commit and push directly to main. No PRs. If a push is blocked by a permission prompt, only anil can approve ("push"/"evet" in the thread or his own `git push`); ask once.

## Shared checkout (parallel threads)
- Stage only your own files; hunk-stage shared files (Program.cs, KapAgentDbContext.cs, EF snapshot).
- Verify the COMMITTED state builds (not just the working tree).
- `git pull --rebase` right before pushing. Never stash or reset others' uncommitted work.
- Migrations: pull --rebase right before generating, push right after. The app does not migrate at startup; production runs the kapagent-migrate unit before the app.

## Config features
New integrations read keys from env (`Section__Key`), empty means feature off. Document them in deploy/kapagent.env.example and the README. If a page needs a new external script/host, extend `Security/SecurityHeaders.cs` CSP for that page only; pages must have no inline scripts.

## Report
Finish with a short Turkish summary: what changed, commit hash, what anil must do (env keys, restart), known limits.