# Base62 Encoding Algorithm

## Overview

The short code generation uses a **deterministic, collision-free** algorithm that combines XOR obfuscation with Base62 encoding to convert database auto-increment IDs into unpredictable short codes.

## Algorithm Steps

### Encode: `id -> short_code`

```
Input: id (integer from DB auto-increment)

Step 1: XOR Obfuscation
   obfuscated = id XOR SECRET
   - SECRET is a hex string from ENV, parsed as integer, masked to 35 bits
   - XOR is a bitwise bijection: each unique input maps to exactly one unique output

Step 2: 35-bit Mask
   obfuscated = obfuscated AND ((1 << 35) - 1)
   - Truncates result to 35-bit unsigned integer range [0, 2^35 - 1]
   - Ensures output < 2^35 ≈ 34B < 62^6 ≈ 56B, so Base62 always fits in 6 chars

Step 3: Base62 Conversion
   result = ""
   while obfuscated > 0:
       result = ALPHABET[obfuscated % 62] + result
       obfuscated = obfuscated / 62  (integer division)

   ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

Step 4: Padding
   short_code = result.pad_left(6, '0')
   - Why 6? The max 35-bit value fits within 6 Base62 digits:
       2^35  =         34,359,738,368  (max possible XOR result)
       62^6  =     56,800,235,584     (covers full 35-bit range)
   - Padding ensures all codes have uniform length (always 6 chars)
   - Leading '0's do not cause ambiguity (they decode back correctly)

Output: short_code (6-character Base62 string)

> **Scaling note:** To increase capacity and brute-force resistance, switch to a 64-bit mask
> for 11-character codes (62^11 ≈ 52 quadrillion). See the Capacity table below.
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

Step 3: 35-bit Mask
   id = id AND ((1 << 35) - 1)

Output: id (original database ID)
```

### Visual Flow

```
ENCODE:
  DB ID (e.g. 42)
    │
    ▼
  42 XOR SECRET (masked to 35 bits)
    │
    ▼
  & MASK_35 → obfuscated (fits in 35 bits)
    │
    ▼
  Base62(obfuscated)
    │
    ▼
  "xxxxxx" (6-char code)


DECODE:
  "xxxxxx"
    │
    ▼
  from_base62 → obfuscated
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

> **Important caveat:** If `id` exceeds the 35-bit range (> 34,359,738,367 ≈ 34 billion), the mask will truncate higher bits and **could cause collisions**. The `short_links` table uses `BIGSERIAL`, so this is a capacity limit — not a crash risk. If you approach this limit, increase to a 64-bit mask for 11-character codes (62^11 ≈ 52 quadrillion capacity).

### Why collisions are impossible

The algorithm is a **composition of bijective (one-to-one) functions**:

```
f(id) = Base62( (id XOR SECRET) AND MASK_35 )

Where:
  - XOR with a constant    → bijection (invertible: x XOR k XOR k = x)
  - AND MASK_35            → identity for IDs within 35-bit range (< 34B)
  - Base62 encoding        → bijection (unique number ↔ unique string)
  - Left-padding with '0'  → preserves uniqueness (no information loss)
```

**Proof by contradiction:**
- Assume `encode(a) == encode(b)` where `a != b`
- Then `Base62((a XOR S) & M) == Base62((b XOR S) & M)`
- Since Base62 is bijective: `(a XOR S) & M == (b XOR S) & M`
- Since a, b are within 35-bit range, masking is identity: `a XOR S == b XOR S`
- XOR both sides with S: `a == b`
- Contradiction. Therefore `encode(a) != encode(b)` for all `a != b`.

### Capacity

| Code Length | Mask | Max Unique Codes | Enough For |
|-------------|------|------------------|------------|
| **6 chars** (current) | **35-bit** | **2^35 ≈ 34 billion** | **~34B links** |
| 8 chars     | 47-bit | 2^47 ≈ 140 trillion | ~140T links |
| 11 chars    | 64-bit | 2^64 ≈ 18.4 quintillion | Theoretical DB limit |

With 6-character codes and a 35-bit mask, the system supports **~34 billion** unique short links.

> **Risk:** 6-char codes have a smaller keyspace (62^6 ≈ 56B), making brute-force enumeration more feasible than 11-char codes (62^11 ≈ 52Q). If URL privacy or capacity becomes a concern, increase `MASK` to 64-bit for 11-character codes — this is a one-line change in `Base62Service`.

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
| **Not cryptographically secure** | XOR obfuscation is not encryption; an attacker with just 1 known (id, code) pair can recover SECRET (see [Security Note](#security-note)) | Acceptable for URL shortener; not protecting sensitive data. Use FPE (FF1/FF3) or Skip32 if stronger obfuscation is needed |
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

- XOR is its own inverse: `a XOR b XOR b = a`, so `SECRET = id XOR obfuscated_code`
- An attacker who knows **just one** `(id, code)` pair can recover SECRET immediately
- With SECRET, they can decode any short code to its ID, and predict future codes

**Example attack with a single known pair:**

```ruby
# ALPHABET is public knowledge (visible in source code or easily guessable)
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

def from_base62(str)
  str.each_char.reduce(0) { |acc, char| (acc * 62) + ALPHABET.index(char) }
end

# from_base62 is just base conversion — like parseInt but base 62:
#   "9krGNW" → '9'=9, 'k'=20, 'r'=27, 'G'=42, 'N'=49, 'W'=58
#
#   9                                  =              9
#   9 * 62 + 20                        =            578
#   578 * 62 + 27                      =         35,863
#   35,863 * 62 + 42                   =      2,223,548
#   2,223,548 * 62 + 49               =    137,859,025
#   137,859,025 * 62 + 58             =  8,547,321,608

# Suppose SECRET = 8,547,321,609 (attacker does NOT know this)
# Attacker creates the first shortlink and observes:
#   id = 1,  code = "9krGNW"

# Step 1: Convert code to integer (anyone can do this)
obfuscated = from_base62("9krGNW")          # → 8,547,321,608

# Step 2: Recover SECRET (XOR is self-inverse)
secret = 1 ^ obfuscated                     # → 1 XOR 8,547,321,608 = 8,547,321,609  ✓

# Step 3: Verify with a second known pair (id=2, code="9krGNZ")
from_base62("9krGNZ") ^ secret               # → 8,547,321,611 XOR 8,547,321,609 = 2  ✓

# Step 4: Decode ANY code without knowing the ID
obfuscated = from_base62("9krK0M")
id = obfuscated ^ secret                     # → reveals the original DB ID = 12,345

# Step 5: Predict future codes for any ID
to_base62(12345 ^ secret)                    # → "9krK0M"
```

**Why only one pair is needed (not 64):**

Unlike real ciphers where known-plaintext attacks require many samples to narrow down a large key space, XOR "encryption" with a fixed key leaks the key in a single equation: `key = plaintext XOR ciphertext`. There is no key schedule, no diffusion, no rounds — just one XOR operation.

**Verification with a second pair:**

An attacker can confirm the recovered SECRET by checking a second known pair: if `id2 XOR from_base62(code2) == SECRET`, the key is confirmed with certainty.

This is acceptable because URL shorteners are not access-control mechanisms — the short code is a convenience, not a secret. If stronger obfuscation is needed, consider a format-preserving encryption (FPE) scheme like FF1/FF3, or a small block cipher like Skip32, where knowing plaintext-ciphertext pairs does not reveal the key.

If access control is needed, add authentication or per-link passwords as a separate layer.

## Worked Examples

Using `SHORTLINK_SECRET=0x5A3CF91D2E7B`:

```
SECRET (raw)    = 0x5A3CF91D2E7B = 99,234,127,601,275
SECRET (35-bit) = SECRET & ((1 << 35) - 1) = SECRET & 0x7FFFFFFFF

MASK = (1 << 35) - 1 = 34,359,738,367

The actual short codes depend on the production SECRET value.
Encode and decode are exact inverses — verification is straightforward:
  decode(encode(id)) = id for all id < 2^35
```

> **Note:** SECRET is masked to 35 bits at load time, ensuring all XOR results fit in the 6-char Base62 code space. To scale to 11-char codes, change `MASK` to `(1 << 64) - 1`.
