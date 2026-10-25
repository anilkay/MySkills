---
name: dotnet-agent-app
description: Start or extend a .NET 10 web product built from the "agentapp" dotnet new template (layered Api/Application/Domain/Infrastructure + Cli, PostgreSQL/EF Core, ASP.NET Core Identity with cookie, bearer and personal API keys, Microsoft Agent Framework chat agents behind an OpenAI-compatible endpoint, framework-free Tailwind UI, HTTP-only CLI with GitHub release workflow, Podman/Quadlet deployment). Use when the user wants a new web app/API/product with accounts, AI assistants, a CLI or self-hosted deployment, or when adding a feature, agent, agent tool, CLI command, API key rule or release to a project with this layout (a solution with <Name>.Api, <Name>.Application, <Name>.Domain, <Name>.Infrastructure and <Name>.Cli projects and an AGENTS.md describing SwitchableChatClient and UseAppApiKeyGate).
---

# .NET agent app (agentapp template)

The template was extracted from the Mercek project (EconomyAgent repo). It lives in
`C:\Users\Administrator\source\repos\AgentAppTemplate\template` (installable folder) with a README one
level up. The generated project's own `AGENTS.md` and `.agents/skills/<name>-development/SKILL.md`
are the detailed rules; read them first in an existing project.

## Create a new project

```bash
dotnet new install C:\Users\Administrator\source\repos\AgentAppTemplate\template   # once; --force after template changes
dotnet new agentapp -n Defter --product "Defter" --owner <github-user> -o C:\Users\Administrator\source\repos\Defter
```

- `-n`: code name in PascalCase without dots or dashes (namespaces `Defter.Api`, CLI command `defter`,
  env vars `DEFTER_SERVER`/`DEFTER_TOKEN`, DB/Quadlet names `defter`, agent `DefterAssistant`).
- `--product`: the name users see (titles, brand letter, CLI help). It may contain spaces and Turkish letters;
  never use it in HTTP headers, file paths or identifiers (the template uses the code name there).
- `--owner`: GitHub owner for `ghcr.io/<owner>/<name>` in the Quadlet units.

Then, in the new folder:

1. `git init`, first commit (ask before creating a remote or pushing).
2. Create `src/<Name>.Api/appsettings.Development.json` with `ConnectionStrings:PostgreSql` and
   `Roles:AdminEmails` (the file is git-ignored; never commit it).
3. `dotnet tool restore`, `dotnet ef database update --project src/<Name>.Infrastructure --startup-project src/<Name>.Api`,
   `dotnet run --project src/<Name>.Api` (http://localhost:5180).
4. Register the first account while no admin exists, then restart so `Roles:AdminEmails` grants `Admin`.
5. Replace the sample `Note` feature and `AssistantAgent` prompt with the real product; keep them until the
   first real feature exists, they are the reference implementation.

## Add a feature (same path as `Note`)

1. Domain entity: private setters, invariants in constructor/methods, `Guid.CreateVersion7()`, UTC times, caps as
   constants, Turkish `ArgumentException` messages.
2. Application: `I<X>Repository` (Abstractions), `<X>Service(userId, ...)`, view/request records.
3. Infrastructure: repository over `AppDbContext`, mapping in `OnModelCreating` (snake_case table, lengths,
   indexes, cascading FK to `UserProfile`), `dotnet ef migrations add <Name>`.
4. Api: register in `ApplicationServiceRegistration`; `Me/<X>Endpoints.cs` under `/api/me` with the user from
   `ICurrentUser`; domain errors -> `400 { error }`; admin-only or expensive endpoints use `AppPolicies.Admin`.
5. UI: page with the shared topbar + `auth.js`, `textContent` only, styles in `Styles/<x>.css` imported in
   `tailwind.css`, `npm run css:build`, commit `wwwroot/app.css`.
6. CLI: `<X>Commands.cs`, entries in the `CliApp` command table, DTOs in `ApiContracts.cs`.
7. Agent tool (optional): read-only `<X>Tools` that resolves the user inside the tool and caps its output.

## Add an agent

Class like `AssistantAgent` (`SwitchableChatClient` + `WithEditablePrompt` + `WithUserMemory` + `AsAIAgent` +
`WithTelemetry`), name in `AiAgentNames`, default prompt in `AiAgentPromptStore`, singleton + `AddAIAgent` in
`AgentRegistration`, labels in `chat.js`/`chat.html`, `admin.js`, `admin-prompts.js`. Keep tools few and
read-only; the user never comes from a tool argument.

## Security rules that must survive every change

- Identity cookie for the browser, opaque bearer + refresh for clients, `Bearer app_...` API keys for automation;
  the `AppAuthSchemes.Default` policy scheme routes them. API keys: hash only, shown once, expire, `User` role
  only, `/api/me` only (`UseAppApiKeyGate`), `read` keys cannot write, keys managed with a session only.
  Exclude any new sensitive `/api/me` endpoint (password, account, credentials) from the gate.
- Never take a user id from a route, body or tool argument; never log passwords, tokens or keys; never return
  stack traces or stored model API keys.
- CLI: HTTP only, no project references, password hidden or `--password-stdin`, tokens in the user profile
  (DPAPI on Windows), plain HTTP only to loopback, no redirects followed.

## Pitfalls already hit

- `ProductInfoHeaderValue` (User-Agent) rejects spaces and non-ASCII: use the code name, not the product name.
- OpenAI-compatible requests to the hosted agents must put `role` before `content` in each message (the adapter's
  polymorphic deserializer needs the discriminator first); hashtable-based PowerShell JSON breaks this.
- Tiny local models (1-3B) often skip tools; to verify tool plumbing, ask explicitly for the tool and check that
  the server log shows two model calls, then judge answer quality with a larger model.
- `IdentityConstants.BearerAndApplicationScheme` is internal; the template repeats its value
  (`Identity.BearerAndApplication`) in `AppAuthSchemes`.
- Version 7 GUIDs created together share their first characters: short ids use the last 8 hex characters.
- Accept `12.5` or `12,5` in CLI numbers but refuse thousands separators (`1.000` is ambiguous in Turkish).
- `dotnet new` renames only `SampleApp` in file names by default; lowercase names need the `fileRename` symbol.

## Verify

```bash
npm run css:build
dotnet build <Name>.sln --no-restore --disable-build-servers   # 0 warnings
node --check src/<Name>.Api/wwwroot/<changed>.js
git diff --check
```

For runtime changes: throwaway database (`dotnet ef database update --connection "...Database=<name>_test..."`),
API on a free port, a test account created in that database, exercise the endpoint/page/CLI/agent, then drop
the database. Do not use real passwords or cloud models with real data for tests.

## Keeping the template current

Improvements made in a generated project or in EconomyAgent can be ported back into
`AgentAppTemplate/template` (code name `SampleApp`, product `SampleProduct`, brand `SampleMark`, env prefix
`SAMPLEAPP`, owner `GITHUB_OWNER`). After editing: build the template solution, `dotnet new install <path> --force`,
generate a scratch project, build it and grep it for leftover placeholders.
