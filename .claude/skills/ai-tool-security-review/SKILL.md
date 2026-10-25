---
name: "ai-tool-security-review"
description: "Security-review an app that lets an LLM agent call local tools or exposes them over MCP: prompt injection, exfiltration, approvals, MCP auth, keys, privilege, distribution."
---

# Security review: apps with AI agent tools / MCP servers

Use for desktop or local apps where a language model can call functions on the user's machine (file listing/reading, env vars, network diagnostics, system info) or where the app hosts an MCP server. Do not change code during the review unless asked; deliver a report.

## Method
1. Inventory every tool the model or MCP client can call: name, arguments, what it touches, whether it needs approval, what it returns.
2. List every source of untrusted text that reaches the model: file names, file contents, command lines, registry/firewall descriptions, web pages, MCP client requests, other tool output.
3. Build attack chains: untrusted text -> instruction -> sensitive read -> exfiltration channel. A finding is strongest as a concrete chain.
4. Verify by test where possible (start the server with a dummy key, send requests from another process, plant files). Label each finding "Verified" (tested) or "From code".
5. On re-checks, add a dated section at the top with a status column (Fixed / Partially / Open / Accepted) per finding and the commit checked. Record decisions the user accepts as won't-fix.

## Checklist
**Prompt injection and exfiltration**
- System prompt says tool results are data, not instructions (cheap, not sufficient).
- Any tool that resolves a hostname (ping, traceroute, HTTP fetch, DNS lookup) is an exfiltration channel via DNS even when ICMP/TCP is blocked: `<data>.attacker.com`. Require approval showing host/port, or allow only IP literals or hosts the user typed.
- Sensitive reads (file contents, env vars) require per-call approval, default answer No; deny when no UI can ask (headless/MCP).
- Mask secret-looking env vars (KEY, TOKEN, SECRET, PASSWORD, PWD, CONNECTIONSTRING); block known secret paths (.ssh, .aws, .azure, .kube, .git-credentials, *.pem, *.key, .env, browser profiles, unattend.xml).
- Rendered output: no auto-loading remote images; links open only http/https with the URL visible; exported Markdown neutralizes `![](...)`; no RTF/HTML injection in chat views.
- Approval dialogs: strip control chars and cap length of model-supplied args; state every destination the data goes to (LLM endpoint and, via MCP, the MCP client).
- Tool calls with arguments are logged in the transcript and export so the user can audit.

**Path handling**
- Block UNC and device paths (`\\host\`, `\\?\`, `\\.\`) before touching the filesystem (NTLM leak).
- Lexical drive checks miss mapped/subst network drives and symlinks to UNC: check `DriveInfo.DriveType`, resolve final path via handle (`GetFinalPathNameByHandle`); treat errors as "not local".
- Reads are bounded (stream up to N chars, never ReadAllText then truncate); show file size in approval.
- Scans skip reparse points/junctions; deletes re-verify path, size, timestamp at delete time (TOCTOU) and go to the Recycle Bin after confirmation.

**MCP / local server**
- Loopback is not per-user: any local process or other RDP user can connect. Require a random per-launch bearer token (32 bytes) and show a ready-to-copy client config.
- Validate Host header (localhost/127.0.0.1/[::1] with port) and reject foreign or `null` Origin (DNS rebinding / browser CSRF).
- Do not silently fall back to another port when busy (port squatting); report the error.
- Tool annotations: ReadOnly, non-destructive. Destructive or admin actions are not exposed at all.
- A server-side "ask the agent" tool spends the user's API key: it needs auth too.

**Credentials and endpoint**
- API key in the OS store (Windows Credential Manager / Keychain / libsecret), never plain files or logs.
- Key bound to the endpoint host; changing the host does not auto-send the old key (e.g. on model list fetch).
- HTTPS required except for loopback (local Ollama/LM Studio).
- Records/classes holding passwords exclude them from ToString/logging.

**Privilege and process**
- If the app runs elevated, the agent and MCP inherit admin reads (confused deputy). Warn or disable AI/MCP when elevated; better, run admin operations in a short-lived separate elevated process.
- Windows binary planting: start system exes by full path (`%WINDIR%\explorer.exe`); `[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]`; test by dropping harmless copies of DLLs next to the exe.

**Supply chain and release**
- `dotnet list package --vulnerable --include-transitive` (or npm/pip equivalent); secret scan of git history.
- CI actions pinned to SHAs, `${{ }}` via env, checksums/attestation, signing, lock files.
- If the repo is public, keep the report out of the repo until fixes ship.

## Report format
- Write in the user's language. Short summary first (overall verdict + top 2 risks), then a table: # | Finding | Severity (High/Medium/Low/Info) | Evidence (Verified/From code) | Status.
- Each finding: Where (file:line), Problem, Impact, Evidence (test output), Recommendation ordered by impact.
- Include a "Done well" section and a recommended fix order.
- Save as a dated Markdown file in the shared project folder, not in the repo.