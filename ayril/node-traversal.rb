
module NodeTraversal
  # Recursively collects the results of a method until nil is returned.
  def recursively_collect(property)
    elements = []; element = self
    while element = element.send(property)
      elements << element if element.kind == NSXMLElementKind
    end
    elements
  end
  
  # Returns all ancestors of a node.
  def ancestors
    self.recursively_collect :parent
  end
  
  # Returns all descendants of a node, direct or indirect.
  def descendants
    self.select "*"
  end
  
  # Returns the first descendant element of a node.
  def first_descendant
    element = self.childAtIndex 0
    while element and element.kind != NSXMLElementKind
      element = element.nextSibling
    end
    element
  end

  # Returns the direct children of a node.
  def immediate_descendants
    return [] unless (element = self.childAtIndex 0)
    while element and element.kind != NSXMLElementKind
      element = element.nextSibling
    end
    return [element] + element.next_siblings unless element.nil?
    []
  end
  alias :child_elements :immediate_descendants
  
  def previous_siblings
    self.recursively_collect :previousSibling
  end

  def previous_element_sibling
    element = self.previousSibling
    while element and element.kind != NSXMLElementKind
      element = element.previousSibling
    end
    element
  end

  def next_siblings
    self.recursively_collect :nextSibling
  end

  def next_element_sibling
    element = self.nextSibling
    while element and element.kind != NSXMLElementKind
      element = element.nextSibling
    end
    element
  end

  def siblings
    self.previous_siblings.reverse + self.next_siblings
  end

  def up(*args)
    expr, index = args[0..1]
    return self.parent if args.length == 0
    if expr.kind_of? Integer then self.ancestors[expr]
    else Selector.find_element(self.ancestors, expr, index) end
  end

  def down(*args)
    expr, index = args[0..1]
    return self.first_descendant if args.length == 0
    if expr.kind_of? Integer then self.descendants[expr]
    else self.select(expr)[index || 0] end
  end
  alias :find :down
  alias :search :down

  def previous(*args)
    expr, index = args[0..1]
    return self.previous_element_sibling if args.length == 0
    expr.kind_of?(Integer) ? self.previous_siblings[expr] : 
      Selector::find_element(self.previous_siblings, expr, index)
  end

  def next(*args)
    expr, index = args[0..1]
    return self.next_element_sibling if args.length == 0
    expr.kind_of?(Integer) ? self.next_siblings[expr] :
      Selector::find_element(self.next_siblings, expr, index)
  end

  def select(css)
    self.select_by_xpath(Selector.new(css.to_s).xpath).to_a
  end
  alias :elements_by_selector :select
  alias :[] :select # REXML inspired

  def at(css)
    self.select(css)[0]
  end
  alias :% :at
  
  def select_by_xpath(xpath)
    self.nodesForXPath(xpath.to_s, error: nil).to_a
  end
  alias :/ :select_by_xpath # Hpricot inspired

  def adjacent(*args)
    Selector.find_child_elements(self.parent, args) - [self]
  end

  def empty?
    self.descendants.invoke(:XMLString).join('') == ''
  end

  def descendant_of?(ancestor)
    element = self
    while element = element.parent
      return true if element == ancestor
    end
    false
  end

  def contains?(child)
    child.descendant_of? self
  end
end
