class CreateUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :urls do |t|
      t.string :original_url, null: false, limit: 2048
      t.string :short_code, null: false, limit: 10

      t.timestamps
    end

    add_index :urls, :short_code, unique: true
    add_index :urls, :original_url
  end
end
