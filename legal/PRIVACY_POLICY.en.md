# Ripple Garden Privacy Policy

> **Draft (v1, 2026-10-19)** — needs review before actual store submission (P3-004).
> Items marked `[TODO]` are not yet settled; they are filled in once the support email and the
> hosting URL are decided.

Effective date: [TODO: set at submission]
Service name: Ripple Garden
Developer / provider: [TODO: business or individual details]

## 1. Overview

Ripple Garden ("the app") is designed around one principle: **it collects no personal data**
(docs/07_MONETIZATION_PRIVACY.md §4). This policy explains what data the app handles, where it
stays, and what you can do about it.

## 2. Personal data we collect

**The app collects no personal data.**

- No account, login, or sign-up.
- No advertising SDK and no analytics SDK.
- No remote config and no gameplay server.
- The app works offline; it has no networking features.

## 3. Data stored on your device

Your game progress stays on your device only.

| Data | Location | Contents |
|---|---|---|
| Save files | App-private storage (`user://`) | Progress, journal, settings (a few KB of JSON) |
| Photo mode pictures | App-private storage (`user://photos`) | PNGs you took yourself (never auto-saved to the gallery) |

This data never leaves your device, and the developer cannot read or collect it.

## 4. Diagnostics (no automatic upload)

A diagnostic file is created only when you choose **Export** in Settings. Nothing is uploaded
automatically.

It may contain: app version, OS type and version, graphics profile, save schema version, and a
recent error log. Personal identifiers and real file paths are masked and minimized
(docs/07 §5). The file is shared only by the method you pick (for example email).

## 5. Purchases (applies when purchase integration ships)

[TODO: settle after P1-011/012 · P3-001~003 purchase integration]

Full-game purchases are processed by the store's payment system (Google Play / Steam). The
developer never receives or stores payment card information. Purchase records handled by the store
follow that store's own privacy policy. Restore-purchases will be offered, and a failed purchase
never costs you progress.

## 6. Sharing with third parties

Personal data is never shared with or processed by third parties — because none is collected. When
purchase integration ships, the store operators will process payment information within their own
scope; that addition will be announced here.

## 7. Children

The app is not directed at children, but a child using it will not have personal data collected
intentionally. There are no ads and no user-to-user chat.

## 8. Your choices and deletion

- **Delete data**: reset game data in Settings, or uninstall the app — everything stored goes with it.
- **Deletion request by email**: [TODO: support email]. Because save data never leaves your
  device, the developer cannot delete it for you and will instead guide you through deleting it
  on your device.

## 9. Policy changes

Changes are announced with an updated effective date and app version. Material changes (such as
new data collection) are announced 7 days before they take effect.

## 10. Contact

Privacy questions: [TODO: support email]
