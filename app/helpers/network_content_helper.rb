module NetworkContentHelper

  def featured_pages( source )
    # TODO: network content sorting
    if source
      return [] unless source.respond_to?(:pages) && source.pages.any?
      [ source.pages.find(:first, :order => "updated_at DESC") ].compact
    else
      find_random Page, 1
    end
  end

  def featured_users( source )
    # TODO: network content sorting
    if source
      return [] unless source.respond_to?(:users) && source.users.any?
      source.users.find(:all, :limit => 6, :order => "updated_at DESC") 
    else
      find_random User, 6
    end
  end

  def featured_groups( source=nil )
    # TODO: network content sorting
    if source
      return [] unless source.respond_to?(:groups) && source.groups.any?
      source.groups.find(:all, :limit => 6, :order => "updated_at DESC")
    else
      find_random Group, 6
    end
  end

  def find_random( klass, qty )
    ids = klass.connection.select_all("Select id from #{klass.name.tableize}")
    random_ids = []
    qty.times do
      next if ids.empty?
      random_index = rand( ids.size )
      random_ids << ids.delete_at( random_index )["id"].to_i
    end
    
    klass.find(random_ids)
  end
end
