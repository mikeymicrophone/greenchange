#####################################################
#
# FORMY -- a form creator for rails
#
# <%=
# form :option => value do
#   title "My Form"
#   label "Mail Client"
#   row :option => value do
#     info "info about this row"
#     label "row label"
#     input text_field('object','method')
#   end
# end
# %>

# a form consistants of a tree of elements. 
# each element may contain other elements. 
# in the close method of each element, the element
# must render its contents to its local string buffer. 
# the parent element then uses that buffer when doing
# its own rendering.

module Formy
  # <% _erbout << "foo" %>
  # <% concat("foo", binding) %>
  
  def self.define_formy_keywords
    # could be replaced with method missing?
    form_word :title, :row, :label, :info, :heading, :input, :section, :spacer,
       :checkbox, :tab, :link, :selectedx
  end
  
  def self.create(options={})
    @@base = f = Form.new(options)
    f.open
    yield f
    f.close
    f.to_s
  end
  def self.form(options={},&block); self.create(options,&block); end
  
  def self.tabs(options={})
    @@base = f = Tabset.new(options)
    f.open
    yield f
    f.close
    f.to_s
  end
    
  # sets up form keywords. when a keyword is called,
  # it tries to call this method on the current form element. 
  def self.form_word(*keywords)
    for word in keywords
      word = word.id2name
      module_eval <<-"end_eval"
      def #{word}(options=nil,&block)
        e = @@base.current_element.last
        return unless e
        unless e.respond_to? "#{word}"
          @@base.puts "<!-- FORM ERROR: '" + e.classname + "' does not have a '#{word}' -->"
          return
        end
        return e.#{word}(options,&block) if block_given?
        return e.#{word}(options) if options
        return e.#{word}() 
      end
      end_eval
    end
  end
  
  def method_missing(method_name)
    word = method_name.id2name
    e = @@base.current_element.last
    return unless e
    unless e.respond_to? word
      @@base.puts "<!-- FORM ERROR: '" + e.classname + "' does not have a '#{word}' -->"
      return
    end
    return e.send(word,options,&block) if block_given?
    return e.send(word,options) if options
    return e.send(word) 
  end
  
  def url_to_hash(url)
    path = url.to_s.split('/')[(3..-1)]
    ActionController::Routing::Routes.recognize_path(path)
  end
   
  class Buffer
    def initialize
      @data = ""
    end
    def <<(str)
      @data << str.to_s
    end
    def to_s
      @data
    end
  end
  
  class Element
    def initialize(form,options={})
      @base = form
      @options = options
      @elements = []                     # sub elements held by this element
      @buffer = Buffer.new
    end
    # takes "object.attribute" or "attribute" and spits out the
    # correct object and attribute strings.
    def get_object_attr(object_dot_attr)
      object =  object_dot_attr[/^([^\.]*)\./, 1] || @base.options['object'] 
      attr = object_dot_attr[/([^\.]*)$/]
      return [object,attr]
    end
    def push
      @base.depth += 1
      @base.current_element.push(self)
    end
    def pop
      @base.depth -= 1
      @base.current_element.pop
    end
    def open
      puts "<!-- begin #{self.classname} -->"
      push
    end
    def close
      pop
      puts "<!-- end #{self.classname} -->"
    end
    def classname
      self.class.to_s[/[^:]*$/].downcase
    end
    def to_s
      @buffer.to_s
    end
    def raw_puts(str)
      @buffer << str
    end
    def indent(str)
      ("  " * @base.depth) + str + "\n"
    end
    def puts(str)
      @buffer << indent(str)
    end
  
    def self.sub_element(*element_names)
      for e in element_names
        e = e.id2name
        module_eval <<-"end_eval"
        def #{e}(options={})
          element = #{e.capitalize}.new(@base,options)
          element.open
          yield element
          element.close
          @elements << element
        end
        end_eval
      end
    end
    def self.element_attr(*attr_names)
      for a in attr_names
        a = a.id2name
        module_eval <<-"end_eval"
        def #{a}(value=nil)
          if block_given? 
            @#{a} = yield
          else
            @#{a} = value
          end
        end
        end_eval
      end
    end
    
  end
  
  class Root < Element
    attr_accessor :depth, :current_element
    attr_reader :options

    def initialize(options={})
      super(self,options)
      @depth = 0
      @base = self
      @current_element = [self]
    end
  end
  
  class Tabset < Root
    sub_element :tab

    def open
      super
      puts "<div><ul id='tabnav'>"
    end
    
    def close
      @elements.each {|e| raw_puts e}
      puts "<li></li></ul></div>"
      super
    end  
  end
  
  class Tab < Element
    element_attr :label, :link, :selectedx
    
    def close
      javascript = "id='@id' href='#' onclick='showtab(event.target)'"
      #hash = url_to_hash(@link)
      selected = @selectedx ? 'selected' : ''
      puts "<li class='tab'><a class='tab-link #{selected}' href='#{@link}'>#{@label}</a></li>"
      super
    end
  end
    
  class Form < Root
    sub_element :row, :section
    
    def title(value)
      puts "<tr class='title'><td colspan='3'>#{value}</td></tr>"
    end
    
    def label(value="&nbsp;")
      @elements << indent("<tr class='label'><td colspan='3'>#{value}</td></tr>")
    end
    
    def spacer
      @elements << indent("<tr class='spacer'><td colspan='3'><div></div></td></tr>")
    end
      
    def open
      super
      puts "<table class='form'>"
      title(@options[:title]) if @options[:title]
    end
    
    def close
      @elements.each {|e| raw_puts e}
      puts "</table>"
      super
    end  
  end
    
  class Section < Element
    sub_element :row
    
    def label(value)
      puts "label(#{value})<br>"
    end

  end
  
  class Row < Element
    element_attr :info, :label, :input, :heading
    sub_element :checkbox
	
    def open
      super
      puts "<tr class='row'>"
    end
    
    def close
      @input ||= @elements.first.to_s
      labelspan = inputspan = infospan = 1
      labelspan = 2 if @label and not @input
      inputspan = 2 if @input and not @label and     @info
      inputspan = 2 if @input and     @label and not @info
      infospan  = 2 if @info  and     @label and not @input
      labelspan = 3 if @label and not @input and not @info
      inputspan = 3 if @input and not @label and not @info
      infospan  = 3 if @info  and not @label and not @input
      puts "<td colspan='#{labelspan}' class='label'>#{@label}</td>" if @label
      if @input =~ /\n/
        puts "<td colspan='#{inputspan}' class='input'>"
        raw_puts @input
        puts "</td>"
      else
        puts "<td colspan='#{inputspan}' class='input'>#{@input}</td>"
      end
      puts "<td colspan='#{infospan}' class='info'>#{@info}</td>"   if @info
      puts "</tr>"      
      super
    end
  end  
  
  class Checkbox < Element
    element_attr :label, :input
    
    def close
      id = @input.match(/id=["'](.*?)["']/).to_a[1] if @input
      label = "<label for='#{id}'>#{@label}</label>"
      puts "<table cellpadding='0' cellspacing='0'><tr><td>#{@input}</td><td>#{label}</td></tr></table>"
      super
    end
  end
  
  
  class Item < Element
    element_attr :object, :field, :label
    def to_s
      "<label>#{@field} #{@label}</label>"
    end
  end

end

