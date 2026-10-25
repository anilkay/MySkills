---
name: "mercek-ops-deploy"
description: "Use when explaining or changing how Mercek (EconomyAgent) is deployed or configured in production: Podman Quadlet, CI image, env file, Cloudflare tunnel."
---

# Mercek production ops

- Host: anil's AlmaLinux, rootless Podman Quadlet units: kapagent-db, kapagent-migrate (runs before the app), kapagent-app (AutoUpdate=registry), kapagent-tunnel.
- Env file: ~/.config/kapagent/kapagent.env. Podman env files do not strip quotes, so write values unquoted. Empty value usually means the feature is off (Push, Turnstile, Ses, OTEL).
- CI: push to main builds ghcr.io/anilkay/economyagent. Deploy with `podman auto-update`, then `systemctl --user restart kapagent-app`. The footer line "Sürüm abc1234 · tarih" confirms which commit is live.
- Quadlet `.container` files are NOT deployed by CI: anil must copy kapagent-db and kapagent-tunnel files to ~/.config/containers/systemd/, run `systemctl --user daemon-reload`, then restart. Image tags (postgres, cloudflared) are pinned by hand.
- Cloudflare named tunnel on a subdomain of anil.work forwards to http://kapagent-app:8080. Logs: `podman logs kapagent-tunnel`. Client IP comes from CF-Connecting-IP / X-Forwarded-For, trusted only from private networks.
- Config reference: deploy/kapagent.env.example and the README ("Rate limits", "Logs"). Feature toggles: `RateLimiting__Enabled`, `Compression__Enabled`, `Cache__Enabled`, `Push__*`, `Turnstile__SiteKey/SecretKey`.
- Give anil copy-paste steps in Turkish and say clearly which steps are unconfirmed on his side.