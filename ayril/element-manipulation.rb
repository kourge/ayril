
module ElementManipulation
  def insert(insertions)
    insertions = { :bottom => insertions } if insertions.kind_of? String or
      insertions.kind_of? Integer or insertions.kind_of? XMLElement or 
      (insertions.respond_to? :to_element or insertions.respond_to? :to_html)

    insertions.each do |position, content|
      position.downcase! if position.kind_of? String
      insert = {
        :before => lambda { |element, node|
          element.parent.insertChild node, atIndex: element.index
        },
        :top => lambda { |element, node|
          element.insertChild node, atIndex: 0
        },
        :bottom => lambda { |element, node|
          element.addChild node
        },
        :after => lambda { |element, node|
          element.parent.insertChild node, atIndex: element.index + 1
        }
      }[position = position.to_sym]

      content = content.to_element if content.respond_to? :to_element
      (insert.call(self, content); next) if content.kind_of? XMLElement

      content = content.respond_to?(:to_html) ? content.to_html : content.to_s
      children = XMLElement.alloc.initWithXMLString("<root>#{content}</root>", error: nil).children
      
      children.reverse! if position == :top or position == :after
      children.each { |child| child.detach; insert.call self, child }
    end
    self
  end

  def append(e) self.insert :bottom => e end
  def prepend(e) self.insert :top => e end

  def wrap(wrapper=nil, attributes={})
    if wrapper.kind_of? XMLElement
      wrapper.write_attribute attributes
    elsif wrapper.kind_of? String
      wrapper = XMLElement.new wrapper, attributes
    else
      wrapper = XMLElement.new 'div', attributes
    end
    self.replace wrapper if self.parent
    wrapper.addChild self
    wrapper
  end

  def identify
    id = self.read_attribute "id"
    return id unless id.nil?
    begin
      id = "anonymous_element_#{XMLElement::id_counter += 1}"
    end while self.rootDocument.select("##{id}").any?
    self.write_attribute "id", id
    id
  end
end
