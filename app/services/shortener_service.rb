class ShortenerService
  def self.encode(original_url)
    id = ActiveRecord::Base.connection.execute("SELECT nextval('short_links_id_seq')").first['nextval']
    code = Base62Service.encode(id)
    record = ShortLink.new(id: id, original_url: original_url, short_code: code)
    record.save!(validate: false)
    record
  end

  def self.decode(code)
    return nil if code.blank?
    return nil unless code&.match?(/\A[a-zA-Z0-9]+\z/)
    return nil if code.length < AppConstants::MIN_CODE_LENGTH

    id = Base62Service.decode(code)
    record = ShortLink.find_by(id: id)
    record if record&.short_code == code
  end
end
