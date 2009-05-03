

class XMLAttributeHash < Hash
  def initialize(element)
    @element = element
    self.sync
  end

  def sync
    cache = {}
    @element.attributes.each { |a| cache[a.name] = a.stringValue } if not @element.attributes.nil?
    self.delete_if { true }.merge! cache
  end
  
  def store(k, v)
    attr = @element.attributeForName k
    if not attr.nil?
      attr.stringValue = v
    else
      @element.addAttribute XMLNode.attributeWithName(k, stringValue: v)
    end
    super k, v
  end
  alias :set :store
  alias :[]= :store

  def fetch(k); @element.attributeForName(k).maybe :stringValue end
  alias :get :fetch
  alias :[] :fetch
  
  def has_key?(k); not @element.attributeForName(k).nil? end
  alias :has? :has_key?
  alias :include? :has_key?
  alias :key? :has_key?
  alias :member? :has_key?

  def delete(k); @element.removeAttributeForName k; super k end
  alias :remove :delete
  alias :- :delete

  def _delete_if(&blk); self.each { |k, v| self.delete k if blk.call k, v } end
  def delete_if(&blk); self._delete_if &blk; self end

  def reject!(&blk)
    old = self.dup; self._delete_if &blk
    (self == old) ? nil : self
  end
  
  def replace(hash); @element.setAttributesAsDictionary hash; super hash end
  def clear; self.replace {} end

  def merge!(hash); hash.each { |k, v| self[k] = v }; self end
  alias :update! :merge!
  alias :+ :merge!
  
  def to_s; self.map { |k, v| "#{k}=\"#{v}\"" }.join ' ' end
  def inspect; "#<#{self.class} #{self.to_s}>" end
end


module ElementAttributeManipulation
  def attribute
    @attributes.nil? ? (@attributes = XMLAttributeHash.new self) : @attributes
  end
  alias :attr :attribute
  
  def attribute=(hash); self.setAttributesAsDictionary hash end
  alias :attr= :attribute=
  alias :set :attribute=

  def read_attribute(k); self.attributeForName(k.to_s).maybe(:stringValue) end
  alias :get_attribute :read_attribute
  alias :[] :read_attribute

  def write_attribute(k, v=nil)
    if v.nil? and k.kind_of? Hash
      k.each { |a, b| self.write_attribute a.to_s, b } unless k.empty?
      return self
    end
    attr = self.attributeForName(k)
    if attr.nil?
      self.addAttribute XMLNode.attributeWithName(k.to_s, stringValue: v)
    else
      attr.stringValue = v
    end
    self
  end
  alias :add_attribute :write_attribute
  alias :set_attribute :write_attribute
  alias :[]= :write_attribute

  def remove_attribute(a) self.removeAttributeForName(a.to_s); self.sync end
  alias :delete_attribute :remove_attribute

  def has_attribute?(k); not self.attributeForName(k.to_s).nil? end
end


module ElementClassnameManipulation
  def has_class_name?(class_name)
    classes = self.read_attribute "class"
    !!(classes.length > 0 and (classes == class_name or 
       classes =~ /(^|\s)#{class_name}(\s|$)/))
  end
  
  def add_class_name(class_name)
    if not self.has_class_name? class_name
      current = if not self.has_attribute? "class" then ''
                else self.read_attribute("class") end
    end
    self.write_attribute "class", (current + ((current == '') ? '' : ' ') + class_name)
    self
  end

  def remove_class_name(class_name)
    return self if not self.has_attribute? "class"
    string_value = self.read_attribute("class").sub(/(^|\s+)#{class_name}(\s+|$)/, ' ').strip
    string_value == '' ? self.remove_attribute("class")
                       : self.write_attribute("class", string_value)
    self.tap { |s| s.attribute.sync; s.class_names.sync }
  end
  
  def toggle_class_name(class_name)
    if self.has_class_name? class_name
    then self.remove_class_name class_name
    else self.add_class_name class_name end
  end
end


class XMLCSSHash < Hash
  def initialize(element)
    if not (@element = element).has_attribute? "style"
      @element.write_attribute "style", ''
    end
    css = @element.read_attribute "style"
    css.gsub(/\n/, '').split(';').invoke(:strip).compact.each do |property|
      property.split(':').tap { |p| self[p.shift] = p.join(':').strip }
    end.tap { sync }
  end

  def to_css; self.map { |k, v| "#{k}: #{v}" }.join "; " end
  alias :to_s :to_css

  def inspect; "#<#{self.class} {#{self.to_css}}>" end
  
  def store(k, v) super(k, v).tap { sync } end
  alias :[]= :store

  def fetch(k) super(k).tap { sync } end
  alias :[] :fetch

  def delete(k) super(k).tap { sync } end
  alias :- :delete

  def delete_if(&blk) super(&blk).tap { sync } end
  def reject!(&blk) super(&blk).tap { sync } end
  def replace(h) super(h).tap { sync } end
  def clear; super.tap { sync } end

  def merge!(h) super(h).tap { sync } end
  alias :update! :merge!
  alias :+ :merge!

  def sync
    @element.removeAttributeForName("style") and return if self.size == 0
    @element.write_attribute "style", self.to_css
  end

  alias :include? :has_key?
  alias :key? :has_key?
  alias :member? :has_key?
end


module ElementStyleManipulation
  def style; XMLCSSHash.new self end
  def style=(h) self.style.replace h end

  def get_style(prop) self.style[style] end
  def set_style(style, value) self.style[style] = value end
end

