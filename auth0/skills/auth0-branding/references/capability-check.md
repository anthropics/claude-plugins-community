# Capability 5: Check my setup

Read-only diagnosis. Answers "will theme changes actually show up on the flows I care about?"

Safe to run first; a good starter when diagnosing "why doesn't my theme show up?" before running Capability 1 ("Brand my tenant").

## Background: Universal Login vs Classic

Themes and templates only apply to flows actually running in Universal Login. Tenants can run in hybrid mode where some flows are Classic. Branding in this skill does not affect Classic flows.

All three Classic toggles are **tenant-wide**. There is no per-client override; if a flow is set to Classic, every client in the tenant uses Classic for that flow.

- **Login and signup**: `GET /api/v2/prompts` → `universal_login_experience`. `"classic"` means every client's login and signup runs Classic; `"new"` means Universal Login.
- **Password reset**: `PATCH /api/v2/tenants/settings`; the `change_password` object (`{ enabled, html }`). When `enabled: true`, the tenant renders Classic for password reset.
- **MFA**: same endpoint; the `guardian_mfa_page` object (`{ enabled, html }`). When `enabled: true`, the tenant renders Classic for MFA.

To restore Universal Login for a flow, set the relevant toggle to false. The checks below flag any toggles in the Classic state.

If a flow is intentionally kept in Classic, "Brand my tenant" can still apply tenant-wide branding settings (logo, favicon, primary color); those show up on Classic pages too. But the theme and page template will not affect that flow.

## Checks (run in parallel)

1. **Universal Login enabled at tenant level**: `GET /api/v2/tenants/settings` → `flags.universal_login === true`.
2. **Login and signup experience**: `GET /api/v2/prompts` → `universal_login_experience`. `"new"` means every client gets Universal Login for login/signup; `"classic"` means every client runs Classic.
3. **Password reset and MFA Classic toggles**: from the tenant settings call, `change_password.enabled` and `guardian_mfa_page.enabled`. Flag if true (that flow is running Classic for the whole tenant).
4. **Custom domain**: `GET /api/v2/custom-domains`. Flag if empty (page templates cannot apply).
5. **Theme present**: `GET /api/v2/branding/themes/default`. Flag if 404 (no theme has been applied yet).
6. **Active flows**: `GET /api/v2/connections`. Determines which login flows actually matter.

## Output format

Structured checklist with pass/fail/warn and a summary of what the theme *will* and *won't* affect:

```text
Tenant: acme-prod (environment: production)

Universal Login at tenant level              ✓
New Universal Login experience               ✓
Current default theme                        ✓ (themeId abc123...)
Custom domain                                ✓ login.acme.com

Tenant-wide flow toggles:
  ✓ Login/signup            universal_login_experience: new  → Universal
  ✓ Password reset          change_password.enabled: false   → Universal
  ✗ MFA                     guardian_mfa_page.enabled: true  → Classic

Active flows (from connections):
  ✓ Username-password database: login + signup + password reset enabled
  ✓ Google social
  — Enterprise: none

Summary:
  Theme will apply to login/signup (tenant set to new) and password reset.
  Theme will NOT apply to MFA (tenant has guardian_mfa_page.enabled: true, so MFA runs Classic for every client).
  Fix (if desired):
    PATCH /tenants/settings --data '{"guardian_mfa_page": {"enabled": false}}'
```

This capability is read-only and does not write to the tenant; skip the "Verify in browser (post-apply)" step from SKILL.md.
