# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
    
  include PageUrlHelper         # provides page_url() and page_xurl()
  include UrlHelper
  include Formy                 # helps create forms
  include LayoutHelper
  include LinkHelper
  include TimeHelper
  include PathFinder::Options   # for Page.find_by_path options
    
  # use by ajax
  def notify_errors(title, errors)
     type = "error"
     img = image_tag("notice/#{type}.png")
     header = content_tag("h2", title)
     text = "<ul>" + errors.collect{|e|"<li>#{e}</li>"}.join("\n") + "</li>"
     content_tag("div", img + header + text, "class" => "notice #{type}")
  end
 
   # use by ajax
  def notify_infos(title, infos)
     type = "info"
     img = image_tag("notice/#{type}.png")
     header = content_tag("h2", title)
     text = "<ul>" + infos.collect{|e|"<li>#{e}</li>"}.join("\n") + "</li>"
     content_tag("div", img + header + text, "class" => "notice #{type}")
  end
 
  def page_icon(page)
    image_tag "#{page.icon_path}", :size => "22x22"
  end
  
  def page_icon_style(icon)
   "background: url(/images/pages/#{icon}.png) no-repeat 0% 50%; padding-left: 26px;"
  end

  def link_to_icon(text, icon, path={}, options={})
    link_to text, path, options.merge(:style => icon_style(icon))
  end

  def icon_style(icon)
    size = 16
    url = "/images/#{icon}"
    "background: url(#{url}) no-repeat 0% 50%; padding-left: #{size+8}px;"
  end
    
  def avatar_for(viewable, size='medium', options={})
    #image_tag avatar_url(:viewable_type => viewable.class.to_s.downcase, :viewable_id => viewable.id, :size => size), :alt => 'avatar', :size => Avatar.pixels(size), :class => 'avatar'
    image_tag avatar_url(:id => (viewable.avatar||0), :size => size), :alt => 'avatar', :size => Avatar.pixels(size), :class => (options[:class] || "avatar avatar_#{size}")
  end
  
  # makes this: link | link | link
  def link_line(*links)
    "<div class='link_line'>" + links.compact.join(' | ') + "</div>"
  end

  def spinner(id, options={})
    display = ("display:none;" unless options[:show])
    options = {:spinner=>"spinner.gif", :style=>"#{display} vertical-align:middle;"}.merge(options)
    "<img src='/images/#{options[:spinner]}' style='#{options[:style]}' id='#{spinner_id(id)}' alt='spinner' />"
  end
  def spinner_id(id)
    "#{id.to_s}_spinner"
  end
  def hide_spinner(id)
    "Element.hide('#{spinner_id(id)}');"
  end
  def show_spinner(id)
    "Element.show('#{spinner_id(id)}');"
  end


  # override standard url_for to cache the result.
  #alias_method :orig_url_for, :url_for
  #def url_for(options = {})
  #  @@cached_urls ||= {}
  #  return(@@cached_urls[options.to_yaml] ||= orig_url_for(options))
  #end
  
 
  def friendly_size(bytes)
    if bytes > 1.megabyte
      '%s MB' % (bytes / 1.megabyte)
    elsif bytes > 1.kilobyte
      '%s KB' % (bytes / 1.kilobyte)
    else
      '%s B' % bytes
    end
  end
  
  
  def created_modified_date(created, modified=nil)
    return friendly_date(created) unless modified and modified != created
    created_date = friendly_date(created)
    modified_date = friendly_date(modified)
    detail_string = "created:&nbsp;#{created_date}<br/>modified:&nbsp;#{modified_date}"
    link_to_function created_date, %Q[this.replace("#{detail_string}")], :class => 'dotted'
  end
  
  # TODO: allow this to be set by the theme
  def favicon
   ret = ''
   ret += '<link rel="shortcut icon" href="/favicon.ico" type="image/x-icon" />'  if File.exists?("#{RAILS_ROOT}/public/favicon.ico")
   ret += '<link rel="icon" href="/favicon.png" type="image/x-icon" />' if File.exists?("#{RAILS_ROOT}/public/favicon.ico")
  end
 
  def once?(key)
    @called_before ||= {}
    return false if @called_before[key]
    @called_before[key]=true
  end
  
  #
  # used to spit out a column value for a single row.
  # for example:
  #  page_column(page, :title)
  # this function exists so we can re-arrange the columns easily.
  #
  def page_list_cell(page, column, participation=nil)
    if column == :icon
      return page_icon(page)
    elsif column == :checkbox
      check_box('page_checked', page.id, {}, 'checked', '')
    elsif column == :title
      return page_list_title(page, column, participation)    
    elsif column == :updated_by or column == :updated_by_login
      return( page.updated_by_login ? link_to_user(page.updated_by_login) : '&nbsp;')
    elsif column == :created_by or column == :created_by_login
      return( page.created_by_login ? link_to_user(page.created_by_login) : '&nbsp;')
    elsif column == :updated_at
      return friendly_date(page.updated_at)
    elsif column == :created_at
      return friendly_date(page.created_at)
    elsif column == :happens_at
      return friendly_date(page.happens_at)
    elsif column == :group or column == :group_name
      return( page.group_name ? link_to_group(page.group_name) : '&nbsp;')
    elsif column == :contributors_count or column == :contributors
      return page.contributors_count
    elsif column == :owner
      return (page.group_name || page.created_by_login)
    elsif column == :owner_with_icon
      return page_list_owner_with_icon(page)
    else
      return page.send(column)
    end
  end

  def page_list_owner_with_icon(page)
    if page.group_id
      return link_to_group(page.group_id, :avatar => 'xsmall')
    elsif page.created_by
      return link_to_user(page.created_by, :avatar => 'xsmall')
    end
  end
  
  def page_list_title(page, column, participation = nil)
    title = link_to(page.title, page_url(page))
    if participation and participation.instance_of? UserParticipation
      title += " " + image_tag("emblems/pending.png", :size => "11x11", :title => 'pending') unless participation.resolved?
      title += " " + image_tag("emblems/star.png", :size => "11x11", :title => 'star') if participation.star?
    else
      title += " " + image_tag("emblems/pending.png", :size => "11x11", :title => 'pending') unless page.resolved?
    end
    return title
  end
  
  def page_list_heading(column=nil)
    if column == :group or column == :group_name
      list_heading 'group'.t, 'group_name'
    elsif column == :icon or column == :checkbox
      "<th></th>"
    elsif column == :updated_by or column == :updated_by_login
      list_heading 'updated by'.t, 'updated_by_login'
    elsif column == :created_by or column == :created_by_login
      list_heading 'created by'.t, 'created_by_login'
    elsif column == :updated_at
      list_heading 'updated'.t, 'updated_at'
    elsif column == :created_at
      list_heading 'created'.t, 'created_at'
    elsif column == :happens_at
      list_heading 'happens'.t, 'happens_at'
    elsif column == :contributors_count or column == :contributors
      #"<th>" + image_tag('ui/person-dark.png') + "</th>"
      list_heading image_tag('ui/person-dark.png'), 'contributors_count'
    elsif column
      list_heading column.to_s.t, column.to_s
    end    
  end

  #
  # Often when you run a page search, you will get an array of UserParticipation
  # or GroupParticipation objects. 
  #
  # This method will convert the array to Pages if they are not.
  #
  def array_of_pages(pages)
    if pages
      if pages.first.is_a? Page
        return pages
      else
        return pages.collect{|p|p.page}
      end
    end
  end
  
  def issue_url(issue)
  	issue 
  end

  # Unobtrusive version of link_to_remote
  def link_to_remote( name, options, html_options={} )
    html_options[:class] = "remote #{html_options.delete(:class)}".strip
    link_to(name, options, html_options)
  end

  def jquery_javascript_includes
    javascript_include_tag( 'jquery/jquery' ) +
    javascript_include_tag( 'jquery/jquery.dimensions.js' )+
    javascript_include_tag( 'jquery/enchant/fx' )+
    javascript_tag( 'jQuery.noConflict();' )+
    javascript_include_tag( 'jquery/enchant/fx.slide.js' )
  end

  def load_javascript_tabs
    content_for :javascript, jquery_javascript_includes +
      javascript_include_tag('tabs') +
      javascript_tag( 'Event.observe( document, "dom:loaded", Crabgrass.Tabs.initialize_tab_blocks);' )
    
  end
  
end
