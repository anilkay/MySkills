---
name: "mercek-ui-conventions"
description: "Use when writing or editing any user-visible page, text, or nav in the Mercek (EconomyAgent) web app, full view or Basit mod."
---

# Mercek UI conventions

## Naming and text
- Product name is **Mercek**. Never show "KAP" or "Kamuyu Aydınlatma Platformu" in visible text (use "bildirim", "resmî kaynaktan alınır"). Code, DB, cookie, env and container names keep "Kap".
- Turkish only. No technical terms for users (PostgreSQL, cache, cookie, LLM, token, "internet erişimi"). Say "asistan", not "agent". Assistants never mention databases or tools.
- Errors: Turkish, generic form "İşlem tamamlanamadı (hata kodu …)". Use "TL", not "TRY".
- Data source as a single bottom line ("Kaynak: İş Yatırım").
- Every page footer: "Yatırım tavsiyesi değildir…". No advice, target prices, or green/red judgement text.

## Layout
- Same top nav everywhere: Bildirimler, Analizler, Piyasalar ▾, Kişisel ▾, Analiz sohbeti; hamburger below 1180px. New pages go into a dropdown, never a new top-level item; link them from related pages.
- Basit mod (phone style) needs an equivalent under /m/ and a bottom-menu or "Daha fazla" entry. Screener, margin/leverage, account and admin stay full-view only.
- Respect the "Miktarları gizle" toggle for any amount, quantity, cost, value or P/L (percentages stay).
- Every page except login requires a session; all APIs require auth.

## Accessibility and compatibility
- WCAG AA contrast (4.5:1 text, 3:1 large/graphics) in full and Basit mod; add +/− signs, not colour alone. Brand colours stay.
- No inline scripts (CSP). Avoid secure-context-only browser APIs (anil sometimes uses plain HTTP).
- Bump the service-worker cache version when styles change.
- Buttons that start a request must disable while it runs; writes need server-side double-submit protection.

## Scope
BIST is the focus; US data stays separate and secondary. Do not re-propose items anil rejected: bulk-fetching all companies from İş Yatırım, TEFAS fund distributions, bold recent dividends, further EF query work.