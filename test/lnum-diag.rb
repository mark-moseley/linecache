#!/usr/bin/env ruby

require 'tracer'
# begin require 'rubygems' rescue LoadError end
# require 'ruby-debug' ; Debugger.start

TEST_DIR = File.expand_path(File.dirname(__FILE__))
TOP_SRC_DIR = File.join(TEST_DIR, '..')
require File.join(TOP_SRC_DIR, 'lib', 'tracelines.rb')

def dump_file(file, print_file=false)
  puts file
  fp = File.open(file, 'r')
  lines = fp.read
  if print_file
    puts '=' * 80
    puts lines
    puts '=' * 80
    fp.rewind
    cmd = "#{File.join(TEST_DIR, 'parse-show.rb')} #{file}"
    system(cmd)
    puts '=' * 80
    tracer = Tracer.new
    tracer.add_filter lambda {|event, f, line, id, binding, klass|
      __FILE__ != f
    }
    tracer.on{load(file)}
  else
    fp.rewind
  end
  first_line = fp.readline.chomp
  fp.close()
  expected_str = first_line[1..-1]
  begin
    expected_lnums = eval(expected_str, binding, __FILE__, __LINE__)
  rescue SyntaxError
    puts '=' * 80
    puts "Failed reading expected values from #{file}"
    expected_lnums = nil
  end
  got_lnums = TraceLineNumbers.lnums_for_str(lines)
  puts expected_lnums.inspect
  puts '-' * 80
  if expected_lnums 
    if got_lnums != expected_lnums
      puts got_lnums.inspect
    else
      puts 'Got what was expected'
    end
  else
    puts got_lnums.inspect
  end
end

ARGV.each do |file| 
  dump_file(file, true)
end
