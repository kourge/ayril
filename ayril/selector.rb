
class Selector
  attr_reader :expr, :xpath
  @@cache = {}

  def initialize(expr)
    @expr = expr.strip
    self.compile_xpath_matcher
  end
  
  def compile_xpath_matcher
    e = @expr.dup; le = nil
    return (@xpath = @@cache[e]) if @@cache.include? e

    @matcher = [".//*"]
    while (e != '') and (le != e) and (e =~ /\S/)
      le = e.dup
      Selector::Patterns.each do |pattern|
        n = Selector::XPath[pattern[:name]]
        if m = e.match(pattern[:re])
          m = m.to_a unless m.nil?
          @matcher << (n.kind_of?(Proc) ? n.call(m) : n.interpolate(m))
          e.sub! m[0], ''
          break
        end
      end
    end

    @xpath = @matcher.join
    @@cache[@expr] = @xpath.gsub! %r{\*?\[name\(\)='([a-zA-Z]+)'\]}, '\1'
  end

  def find_elements(root)
    root.select_by_xpath @xpath
  end

  def match?(element)
    @tokens = []
    
    e = @expr.dup; le = nil
    while (e != '') and (le != e) and (e =~ /\S/)
      le = e.dup
      Selector::Patterns.each do |pattern|
        if m = e.patch(pattern[:re])
          m = m.to_a unless m.nil?
          if Selector::Assertions.include? name
            @tokens << [pattern[:name], m.clone]
            e.sub! m[0], ''
          else # resort to whole document
            return self.find_elements(element.rootDocument).include? element
          end
        end
      end
    end

    match = true
    @tokens.each do |token|
      name, matches = token[0..1]
      if not Selector::Assertions[name].call self, matches
        match = false
        break
      end
    end
    match
  end

  def to_s
    @expr
  end

  def inspect
    "#<Selector:#{@expr.inspect}>"
  end
  

  XPath = {
    :descendant =>   "//*",
    :child =>        "/*",
    :adjacent =>     "/following-sibling::*[1]",
    :laterSibling => '/following-sibling::*',
    :tagName =>      lambda { |m|
      return '' if m[1] == '*'
      "[name()='" + m[1] + "']"
    },
    :className =>    "[contains(concat(' ', @class, ' '), ' \#{1} ')]",
    :id =>           "[@id='\#{1}']",
    :attrPresence => lambda { |m|
      m[1].downcase!
      "[@\#{1}]".interpolate(m)
    },
    :attr => lambda { |m|
      m[1].downcase!
      m[3] = m[5] || m[6]
      Selector::XPath[:operators][m[2]].interpolate(m)
    },
    :pseudo => lambda { |m|
      h = Selector::XPath[:pseudos][m[1]]
      return '' if h.nil?
      return h.call(m) if h.kind_of? Proc
      Selector::XPath[:pseudos][m[1]].interpolate(m)
    },
    :operators => {
      '='  => "[@\#{1}='\#{3}']",
      '!=' => "[@\#{1}!='\#{3}']",
      '^=' => "[starts-with(@\#{1}, '\#{3}')]",
      '$=' => "[substring(@\#{1}, (string-length(@\#{1}) - string-length('\#{3}') + 1))='\#{3}']",
      '*=' => "[contains(@\#{1}, '\#{3}')]",
      '~=' => "[contains(concat(' ', @\#{1}, ' '), ' \#{3} ')]",
      '|=' => "[contains(concat('-', @\#{1}, '-'), '-\#{3}-')]"
    },
    :pseudos => {
      'first-child' => '[not(preceding-sibling::*)]',
      'last-child' =>  '[not(following-sibling::*)]',
      'only-child' =>  '[not(preceding-sibling::* or following-sibling::*)]',
      'empty' =>       "[count(*) = 0 and (count(text()) = 0)]",
      'checked' =>     "[@checked]",
      'disabled' =>    "[(@disabled) and (@type!='hidden')]",
      'enabled' =>     "[not(@disabled) and (@type!='hidden')]",
      'not' => lambda { |m|
        e = m[6]; le = nil; exclusion = []
        while (e != '') and (le != e) and (e =~ /\S/)
          le = e.dup
          Selector::Patterns.each do |pattern|
            n = Selector::XPath[pattern[:name]]
            if m = e.match(pattern[:re])
              v = n.kind_of?(Proc) ? n.call(m) : n.interpolate(m)
              exclusion << ('(' + v[1, v.length - 2] + ')')
              e.gsub! m[0], ''
              break
            end
          end
        end      
        "[not(" + exclusion.join(" and ") + ")]"
      },
      'nth-child' =>      lambda { |m| 
        Selector::XPath[:pseudos]['nth'].call("(count(./preceding-sibling::*) + 1) ", m)
      },
      'nth-last-child' => lambda { |m|
        Selector::XPath[:pseudos]['nth'].call("(count(./following-sibling::*) + 1) ", m)
      },
      'nth-of-type' =>    lambda { |m|
        Selector::XPath[:pseudos]['nth'].call("position() ", m)
      },
      'nth-last-of-type' => lambda { |m|
        Selector::XPath[:pseudos]['nth'].call("(last() + 1 - position()) ", m)
      },
      'first-of-type' =>  lambda { |m| 
        m[6] = "1"; Selector::XPath[:pseudos]['nth-of-type'].call(m)
      },
      'last-of-type' =>   lambda { |m|
        m[6] = "1"; Selector::XPath[:pseudos]['nth-last-of-type'].call(m)
      },
      'only-of-type' =>   lambda { |m|
        p = Selector::XPath[:pseudos]
        p['first-of-type'].call(m) + p['last-of-type'].call(m)
      },
      'nth' => lambda { |fragment, m|
        mm = nil; formula = m[6]; predicate = nil
        formula = '2n+0' if formula == 'even'
        formula = '2n+1' if formula == 'odd'
        return "[#{fragment}= #{mm[1]}]" if mm = formula.match(/^(\d+)$/) # digit only
        if mm = formula.match(/^(-?\d*)?n(([+-])(\d+))?/).to_a # an+b
          mm[1] = -1 if mm[1] == '-'
          # in JS: mm => ['n', undefined, undefined, undefined, undefined]
          # in RB: mm => ['n', '', nil, nil, nil]
          mm[1] = nil if mm[0] == 'n' # edge case
          a = mm[1] ? mm[1].to_i : 1
          b = mm[2] ? mm[2].to_i : 0
          "[((#{fragment} - #{b}) mod #{a} = 0) and ((#{fragment} - #{b}) div #{a} >= 0)]"
        end
      }
    }    
  }

  Patterns = [
    # combinators must be listed first
    # (and descendant needs to be last combinator)
    { :name => :laterSibling, :re => %r{^\s*~\s*}  },
    { :name => :child,        :re => %r{^\s*>\s*}  },
    { :name => :adjacent,     :re => %r{^\s*\+\s*}  },
    { :name => :descendant,   :re => %r{^\s}  },

    # selectors follow
    { :name => :tagName,      :re => %r{^\s*(\*|[\w\-]+)(\b|$)?}  },
    { :name => :id,           :re => %r{^#([\w\-\*]+)(\b|$)}  },
    { :name => :className,    :re => %r{^\.([\w\-\*]+)(\b|$)}  },
    { :name => :pseudo,       :re => %r{^:((first|last|nth|nth-last|only)(-child|-of-type)|empty|checked|(en|dis)abled|not)(\((.*?)\))?(\b|$|(?=\s|[:+~>]))}  },
    { :name => :attrPresence, :re => %r{^\[((?:[\w-]+:)?[\w-]+)\]}  },
    { :name => :attr,         :re => %r{\[((?:[\w-]*:)?[\w-]+)\s*(?:([!^$*~|]?=)\s*((['"])([^\4]*?)\4|([^'"][^\]]*?)))?\]} }
  ]

  Assertions = {
    "tagName" => lambda { |element, matches|
       matches[1].upcase == element.name.upcase
    },

    "className" => lambda { |element, matches|
       element.has_class_name? matches[1]
    },

    "id" => lambda { |element, matches|
       element.read_attribute("id") == matches[1]
    },

    "attrPresence" => lambda { |element, matches|
       element.has_attribute? matches[1]
    },

    "attr" => lambda { |element, matches|
      value = element.read_attribute matches[1]
      value and Selector::Operators[matches[2]].call(value, matches[5] || matches[6])
    }
  }

  Operators = {
    '=' =>  lambda { |nv, v| nv == v },
    '!=' => lambda { |nv, v| nv != v },
    '^=' => lambda { |nv, v| nv == v or (nv and nv.start_with? v) },
    '$=' => lambda { |nv, v| nv == v or (nv and nv.end_with? v) },
    '*=' => lambda { |nv, v| nv == v or (nv and nv.include? v) },
    '~=' => lambda { |nv, v| " #{nv} ".include? " #{v} " },
    '|=' => lambda { |nv, v| "-#{(nv || '').upcase}-".include? "-#{(v || '').upcase}-" }    
  }

  def self.split(expression)
    expressions = []
    expression.scan(/(([\w#:.~>+()\s-]+|\*|\[.*?\])+)\s*(,|$)/) do |m|
      expressions << m[1].strip
    end
    expressions
  end

  def self.match_elements(elements, expression)
    elements & elements[0].rootDocument.select(expression)
  end

  def self.find_element(elements, *rest)
    expression, index = rest[0], rest[1]
    (expression = nil; index = expression) if expression.kind_of? Integer
    Selector::match_elements(elements, expression || '*')[index || 0]
  end

  def self.find_child_elements(element, expressions)
    Selector::split(expressions.join(',')).map do |expression|
      Selector.new(expression.strip).find_elements(element)
    end.uniq.flatten
  end
end



