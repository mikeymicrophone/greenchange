class CreateGroupParticipations < ActiveRecord::Migration
  def self.up
    create_table :group_participations do |t|
	  t.column :group_id, :integer
	  t.column :page_id, :integer
	  t.column :access, :integer
	end
  end

  def self.down
    drop_table :group_participations
  end
end
