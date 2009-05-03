#!/usr/local/bin/macruby

require '../core-extensions'
require '../ayril/selector'

puts Selector.new($*[0]).xpath
