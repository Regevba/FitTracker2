# FitMe — Privacy Policy

**Last updated:** April 16, 2026

## Overview

FitMe is a personal fitness tracking app built on a zero-knowledge, privacy-first architecture. Your health data belongs to you.

---

## What We Collect

### Data stored locally on your device
- Health metrics: workouts, body weight, body fat %, HRV, sleep, nutrition logs
- User preferences and app settings
- AI-generated readiness scores and recommendations (computed on-device)

All local data is **AES-256 encrypted at rest** using keys that never leave your device.

### Data synced to our servers (Supabase)
- Encrypted health record blobs — we cannot read the contents
- Account identifier (anonymous UUID, not linked to your name or email)
- Sync timestamps and record checksums

We operate **zero-knowledge sync**: data is encrypted on your device before it leaves. Our servers store ciphertext only.

---

## What We Do NOT Collect

- Your name, email address, or any personally identifiable information
- Unencrypted health or fitness data
- Location data
- Device identifiers used for cross-app tracking
- Data sold or shared with advertisers — ever

---

## Third-Party Services

### Firebase Analytics (Google)
- Used for aggregated, anonymized usage analytics (screen views, feature adoption)
- Analytics collection requires your explicit in-app consent
- You can opt out at any time in Settings → Privacy
- Governed by [Google's Privacy Policy](https://policies.google.com/privacy)

### Supabase
- Provides the encrypted sync backend
- Receives only encrypted blobs — no plaintext health data
- Governed by [Supabase's Privacy Policy](https://supabase.com/privacy)

### Apple HealthKit
- FitMe reads and writes data to Apple Health with your permission
- HealthKit data is never shared with third parties or used for advertising
- You can revoke HealthKit access at any time in iOS Settings → Health → Data Access

---

## Your Rights (GDPR / CCPA)

| Right | How to exercise it |
|---|---|
| **Access** | Export all your data: Settings → Privacy → Export My Data |
| **Deletion** | Delete all data: Settings → Privacy → Delete My Account |
| **Consent management** | Toggle analytics: Settings → Privacy → Analytics |
| **Portability** | Data exported as JSON — machine-readable and portable |

Requests are processed within 30 days. For manual requests, email **regvash21@gmail.com**.

---

## Data Retention

- Local data: retained until you delete the app or trigger account deletion
- Synced encrypted blobs: deleted within 30 days of account deletion request
- Analytics events: retained per Firebase's standard 14-month rolling window

---

## Children

FitMe is not directed at children under 13. We do not knowingly collect data from children.

---

## Changes to This Policy

Material changes will be communicated via in-app notification. Continued use after the effective date constitutes acceptance.

---

## Contact

Questions or concerns about privacy:

**Email:** regvash21@gmail.com
