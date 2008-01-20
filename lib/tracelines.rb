#!/usr/bin/env ruby
# $Id$
begin require 'rubygems' rescue LoadError end
require 'parse_tree'
# require 'ruby-debug' ; Debugger.start

module TraceLineNumbers
  # Return an array of lines numbers given a ParseTree array.
  def line_numbers_for_a(ary)
    result = []
    ary.each_with_index do |elt, i|
      case elt
      when Array
        line_nums = line_numbers_for_a(elt).flatten
        result += line_nums unless line_nums.empty?
      when Symbol
        if 0 == i and :newline == elt 
          result << ary[i+1]
          # Skip line number and file name. We really don't need to do
          # this since it should be ignored by the rest of the
          # code. But I think I want to be explicit.
          i += 2 
        end
      else
      end
    end
    result
  end
  module_function :line_numbers_for_a

  # Return an array of lines numbers that could be 
  # stopped at given a string of a Ruby program.
  def line_numbers_for_string(ruby, filename='*bogus*')
    parse_tree = ParseTree.new(true)
    a = parse_tree.parse_tree_for_string(ruby, filename)
    # We could use a special uniq routine since
    # line numbers are sorted.
    line_numbers_for_a(a).uniq
  end
  module_function :line_numbers_for_string

  # Return an array of lines numbers that could be 
  # stopped at given a file name of a Ruby program.
  def line_numbers_for_file(file)
    line_numbers_for_string(File.read(file), file)
  end
  module_function :line_numbers_for_file

  # Return an array of lines numbers that could be 
  # stopped at given a file name of a Ruby program.
  # We assume the each line has \n at the end. If not 
  # set the newline parameters to \n.
  def line_numbers_for_string_array(string_array, filename='*bogus*', 
                                    newline='')
    line_numbers_for_string(string_array.join(newline), filename)
  end
  module_function :line_numbers_for_string_array
end

if __FILE__ == $0
  SCRIPT_LINES__ = {} unless defined? SCRIPT_LINES__
  test_file = '../test/rcov-bug.rb'
  if  File.exists?(test_file)
    puts TraceLineNumbers.line_numbers_for_file(test_file).inspect 
    load(test_file, 0) # for later
  end
  puts TraceLineNumbers.line_numbers_for_file(__FILE__).inspect
  unless SCRIPT_LINES__.empty?
    key = SCRIPT_LINES__.keys.first
    puts key
    puts SCRIPT_LINES__[key]
    puts TraceLineNumbers.line_numbers_for_string_array(SCRIPT_LINES__[key]).inspect
  end
end
