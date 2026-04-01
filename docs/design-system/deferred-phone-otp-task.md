# Deferred Task: Phone Number OTP Registration

**Status:** DEFERRED — implement after UI is complete
**Priority:** High
**Depends on:** Login screen UI approval

## What to implement

### 1. Phone Number Registration Flow (code changes)
- Add `PhoneRegistrationView` to `AuthHubView.swift` (new route: `.phoneRegistration`)
- International area code picker:
  - Use **PhoneNumberKit** (SPM) or build custom SwiftUI picker
  - Auto-detect country via `Locale.current`
  - Unicode flag emojis (no image assets needed): 🇺🇸 🇮🇱 🇬🇧 etc.
  - Searchable list of 200+ countries by name, ISO code, or dialing code
  - Manual entry of area code supported
- Phone number input field with formatting per country
- Validation via `libPhoneNumber`

### 2. Phone OTP Verification
- Send SMS OTP via Supabase Auth (`supabase.auth.signInWithOtp(phone:)`)
- Reuse the existing `EmailVerificationView` pattern but adapted for phone:
  - Title: "Verify Your Phone"
  - Subtitle: "Enter the 6-digit code sent to +972 XX XXX XXXX"
  - 6-digit OTP boxes (phone SMS codes are typically 6 digits, not 5)
  - Resend link with cooldown timer (60s)
- On success: create session, proceed to Home

### 3. Supabase Configuration
- Enable Phone Auth provider in Supabase Dashboard
- Configure SMS provider (Twilio, MessageBird, or Vonage)
- Set OTP expiry (default 60s)
- Rate limiting: max 5 OTP requests per phone per hour

### 4. Files to modify
- `FitTracker/Views/Auth/AuthHubView.swift` — add PhoneRegistrationView + PhoneVerificationView
- `FitTracker/Services/Auth/SignInService.swift` — add `signInWithPhone(number:)` + `verifyPhoneOTP(code:)`
- `FitTracker/Services/Supabase/SupabaseClient.swift` — phone auth methods
- `Package.swift` or Xcode SPM — add PhoneNumberKit dependency

### 5. Best practice references
- PhoneNumberKit: https://github.com/marmelroy/PhoneNumberKit
- Supabase Phone Auth: https://supabase.com/docs/guides/auth/phone-login
- Unicode flag emojis via ISO 3166-1 regional indicators
