class Asset < ActiveRecord::Base
  # thanks mephisto
  # used for extra mime types that dont follow the convention
  @@extra_content_types = { :audio => ['application/ogg'], :movie => ['application/x-shockwave-flash'], :pdf => ['application/pdf'] }.freeze
  cattr_reader :extra_content_types

  class << self
    def image?(content_type)
      content_type.to_s =~ /^image/
    end

    def movie?(content_type)
      content_type.to_s =~ /^video/ || extra_content_types[:movie].include?(content_type)
    end
    alias :video? :movie?

    def audio?(content_type)
      content_type.to_s =~ /^audio/ || extra_content_types[:audio].include?(content_type)
    end

    def other?(content_type)
      ![:image, :movie, :audio].any? { |a| send("#{a}?", content_type) }
    end

    def pdf?(content_type)
      extra_content_types[:pdf].include? content_type
    end

    def document?(content_type)
      content_type.to_s =~ /^text/ || pdf?( content_type )
    end
  end

  TYPES = [:image, :movie, :video, :audio, :pdf, :document, :other]
  TYPES.each do |content|
    define_method("#{content}?") { self.class.send("#{content}?", content_type) }
  end

  def display_type_name
    TYPES.find do |type_check| 
      send("#{type_check}?".to_sym) 
    end
  end

  def display_class
    %w[ video image audio document ].find( lambda{ 'Asset' } ) do |type_check| 
      send("#{type_check}?") 
    end.classify
  end

  ## associations #####################################

  belongs_to :parent_page, :foreign_key => 'page_id', :class_name => 'Page'
  has_one :page, :as => :data
  #def page
  #  pages.first || parent_page
  #end

  ## versions #########################################
  
  # both this class and the versioned class use attachment_fu
  acts_as_versioned do
    def self.included(klass)
      klass.has_attachment :storage => :file_system, :max_size => 10.megabytes,
        :thumbnails => {:small => "24x24>", :medium => '48x48>', :standard => "64x64>", :large => "92x92>", :preview => "128x128>", :pic => "250x250", :display => "500x500" }
      klass.validates_as_attachment
    end
  end
  def save_version_on_create_with_thumbnails_excluded
    save_version_on_create_without_thumbnails_excluded unless parent_id
  end
  alias_method_chain :save_version_on_create, :thumbnails_excluded

  # when cloning a model, we need to set the new versions file data
  def clone_versioned_model_with_file_data(orig_model, new_model)
    clone_versioned_model_without_file_data(orig_model, new_model)
    return if orig_model.new_record?
    new_model.temp_data = orig_model.temp_data || (File.read(orig_model.full_filename) if File.exists?(orig_model.full_filename))
  end
  alias_method_chain :clone_versioned_model, :file_data

  def destroy_file_with_versions_directory
    FileUtils.rm_rf(File.join(full_dirpath, 'versions'))
    destroy_file_without_versions_directory
  end
  alias_method_chain :destroy_file, :versions_directory
  
  versioned_class.class_eval do
    delegate :page, :small_icon, :big_icon, :icon, :to => :asset
    def public_filename(thumbnail = nil)
      "/assets/#{asset.id}/versions/#{version}/#{thumbnail_name_for(thumbnail)}"
    end
    def full_filename(thumbnail = nil)
      version = self.version || parent.version
      File.join(@@file_storage, *partitioned_path('versions', version.to_s, thumbnail_name_for(thumbnail)))
    end
    def attachment_path_id
      asset.attachment_path_id if asset
    end
    def asset_with_parent
      asset_without_parent || parent.asset
    end
    alias_method_chain :asset, :parent
  end


  ## methods #########################################
  
  @@file_storage = "#{RAILS_ROOT}/assets"
  cattr_accessor :file_storage
  @@public_storage = "#{RAILS_ROOT}/public/assets"
  FileUtils.mkdir_p @@public_storage unless File.exists?(@@public_storage)
  cattr_accessor :public_storage

  def full_filename(thumbnail = nil)
    File.join(@@file_storage, *partitioned_path(thumbnail_name_for(thumbnail)))
  end

  def update_access
    if public?
      FileUtils.ln_s(full_dirpath_no_symlinks, public_dirpath) unless File.exists?(public_dirpath)
    else
      remove_symlink
    end
  end

  before_destroy :remove_symlink
  def remove_symlink
    FileUtils.rm_f(public_dirpath) if File.exists?(public_dirpath)
  end
  
  def public?
    return page.public? if page
    return parent_page.public? if parent_page
    true
  end

  def public_filename(thumbnail = nil)
    "/assets/#{id}/#{thumbnail_name_for(thumbnail)}"
  end

  def public_filepath
    "#{public_storage}/#{id}/#{filename}"
  end

  def public_dirpath
    File.dirname(public_filepath)
  end

  def full_dirpath
    File.dirname(full_filename)
  end

  def full_dirpath_no_symlinks
    Pathname.new( full_dirpath ).realpath
  end

  def extname
    File.extname(filename)
  end
  alias :suffix :extname

  def basename
    File.basename(filename, File.extname(filename))
  end
  
  def big_icon
    "mime/big/#{icon}"
  end

  def small_icon
    "mime/small/#{icon}"
  end
  
  def icon
    ctype = content_type.to_s.sub(/\/x\-/,'/')  # remove x-
    cgroup = ctype.sub(/\/.*$/,'/')              # everything after /
    iconname = @@mime_to_icon_map[ctype] || @@mime_to_icon_map[cgroup] || @@mime_to_icon_map['default']
    "#{iconname}.png"
  end
    
  @@mime_to_icon_map = {
    'default' => 'default',
    
    'text/' => 'text',
    'text/html' => 'html',
    'application/rtf' => 'rtf',
    
    'application/pdf' => 'pdf',
    'application/bzpdf' => 'pdf',
    'application/gzpdf' => 'pdf',
    'application/postscript' => 'pdf',
    
    'text/spreadsheet' => 'spreadsheet',
    'application/gnumeric' => 'spreadsheet',
    'application/kspread' => 'spreadsheet',
        
    'application/scribus' => 'doc',
    'application/abiword' => 'doc',
    'application/kword' => 'doc',
    
    'application/msword' => 'msword',
    'application/mswrite' => 'msword',
    'application/vnd.ms-powerpoint' => 'mspowerpoint',
    'application/vnd.ms-excel' => 'msexcel',
    'application/vnd.ms-access' => 'msaccess',
    
    'application/executable' => 'binary',
    'application/ms-dos-executable' => 'binary',
    'application/octet-stream' => 'binary',
    
    'application/shellscript' => 'shell',
    'application/ruby' => 'ruby',
        
    'application/vnd.oasis.opendocument.spreadsheet' => 'oo-spreadsheet',    
    'application/vnd.oasis.opendocument.spreadsheet-template' => 'oo-spreadsheet',
    'application/vnd.oasis.opendocument.formula' => 'oo-spreadsheet',
    'application/vnd.oasis.opendocument.chart' => 'oo-spreadsheet',
    'application/vnd.oasis.opendocument.image' => 'oo-graphics',    
    'application/vnd.oasis.opendocument.graphics' => 'oo-graphics',
    'application/vnd.oasis.opendocument.graphics-template' => 'oo-graphics',
    'application/vnd.oasis.opendocument.presentation-template' => 'oo-presentation',
    'application/vnd.oasis.opendocument.presentation' => 'oo-presentation',
    'application/vnd.oasis.opendocument.database' => 'oo-database',
    'application/vnd.oasis.opendocument.text-web' => 'oo-html',
    'application/vnd.oasis.opendocument.text' => 'oo-text',
    'application/vnd.oasis.opendocument.text-template' => 'oo-text',
    'application/vnd.oasis.opendocument.text-master' => 'oo-text',
    
    'packages/' => 'archive',
    'application/zip' => 'archive',
    'application/gzip' => 'archive',
    'application/rar' => 'archive',
    'application/deb' => 'archive',
    'application/tar' => 'archive',
    'application/stuffit' => 'archive',
    'application/compress' => 'archive',
        
    'video/' => 'video',

    'audio/' => 'audio',
    
    'image/' => 'image',
    'image/svg+xml' => 'vector',
    'image/svg+xml-compressed' => 'vector',
    'application/illustrator' => 'vector',
    'image/bzeps' => 'vector',
    'image/eps' => 'vector',
    'image/gzeps' => 'vector',
    
    'application/pgp-encrypted' => 'lock',
    'application/pgp-signature' => 'lock',
    'application/pgp-keys' => 'lock'
  }
end
