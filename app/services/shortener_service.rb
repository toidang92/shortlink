class ShortenerService
  CODE_LENGTH = 6

  def self.encode(original_url)
    code = generate_code
    record = Url.create!(original_url: original_url, short_code: code)
    BloomService.add(code)
    record
  end

  def self.decode(code)
    Url.find_by(short_code: code)
  end

  def self.generate_code
    loop do
      code = SecureRandom.alphanumeric(CODE_LENGTH)

      return code unless BloomService.might_exist?(code)

      # Bloom filter says maybe exists — confirm with DB
      return code unless Url.exists?(short_code: code)
    end
  end

  private_class_method :generate_code
end
