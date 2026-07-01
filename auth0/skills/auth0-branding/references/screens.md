# Universal Login screens, by category

Canonical category map used by "Match my brand voice" to expand user-selected categories into concrete (prompt, screen) pairs for custom-text rewrites. Source: Auth0 internal data.

**This list is a starting point, not exhaustive.** Auth0 adds new screens over time. When the skill encounters a screen name it doesn't recognize (the user mentions one, or a new flow lights up), it should fall back to probing `GET /api/v2/prompts/{prompt}/custom-text/{lang}` for the candidate prompt/locale: the response indicates whether the prompt accepts that screen's keys. If the user knows the new screen name but the skill doesn't, accept what they give and proceed. The skill should treat this map as current-as-of-last-update, not as the authoritative registry.

The custom-text API is **per-prompt, not per-screen**. Multiple screens under the same prompt share one PUT call with a single merged body keyed by screen name. When applying rewrites, batch screens by prompt.

**Single-screen prompts:** Many prompts have exactly one screen, where the screen name matches the prompt name (e.g., prompt `login-id`, screen `login-id`). These still require their own individual PUT call — batching doesn't apply, but the structure is the same. Do not attempt to nest them under a parent prompt.

**Currency of this list:** The tables below reflect the known screen inventory as of last update. Auth0 adds screens over time — new screens may appear under existing prompts, or entirely new prompts may be introduced. Treat this list as a reliable baseline, not a closed registry. If the API accepts a screen or prompt not listed here, that is expected; follow the "Learn new screens" flow in `capability-voice.md` to record it.

**Important: `GET /prompts/{prompt}/custom-text/{lang}` returns only keys the tenant has explicitly customized**, not Auth0's default built-in text. For a screen the tenant has never customized, GET returns an empty object (or the key is absent) and the skill cannot read the default copy via the API. See `capability-voice.md` "Generate and apply" for how to handle this.

## Login

**Identifier-first note:** `login-id` and `login-password` are each their own prompt, not screens nested under the `login` prompt. Each takes a separate `PUT /prompts/{prompt}/custom-text/{lang}` call with a body keyed by the screen name matching the prompt name (e.g., `{ "login-id": { ... } }`). Do not batch them under `login`.

| Prompt | Screen |
|---|---|
| login | login |
| login-id | login-id |
| login-password | login-password |
| email-identifier-challenge | email-identifier-challenge |
| phone-identifier-challenge | phone-identifier-challenge |
| phone-identifier-enrollment | phone-identifier-enrollment |
| login-email-verification | login-email-verification |

## Signup

**Same pattern as Login:** `signup-id` and `signup-password` are separate prompts, not screens under `signup`. Each requires its own PUT call.

| Prompt | Screen |
|---|---|
| signup | signup |
| signup-id | signup-id |
| signup-password | signup-password |

## Passwordless

| Prompt | Screen |
|---|---|
| login-passwordless | login-passwordless-email-code |
| login-passwordless | login-passwordless-email-link |
| login-passwordless | login-passwordless-sms-otp |
| email-otp-challenge | email-otp-challenge |

## Password reset

Includes reset-time MFA challenge screens because they're part of the reset flow Auth0-side.

| Prompt | Screen |
|---|---|
| reset-password | reset-password |
| reset-password | reset-password-request |
| reset-password | reset-password-email |
| reset-password | reset-password-success |
| reset-password | reset-password-error |
| reset-password | reset-password-mfa-email-challenge |
| reset-password | reset-password-mfa-otp-challenge |
| reset-password | reset-password-mfa-push-challenge-push |
| reset-password | reset-password-mfa-sms-challenge |
| reset-password | reset-password-mfa-phone-challenge |
| reset-password | reset-password-mfa-voice-challenge |
| reset-password | reset-password-mfa-recovery-code-challenge |
| reset-password | reset-password-mfa-webauthn-platform-challenge |
| reset-password | reset-password-mfa-webauthn-roaming-challenge |

## Passkeys

| Prompt | Screen |
|---|---|
| passkeys | passkey-enrollment |
| passkeys | passkey-enrollment-local |

## MFA

Grouped by factor. When the user picks MFA, show a sub-picker so they can scope to the factors they've actually enabled on the tenant.

**Key restrictions on `mfa` prompt screens:** `mfa-begin-enroll-options` and `mfa-login-options` only accept `title` — `description` is not a valid key and the API will reject it with a 400. Do not include `description` in rewrites for these screens.

| Prompt | Screen |
|---|---|
| mfa | mfa-begin-enroll-options |
| mfa | mfa-detect-browser-capabilities |
| mfa | mfa-enroll-result |
| mfa | mfa-login-options |
| mfa-email | mfa-email-challenge |
| mfa-email | mfa-email-list |
| mfa-otp | mfa-otp-challenge |
| mfa-otp | mfa-otp-enrollment-code |
| mfa-otp | mfa-otp-enrollment-qr |
| mfa-push | mfa-push-challenge-push |
| mfa-push | mfa-push-enrollment-code |
| mfa-push | mfa-push-enrollment-qr |
| mfa-push | mfa-push-list |
| mfa-push | mfa-push-success |
| mfa-push | mfa-push-welcome |
| mfa-sms | mfa-country-codes |
| mfa-sms | mfa-sms-challenge |
| mfa-sms | mfa-sms-enrollment |
| mfa-sms | mfa-sms-list |
| mfa-phone | mfa-phone-challenge |
| mfa-phone | mfa-phone-enrollment |
| mfa-voice | mfa-voice-challenge |
| mfa-voice | mfa-voice-enrollment |
| mfa-recovery-code | mfa-recovery-code-challenge |
| mfa-recovery-code | mfa-recovery-code-enrollment |
| mfa-recovery-code | mfa-recovery-code-challenge-new-code |
| mfa-webauthn | mfa-webauthn-change-key-nickname |
| mfa-webauthn | mfa-webauthn-enrollment-success |
| mfa-webauthn | mfa-webauthn-error |
| mfa-webauthn | mfa-webauthn-platform-challenge |
| mfa-webauthn | mfa-webauthn-platform-enrollment |
| mfa-webauthn | mfa-webauthn-roaming-challenge |
| mfa-webauthn | mfa-webauthn-roaming-enrollment |
| mfa-webauthn | mfa-webauthn-not-available-error |

## Organizations (B2B)

| Prompt | Screen |
|---|---|
| organizations | organization-picker |
| organizations | organization-selection |
| invitation | accept-invitation |

## Other

Long-tail screens rarely targeted for voice rewrites. Available if the user explicitly picks the Other category, where they can then choose individual screens.

| Prompt | Screen |
|---|---|
| consent | consent |
| customized-consent | customized-consent |
| logout | logout |
| logout | logout-aborted |
| logout | logout-complete |
| device-flow | device-code-activation |
| device-flow | device-code-activation-allowed |
| device-flow | device-code-activation-denied |
| device-flow | device-code-confirmation |
| email-verification | email-verification-result |
| captcha | interstitial-captcha |
| brute-force-protection | brute-force-protection-unblock |
| brute-force-protection | brute-force-protection-unblock-failure |
| brute-force-protection | brute-force-protection-unblock-success |
| common | redeem-ticket |
| status | status |
| custom-form | custom-form |
