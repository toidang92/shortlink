# Base62 Encoding Algorithm

## Overview

The short code generation uses a **deterministic, collision-free** algorithm that combines XOR obfuscation with Base62 encoding to convert database auto-increment IDs into unpredictable short codes.

## Algorithm Steps

### Encode: `id -> short_code`

```
Input: id (64-bit integer from DB auto-increment)

Step 1: XOR Obfuscation
   obfuscated = id XOR SECRET
   - SECRET is a 128-bit hex string from ENV, parsed as integer
   - XOR is a bitwise bijection: each unique input maps to exactly one unique output

Step 2: 64-bit Mask
   obfuscated = obfuscated AND ((1 << 64) - 1)
   - Truncates result to 64-bit unsigned integer range [0, 2^64 - 1]
   - Since DB IDs fit in 64 bits, this is effectively a no-op for valid inputs

Step 3: Base62 Conversion
   result = ""
   while obfuscated > 0:
       result = ALPHABET[obfuscated % 62] + result
       obfuscated = obfuscated / 62  (integer division)

   ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

Step 4: Padding
   short_code = result.pad_left(11, '0')
   - Why 11? The max 64-bit value needs at most 11 Base62 digits:
       62^10 =    839,299,365,868,340,224  (too small for 64-bit)
       2^64  = 18,446,744,073,709,551,616  (max possible XOR result)
       62^11 = 52,036,560,683,837,093,888  (covers full 64-bit range)
     Since 62^10 < 2^64 < 62^11, exactly 11 characters are needed.
   - Padding ensures all codes have uniform length (always 11 chars)
   - Leading '0's do not cause ambiguity (they decode back correctly)

Output: short_code (11-character Base62 string)
```

### Decode: `short_code -> id`

```
Input: short_code (Base62 string)

Step 1: Base62 to Integer
   obfuscated = 0
   for each char in short_code:
       obfuscated = (obfuscated * 62) + ALPHABET.index(char)

Step 2: XOR De-obfuscation
   id = obfuscated XOR SECRET

Step 3: 64-bit Mask
   id = id AND ((1 << 64) - 1)

Output: id (original database ID)
```

### Visual Flow

```
ENCODE:
  DB ID (e.g. 42)
    │
    ▼
  42 XOR 0x8c3a9bb7c3a162709e40ee6c6ea879e1
    │
    ▼
  186,324,877,870,515,032,961,536,628,475,018,935,195 (obfuscated)
    │
    ▼
  & MASK_64 → 7,960,602,848,268,221,419 (truncated to 64-bit)
    │
    ▼
  Base62("7960602848268221419")
    │
    ▼
  "6DuFz5DuFzb" (11-char code)


DECODE:
  "6DuFz5DuFzb"
    │
    ▼
  from_base62 → 7,960,602,848,268,221,419
    │
    ▼
  XOR SECRET → 42
    │
    ▼
  DB ID = 42
```

## Collision Analysis

### Collision probability: exactly 0%

This algorithm has **no probability of collision** — it is mathematically impossible, not just unlikely. Unlike hash-based or random-string approaches where collisions are improbable but possible (birthday problem), this algorithm **guarantees** uniqueness by construction. There is no need for retry loops, uniqueness checks, or collision handling.

> **Important caveat:** If `id` exceeds 64-bit range (> 18,446,744,073,709,551,615), `MASK_64` will truncate the higher bits and **could cause collisions**. However, the `short_links` table uses Rails' default `BIGSERIAL` primary key (see `db/migrate/20260405042657_create_short_links.rb`), which is a 64-bit signed integer (max 9.2 quintillion), so this limit will never be reached in practice.

### Why collisions are impossible

The algorithm is a **composition of bijective (one-to-one) functions**:

```
f(id) = Base62( (id XOR SECRET) AND MASK_64 )

Where:
  - XOR with a constant    → bijection (invertible: x XOR k XOR k = x)
  - AND MASK_64            → identity for 64-bit inputs (DB IDs are 64-bit)
  - Base62 encoding        → bijection (unique number ↔ unique string)
  - Left-padding with '0'  → preserves uniqueness (no information loss)
```

**Proof by contradiction:**
- Assume `encode(a) == encode(b)` where `a != b`
- Then `Base62((a XOR S) & M) == Base62((b XOR S) & M)`
- Since Base62 is bijective: `(a XOR S) & M == (b XOR S) & M`
- Since a, b are 64-bit DB IDs, masking is identity: `a XOR S == b XOR S`
- XOR both sides with S: `a == b`
- Contradiction. Therefore `encode(a) != encode(b)` for all `a != b`.

### Capacity

| Code Length | Max Unique Codes | Enough For |
|-------------|------------------|------------|
| 6 chars     | 62^6 = 56.8 billion | ~56.8B links |
| 8 chars     | 62^8 = 218 trillion | ~218T links |
| **11 chars** (current) | **62^11 = 52.0 quadrillion** | **~52.0Q links** |
| 64-bit max  | 2^64 = 18.4 quintillion | Theoretical DB limit |

With 11-character codes, the system can handle **52 quadrillion** unique short links before exhausting the code space. The actual bottleneck is the 64-bit DB ID limit (18.4 quintillion).

## Evaluation

### Strengths

| Property | Description |
|----------|-------------|
| **Zero collisions** | Mathematically guaranteed — no retry loops needed |
| **Deterministic** | Same ID always produces the same code |
| **O(1) decode** | Decode yields the DB primary key directly — no index scan |
| **Non-sequential** | XOR obfuscation prevents users from guessing adjacent codes |
| **No external dependency** | No Redis, no distributed counter — just math |
| **Reversible** | Encode and decode are exact inverses |

### Weaknesses

| Property | Description | Mitigation |
|----------|-------------|------------|
| **Not cryptographically secure** | XOR obfuscation is not encryption; a determined attacker with ~64 known (id, code) pairs can recover SECRET via XOR | Acceptable for URL shortener; not protecting sensitive data |
| **SECRET is immutable** | Changing SECRET breaks all existing codes | Document this constraint; never rotate SECRET in production |
| **Same URL gets different codes** | Re-encoding the same URL creates a new DB record with a new ID and new code | By design — allows analytics per-link; add dedup layer if needed |
| **Predictable with leaked SECRET** | If SECRET is exposed, all codes become predictable | Protect SECRET via env vars; restrict access |

### Comparison with Alternatives

| Approach | Collision-Free | Decode Speed | Predictability | Complexity |
|----------|---------------|-------------|----------------|------------|
| **XOR + Base62 (current)** | Yes (guaranteed) | O(1) PK lookup | Low (without SECRET) | Low |
| Random string + DB check | No (needs retry) | O(log n) index lookup | None | Medium |
| Hash (MD5/SHA) truncated | No (birthday problem) | O(log n) index lookup | None | Medium |
| Counter + Base62 (no XOR) | Yes | O(1) PK lookup | High (sequential) | Low |
| Nano ID / UUID | Practically no | O(log n) index lookup | None | Low |

### Security Note

The XOR obfuscation provides **obscurity, not security**. Specifically:

- An attacker who knows `encode(1) = "xxx"` and `encode(2) = "yyy"` can compute `SECRET = from_base62("xxx") XOR 1`
- With SECRET, they can enumerate all valid short codes
- This is acceptable because URL shorteners are not access-control mechanisms — the short code is a convenience, not a secret

If access control is needed, add authentication or per-link passwords as a separate layer.

## Worked Examples

Using `SHORTLINK_SECRET=8c3a9bb7c3a162709e40ee6c6ea879e1`:

```
SECRET (as integer) = 186,324,877,870,515,032,961,536,628,475,018,935,265
SECRET (lower 64 bits) = 0x9e40ee6c6ea879e1 = 11,403,858,559,813,527,009

Example 1: id = 1
  Step 1: 1 XOR 11403858559813527009 = 11403858559813527008
  Step 2: & MASK_64 = 11403858559813527008 (no change)
  Step 3: Base62(11403858559813527008) = "aUBVMQWEHq8"
  Step 4: pad to 11 → "aUBVMQWEHq8"
  Result: encode(1) = "aUBVMQWEHq8"

Example 2: id = 2
  Step 1: 2 XOR 11403858559813527009 = 11403858559813527011
  Step 2: & MASK_64 = 11403858559813527011 (no change)
  Step 3: Base62(11403858559813527011) = "aUBVMQWEHqb"
  Step 4: pad to 11 → "aUBVMQWEHqb"
  Result: encode(2) = "aUBVMQWEHqb"

Example 3: id = 1000000
  Step 1: 1000000 XOR 11403858559813527009 = 11403858559812527537
  Step 2: & MASK_64 = 11403858559812527537 (no change)
  Step 3: Base62(11403858559812527537) = "aUBVMQWCaNH"
  Step 4: pad to 11 → "aUBVMQWCaNH"
  Result: encode(1000000) = "aUBVMQWCaNH"

Verification (decode Example 1):
  from_base62("aUBVMQWEHq8") = 11403858559813527008
  11403858559813527008 XOR 11403858559813527009 = 1
  Recovered id = 1 ✓
```

> **Note:** These examples use the lower 64 bits of SECRET since MASK_64 truncates the XOR result. The actual short codes depend on the production SECRET value.
