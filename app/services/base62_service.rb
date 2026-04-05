class Base62Service
  ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.freeze
  BASE = ALPHABET.length
  SECRET = ENV.fetch('SHORTLINK_SECRET').to_i(16)

  MASK_64 = (1 << 64) - 1

  def self.encode(id)
    obfuscated = (id ^ SECRET) & MASK_64
    to_base62(obfuscated).rjust(AppConstants::MIN_CODE_LENGTH, '0')
  end

  def self.decode(code)
    obfuscated = from_base62(code)
    (obfuscated ^ SECRET) & MASK_64
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
