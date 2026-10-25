# MySkills

Custom [Claude Code](https://claude.com/claude-code) skills.

| Skill | What it does |
|---|---|
| [avalonia-app](.claude/skills/avalonia-app/SKILL.md) | Build or port cross-platform desktop apps with Avalonia UI (.NET) |
| [dotnet-agent-app](.claude/skills/dotnet-agent-app/SKILL.md) | Start or extend a .NET 10 web product from the `agentapp` template |
| [macos-app-bundle](.claude/skills/macos-app-bundle/SKILL.md) | Package a .NET desktop app as a signed macOS `.app` bundle |
| [mercek-feature-delivery](.claude/skills/mercek-feature-delivery/SKILL.md) | Feature workflow for the Mercek (EconomyAgent) repo: git rules, changelog, migrations |
| [mercek-ops-deploy](.claude/skills/mercek-ops-deploy/SKILL.md) | How Mercek runs in production: Podman Quadlet, CI image, env file, Cloudflare tunnel |
| [mercek-ui-conventions](.claude/skills/mercek-ui-conventions/SKILL.md) | Text, layout and accessibility rules for Mercek web pages |
| [ai-tool-security-review](.claude/skills/ai-tool-security-review/SKILL.md) | Security review of apps that let an LLM call local tools or host an MCP server |
| [app-features-as-ai-tools](.claude/skills/app-features-as-ai-tools/SKILL.md) | Expose an app's features as safe, read-only tools for an in-app AI agent or MCP server |
| [dotnet-single-file-release](.claude/skills/dotnet-single-file-release/SKILL.md) | Release a .NET app as a self-contained single-file exe via GitHub Actions on `v*` tags |

## Install

Copy a skill folder into `~/.claude/skills/` (all projects) or into a project's `.claude/skills/`.
