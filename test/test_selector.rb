#!/usr/local/bin/macruby

def run(a)
  IO.popen(a).read
end

NORMAL = "\e[0m"
RED    = "\e[31m"
GREEN  = "\e[32m"
BLUE   = "\e[34m"

selectors = <<EOF
body
div
body div
div p
div > p
div + p
div ~ p
div[class^=exa][class$=mple]
div p a
div, p, a
.note
div.example
div.dialog.emphatic
ul .tocline2
div.example, div.note
#title
h1#title
div #title
ul.toc li.tocline2
ul.toc > li.tocline2
h1#title + div > p
h1[id]:contains(Selectors)
a[href][lang][class]
div[class]
div[class=example]
div[class^=exa]
div[class$=mple]
div[class*=e]
div[class|=dialog]
div[class!=made_up]
div[class~=example]
div:not(.example)
p:contains(selectors)
p:nth-child(even)
p:nth-child(2n)
p:nth-child(odd)
p:nth-child(2n+1)
p:nth-child(n)
p:only-child
p:last-child
p:first-child
EOF
selectors = selectors.split /\n/
VERBOSE = ARGV[0] == "--verbose"

path = File.expand_path '.'
js = File.join(path, "invoke_prototype_selector.js")
rb = File.join(path, "invoke_ayril_selector.rb")

selectors.each do |test|
  # The SpiderMonkey JavaScript shell also works
  reference = run(["java", "org.mozilla.javascript.tools.shell.Main", js, test])
  resulting = run(["macruby", rb, test])
  reference.strip!; resulting.strip!
  
  detail = "
   JS: #{BLUE}#{reference}#{NORMAL}
   RB: #{BLUE}#{resulting}#{NORMAL}"
  
  passed = (reference == resulting)
  if passed
    puts "#{GREEN}PASS#{NORMAL} ``#{test}\"" +
        (passed && VERBOSE ? "\n   #{BLUE}#{resulting}#{NORMAL}" : '')
  else
    puts "#{RED}FAIL#{NORMAL} ``#{test}\"#{detail}" + (VERBOSE ? '\n' : '')
  end
end
