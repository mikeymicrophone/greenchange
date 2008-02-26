##
## serialize_as
## ---------------------------------
##
## usage:
##
## class Tree < ActiveRecord::Base
##   serialize_as IntArray, :branches, :roots
## end
##
## In this case, the column 'branches' will be serialized and unserialized
## using the IntArray.to_s and IntArray.new methods (respectively).
##
## It would be cool if I made this into a plugin, but then again, a lot
## of things would be cool.
##
## initialized_by
## ---------------------------------
##
## usage:
##
## class Tree < ActiveRecord::Base
##   initialized_by :my_method, :my_attribute
## end
##
## In this case, my_method() will be called each time my_attribute()
## is accessed if my_attribute is nil.
##

ActiveRecord::Base.class_eval do

  def self.serialize_as(klass, *keywords)
    for word in keywords
      word = word.id2name
      module_eval <<-"end_eval"
        def #{word}=(value)
          @#{word} = #{klass.to_s}.new(value)
          write_attribute('#{word}', @#{word}.to_s)
        end
        def #{word}
          @#{word} ||= #{klass.to_s}.new( read_attribute('#{word}') )
        end
      end_eval
    end
  end
  
  def self.initialized_by(method, *attributes)
    method = method.id2name
    for attribute in attributes
      attribute = attribute.id2name
      module_eval <<-"end_eval"
        alias_method :#{attribute}_without_initialize, :#{attribute}
        def #{attribute}
          self.#{method}() if read_attribute('#{attribute}').nil?
          #{attribute}_without_initialize()
        end
      end_eval
    end
  end
  
end

ActiveRecord::Base.class_eval do
  
  # used to auto-format body  
  def self.format_attribute(attr_name)
    #class << self; include ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper, WhiteListHelper; end
    define_method(:body)       { read_attribute attr_name }
    define_method(:body_html)  { read_attribute "#{attr_name}_html" }
    define_method(:body_html=) { |value| write_attribute "#{attr_name}_html", value }
    before_save do |record|
      unless record.body.blank?
        record.body.strip!
        if record.respond_to?('group_name')
          record.body_html = GreenCloth.new(record.body,record.group_name).to_html
        else
          record.body_html = GreenCloth.new(record.body).to_html
        end
      end
    end
  end
  
  def dom_id
    [self.class.name.downcase.pluralize.dasherize, id] * '-'
  end
  
  # make sanitize_sql public so we can use it ourselves
  def self.public_sanitize_sql(condition)
    sanitize_sql(condition)
  end
  
  # class_attribute()
  #
  # Used by Page in order to allow subclasses (ie Tools) to define themselves
  # (ie icon, description, etc) by setting class attributes.
  #
  # <example>
  #   class Page
  #     class_attribute :color
  #   end
  #   class Wiki < Page
  #     color 'blue'
  #   end
  # </example>
  #
  # class_inheritable_accessor is very close to what we want. However, when
  # an attr is defined with class_inheritable_accessor, the accessor is not
  # called when it appears in a class definition, and I don't understand why.
  #
  def self.class_attribute(*keywords)
    for word in keywords
      word = word.id2name
      module_eval <<-"end_eval"
        def self.#{word}(value=nil)
          @#{word.sub '?',''} = value if value
          @#{word.sub '?',''}
        end
        def #{word}
          self.class.#{word.sub '?',''}
        end
      end_eval
    end
  end

  #
  # TRACK CHANGES
  #
  # it allows you to tell when an attribute has
  # been changed. example usage:
  # 
  # class User < ActiveRecord::Base
  #    track_changes :username, :password
  #    after_save :reset_changed  # if you want 
  #    def before_save
  #      if changed? :username
  #        do_something_with old_value(:username)
  #      end
  #    end
  # end
  #
  # TODO: track changes currenlty only works with simple attributes,
  #       not with associations!!!
  #
  # this code is here because originally the acts_as_modified plugin
  # did not work with ruby 1.8. I wrote to the author about this and
  # he released a new versions that works with 1.8. So, there we should
  # probably eliminate this code and just use the plugin:
  # 
  # http://svn.viney.net.nz/things/rails/plugins/acts_as_modified/
  # 
  # This plugin is currently installed and used by some models.
  #
  def self.track_changes(*attr_names)
    attr_names.each do |attr_name|
      define_method "#{attr_name}=" do |value|
        write_changed_attribute attr_name.to_sym, value
      end
    end
  end

  def changed
    @changed || reset_changed
  end

  def reset_changed
    @changed = Hash.new(false)
  end
  
  def old_value(key)
    changed[key.to_sym]
  end
  
  def write_changed_attribute(attr_name, value)
    old_value = self.send(attr_name)
    write_attribute attr_name, value
    changed[attr_name.to_sym] = old_value if self.send(attr_name) != old_value
  end
    
  def changed?(attr_name = nil)
    return changed.any? unless attr_name
    begin
      changed.fetch(attr_name.to_sym)
      return true
    rescue IndexError
      return false
    end
  end

end


class ActionView::Base

# It is nice to be able to have multiple submit buttons.
# For non-ajax, this works fine: you just check the existance
# in the params of the :name of the submit button.
# For ajax, this breaks, and is labelled wontfix
# http://dev.rubyonrails.org/ticket/3231
# this hack is an attempt to get around the limitation

  alias_method :rails_submit_tag, :submit_tag
  def submit_tag(value = "Save changes", options = {})
    options[:id] = (options[:id] || options[:name] || :commit)
    options.update(:onclick => "Form.getInputs(this.form, 'submit').each(function(x) { if (x.value != this.value) x.name += '_not_pressed'; else x.name = x.name.gsub('_not_pressed','')}.bind(this))")
    rails_submit_tag(value, options)
  end
  
# i really want to be able to use link_to(:id => 'group+name') and not have
# it replace '+' with some ugly '%2B' character.

  alias_method :rails_link_to, :link_to
  def link_to(name, options = {}, html_options = nil, *parameters_for_method_reference)
     rails_link_to(name, options, html_options, parameters_for_method_reference).sub('%2B','+')
  end
  
end



#
# validates_handle makes sure that 
# (1) the handle is in a good format
# (2) the handle is not taken by an existing group or user
# (3) the handle does not collide with our routes or controllers
# 

module ActiveRecord
  module Validations
    module ClassMethods
      def validates_handle(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:invalid], :on => :save, :with => nil }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          unless value
            record.errors.add(attr_name, 'must exist')
            next #can't use return cause it raises a LocalJumpError
          end
          unless (3..50).include? value.length
            record.errors.add(attr_name, 'must be at least 3 and no more than 50 characters')
          end
          unless /^[a-z0-9]+([-\+_]*[a-z0-9]+){1,49}$/ =~ value
            record.errors.add(attr_name, 'may only contain letters, numbers, underscores, and hyphens')
          end
          unless record.instance_of?(Committee)
            # only allow '+' for Committees
            if /\+/ =~ value
              record.errors.add(attr_name, 'may only contain letters, numbers, underscores, and hyphens')
            end
          end
          if value =~ /^(groups|me|people|networks|places|avatars|page|pages|account|static|places|assets|files|chat)$/
            record.errors.add(attr_name, 'is already taken')
          end
          # TODO: make this dynamic so this function can be
          # used over any set of classes (instead of just User, Group)
          if record.instance_of? User
            if User.exists?(['login = ? and id <> ?', value, record.id||-1])
              record.errors.add(attr_name, 'is already taken')
            end
            if Group.exists?({:name => value})
              record.errors.add(attr_name, 'is already taken')
            end
          elsif record.instance_of? Group
            if Group.exists?(['name = ? and id <> ?', value, record.id||-1])
              record.errors.add(attr_name, 'is already taken')
            end
            if User.exists?({:login => value})
              record.errors.add(attr_name, 'is already taken')
            end
          end
        end
      end
    end   
  end
end
