class CreateUserParticipations < ActiveRecord::Migration
  def self.up
    create_table :user_participations do |t|
      t.column :page_id,   :integer
      t.column :user_id,   :integer
      t.column :folder_id, :integer
      t.column :access,    :integer
      t.column :read_at,   :datetime
      t.column :wrote_at,  :datetime
      t.column :watch,     :boolean
      t.column :star,      :boolean
      t.column :resolved,  :boolean
      t.column :message_count, :integer, :default => 0
    end
  end

  def self.down
    drop_table :user_participations
  end
end
