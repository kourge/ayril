
module NodeManipulation
  # Removes node from parent and return the removed node itself.
  def remove
    self.tap { |e| e.parent.removeChildAtIndex e.index }
  end
  
  # Updates the content of node. If passed nothing or a blank string, the 
  # children are cleared. If passed a string, the string is parsed into 
  # element(s). Passing an element or an array of elements is good. All 
  # elements are first detached if possible.
  def update(content='')
    if content == ''; children = nil
    elsif content.respond_to? :to_s
      children = XMLElement.alloc.initWithXMLString("<r>#{content}</r>", 
        error: nil).children
    elsif content.kind_of? XMLElement; children = [content]
    end
    children.each { |child| child.detach } if not children.nil?
    self.setChildren children
  end
  
  # Replaces a node with another node and returns the old node.
  def replace(content)
    content = content.to_elem if content.respond_to? :to_elem
    self.parent.replaceChildAtIndex self.index, withNode: content
    self
  end
  alias :swap :replace
  
  # Clean the whitespace of the node, i.e. remove all of its children text nodes
  # that contain only whitespace.
  def clean_whitespace
    node = self.childAtIndex 0
    while node
      next_node = node.nextSibling
      node.remove if node.kind == NSXMLTextKind and node.stringValue =~ /\S/
      node = next_node
    end
    self
  end
  
  forward :xpath, :XPath

  forward :text, :stringValue
  forward :text=, :stringValue=

  forward :to_html, :XMLString
  def inner_html; self.children.invoke(:XMLString).join end
end

