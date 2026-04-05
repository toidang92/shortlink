class CreateShortLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :short_links do |t|
      t.string :original_url, null: false, limit: 2048
      t.string :short_code, null: false, limit: 20

      t.timestamps
    end

    add_index :short_links, :short_code, unique: true
  end
end
