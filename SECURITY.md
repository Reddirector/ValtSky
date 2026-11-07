# Security Policy

ValtSky treats data security, privacy, and encryption with the rigor demanded by mission-critical aerospace standards (ADE STD 100). As a personal zero-loss cloud vault that bridges local file systems directly with Telegram's distributed data centers, security boundaries are enforced at compile time, runtime, and in transit.

---

## Supported Versions

Only the latest active major/minor release stream receives official security patches and vulnerability mitigations.

| Version | Supported | Status |
| :--- | :--- | :--- |
| **v2.1.x** | :white_check_mark: | **Current Production Airframe (Active)** |
| **v2.0.x** | :warning: | End of Active Maintenance |
| **< v2.0** | :x: | Deprecated |

---

## Threat Model & Security Invariants

ValtSky implements a multi-layer defense-in-depth posture:

1. **Direct MTProto 2.0 Encryption & Diffie-Hellman Key Exchange**:
   - Transmissions bypass intermediate proxies, third-party relays, or intermediary cloud storage.
   - Network datalinks utilize Telegram's MTProto 2.0 with 2048-bit Diffie-Hellman ephemeral key negotiation over TLS 1.3.

2. **Zero-Knowledge Vault PIN Lock**:
   - User PINs are never stored in plaintext on disk or in volatile runtime memory.
   - PINs are cryptographically salted with a 32-byte CSPRNG salt and hashed using SHA-256 (`package:crypto`).
   - Constant-time string comparisons neutralize timing-attack surface vectors.

3. **Hostile Payload & File Header Quarantine**:
   - Prior to staging or transmission, files pass through `FileSecurityGuard`.
   - Magic bytes are inspected against strict sensor definitions (JPEG `FF D8 FF`, PNG `89 50 4E 47`, MP4 `ftyp`, DNG `49 49 2A 00`).
   - Known hostile test signatures (including EICAR test markers) and null-byte injection attempts are quarantined immediately.

4. **SQL Injection & Buffer Overflow Immunity**:
   - All relational operations in SQLite execute in WAL mode with parameterized queries (`whereArgs` placeholders).
   - Chunk size limits (500 items max per batch) prevent `SQLITE_MAX_VARIABLE_NUMBER` host limits from being exceeded.

5. **Local Sandboxing**:
   - Android storage operates strictly within scoped media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `ACCESS_MEDIA_LOCATION`).
   - Web PWA builds enforce Content Security Policy (CSP) headers and cross-origin resource isolation.

---

## Reporting a Vulnerability

We deeply appreciate the efforts of security researchers in identifying potential flaws responsibly.

### Reporting Procedure:
1. **Do NOT open a public GitHub Issue** for suspected vulnerabilities or leaked credentials.
2. Email your findings directly to the lead security maintainer at:
   **`adityakumarks2008@gmail.com`**
3. Include:
   - A descriptive summary of the vulnerability.
   - Detailed proof-of-concept (PoC) steps or exploit script.
   - Affected platform(s) (Android, iOS, Web, Windows, Linux, macOS).
   - Potential impact assessment.

### Coordinated Disclosure Timeline:
- **Initial Acknowledgment**: Within 24 hours of report receipt.
- **Triage & Reproducibility**: Within 48 hours.
- **Patch Development & Testing**: Typically 3–7 business days depending on severity.
- **Public Disclosure**: Released alongside a CVE / GitHub Security Advisory after the patch is published.
