# Threat Model

Ant Manager is a **local-first, personal work reflection tool**.  
This document describes the threats we consider, and the boundaries we intentionally do not cross.

## Scope

Ant Manager is designed for **individual use** on a personal machine.
It is not a monitoring tool, surveillance system, or employer-facing product.

The primary goal is to help an individual understand and reflect on their own work over time.

---

## Assets Being Protected

Ant Manager may process or store:

- Local git metadata (commits, timestamps, messages)
- Manually entered notes
- User-provided meeting transcripts
- AI-generated summaries derived from the above

These may contain sensitive professional or personal context.

---

## Threats Considered

### 1. Data Exfiltration

**Risk:**  
Sensitive data leaving the user’s machine without intent.

**Mitigation:**  
- Local-first architecture by default  
- No background network communication  
- Optional external LLM providers are **explicitly user-enabled**
- No telemetry, analytics, or remote logging

---

### 2. Accidental Disclosure

**Risk:**  
Sensitive content appearing unexpectedly (notifications, previews, logs).

**Mitigation:**  
- No notifications containing content
- No background UI popups
- No automatic exports
- All sharing actions are manual and explicit

---

### 3. Model Hallucination or Misrepresentation

**Risk:**  
AI-generated summaries presenting incorrect or fabricated information.

**Mitigation:**  
- Summaries are derived from explicit inputs
- Manual review and editing is expected
- Ant Manager does not claim summaries are authoritative records

---

### 4. Misuse as a Surveillance Tool

**Risk:**  
The software being interpreted or used as employee monitoring software.

**Mitigation:**  
- No passive screen capture
- No keystroke logging
- No audio recording
- No activity scoring or productivity metrics
- No employer or team features

---

### 5. Legal and Consent Risks

**Risk:**  
Violations of recording or consent laws.

**Mitigation:**  
- Ant Manager does not record meetings or conversations
- Transcripts must be manually provided by the user
- Users are responsible for ensuring transcripts comply with local laws

---

## Explicit Non-Goals

Ant Manager does **not** aim to:

- Monitor people
- Record conversations covertly
- Bypass workplace policies
- Serve as evidence in disputes
- Automate performance evaluation

---

## Summary

Ant Manager prioritizes:
- User agency
- Transparency
- Minimal data collection
- Predictable behavior

It is designed to feel like a **personal notebook with structure**, not an automated observer.
