class ActiveRecord::Base#.class_eval do
  def self.polymorphic_attr( base_attr, options = {} )
    return unless options[:as]
    attr_types = options[:as].is_a?(Array) ? options[:as] : [ options[:as] ]
    attr_types.each do |attr_as|
      define_method("#{attr_as}?") { self.send(base_attr) and self.send(base_attr).is_a?(Object.const_get(attr_as.to_s.classify)) }
      define_method("#{attr_as}")  { self.send("#{attr_as}?") ? self.send(base_attr) : nil }
      define_method( "#{attr_as}=" ) { |value| self.send("#{base_attr}=", value ) }
    end
  end
end

