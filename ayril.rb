
framework 'Cocoa'

require 'core-extensions'

require 'ayril/node-manipulation'
require 'ayril/element-manipulation'
require 'ayril/element-attribute-manipulation'

require 'ayril/selector'
require 'ayril/node-traversal'


class XMLNode < NSXMLNode
  include NodeManipulation
  include NodeTraversal
  
  def initWithKind(kind) raise NotImplementedError end
  def initWithKind(kind, options: options) raise NotImplementedError end
  
  def self.document
    XMLDocument.alloc
  end

  def self.documentWithRootElement(element)
    XMLDocument.alloc.initWithRootElement element
  end

  def self.elementWithName(name)
    XMLElement.alloc.initWithName name
  end

  def self.elementWithName(name, stringValue: string)
    XMLElement.alloc.initWithName name, stringValue: string
  end
  
  def self.elementWithName(name, children: children, attributes: attrs)
    self.elementWithName(name).tap do |e|
      attrs.kind_of?(Hash) ? e.setAttributesAsDictionary(attrs)
                           : e.setAttributes(attrs)
      e.setChildren children
    end
  end

  def self.elementWithName(name, URI: uri)
    XMLElement.alloc.initWithName name, URI: uri
  end

  def self.attributeWithName(name, stringValue: string)
    e = XMLElement.alloc.initWithName "r"
    e.setAttributesAsDictionary name => string
    (e.attributeForName name).tap { |a| a.detach }
  end
  
  def self.attributeWithName(name, URI: uri, stringValue: string)
    self.attributeWithName(name, stringValue: string).tap do |n|
      n.URI = uri
    end
  end

  def self.textWithStringValue(string)
    d = XMLDocument.initWithXMLString "<r>#{string}</r>", options: 0, error: nil
    d.rootElement.childAtIndex(0).tap { |n| n.detach }
  end

  def self.commentWithStringValue(string)
    d = XMLDocument.alloc.initWithXMLString "<r><!--#{string}--></r>", options: 0, error: nil
    d.rootElement.childAtIndex(0).tap { |n| n.detach }
  end

  def self.namespaceWithName(name, stringValue: string) raise NotImplementedError end
  def self.DTDNodeWithXMLString(string) raise NotImplementedError end
  def self.predefinedNamespaceForPrefix(prefix) raise NotImplementedError end
  def self.processingInstructionWithName(name, stringValue: string) raise NotImplementedError end

  def kind?(kind)
    return self.kind == kind if kind.kind_of? Fixnum
    kind = kind.to_sym
    kinds = %w(invalid document element attribute namespace processing_instruction comment text DTD).invoke(:to_sym)
    if kinds.include? kind
      camelcase = kind.to_s.capitalize.gsub(/_([a-z])/) { |m| m[1].upcase }
      return self.kind == Object.const_get(:"NSXML#{camelcase}Kind")
    end
    false
  end
  alias :type? :kind?

  def doc?; self.kind == NSXMLDocumentKind end

  def elem?; self.kind == NSXMLElementKind end
  alias :element? :elem?

  def attr?; self.kind == NSXMLAttributeKind end
  alias :attribute? :attr?
  
  def namespace?; self.kind == NSXMLNamespaceKind end
  def pi?; self.kind == NSXMLProcessingInstructionKind end
  def comment?; self.kind == NSXMLCommentKind end
  def text?; self.kind == NSXMLTextKind end
  def dtd?; self.kind == NSXMLDTDKind end
end


class XMLElement < NSXMLElement
  include NodeManipulation
  include NodeTraversal
  include ElementManipulation
  include ElementAttributeManipulation
  include ElementClassnameManipulation
  include ElementStyleManipulation

  @@id_counter = 0
  attr_accessor :id_counter
  
  def self.new(name, attributes={})
    if attributes.empty? and name.include? "<"
      self.alloc.initWithXMLString name, error: nil
    else
      XMLNode.elementWithName name, children: nil, attributes: attributes
    end
  end
  
  def kind; NSXMLElementKind end

  def initWithName(name)
    self.class.alloc.tap { |e| e.name = name }
  end

  def initWithName(name, stringValue: string)
    self.initWithName(name).tap { |e| e.stringValue = string }
  end

  def initWithName(name, URI: uri)
   self.initWithName(name).tap { |e| e.URI = uri }
  end

  def initWithXMLString(string, error: error)
    d = XMLDocument.alloc.initWithXMLString(string, options: 0, error: error)
    d.maybe(:rootElement).tap { |n| n.maybe :detach }
  end

  def inspect
    attributes = self.attribute.tap { |a| a.sync }
    "#<#{self.class}<#{self.name}#{attributes.maybe(:empty?) ? '' : ' '}#{attributes}>>"
  end
end


class XMLDTD < NSXMLDTD
  include NodeManipulation
end


class XMLDTDNode < NSXMLDTDNode
  include NodeManipulation
end


class XMLDocument < NSXMLDocument
  include NodeManipulation
  include NodeTraversal

  def self.new(data)
    path = data.dup
    path = NSURL.fileURLWithPath data.path if data.kind_of? File
    if path.kind_of? NSURL
      XMLDocument.alloc.initWithContentsOfURL path, options: 0, error: nil
    elsif path.kind_of? XMLElement
      XMLDocument.alloc.initWithRootElement path
    elsif path.kind_of? String
      XMLDocument.alloc.initWithXMLString path, options: 0, error: nil
    end
  end

  def self.replacementClassForClass(currentClass)
    { NSXMLNode => XMLNode,
      NSXMLElement => XMLElement,
      NSXMLDocument => XMLDocument,
      NSXMLDTD => XMLDTD,
      NSXMLDTDNode => XMLDTDNode
    }[currentClass]
  end

  forward :to_s, :XMLString

  def inspect
    "#<#{self.class}:0x#{self.object_id.to_s(16)}>"
  end
end

