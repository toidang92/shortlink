class Base62Service
  ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.freeze
  BASE = ALPHABET.length

  # 35-bit mask ensures XOR output < 2^35 ≈ 34B < 62^6 ≈ 56B, so Base62 always fits in 6 chars
  MASK = (1 << 35) - 1

  # SECRET prevents sequential ID enumeration: without it, code = Base62(id),
  # so id=1 → "000001", id=2 → "000002", etc. — trivially guessable.
  # XOR with SECRET scrambles the mapping so codes appear random to casual observers.
  # Note: This is obfuscation, not encryption — see docs/BASE62_ALGORITHM.md#security-note
  SECRET = ENV.fetch('SHORTLINK_SECRET').to_i(16) & MASK

  def self.encode(id)
    obfuscated = (id ^ SECRET) & MASK
    to_base62(obfuscated).rjust(AppConstants::MIN_CODE_LENGTH, '0')
  end

  def self.decode(code)
    obfuscated = from_base62(code)
    (obfuscated ^ SECRET) & MASK
  end

  def self.to_base62(num)
    return ALPHABET[0] if num.zero?

    result = +''
    while num.positive?
      result.prepend(ALPHABET[num % BASE])
      num /= BASE
    end
    result
  end

  def self.from_base62(str)
    str.each_char.reduce(0) { |acc, char| (acc * BASE) + ALPHABET.index(char) }
  end

  private_class_method :to_base62, :from_base62
end
