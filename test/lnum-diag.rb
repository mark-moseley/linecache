#!/usr/bin/env ruby

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
  end
  first_line = fp.readline.chomp
  fp.close()
  expected_str = first_line[1..-1]
  begin
    expected_lnums = eval(expected_str, binding, __FILE__, __LINE__)
  rescue
    assert nil, "Failed reading expected values from #{f}"
  else
    got_lnums = TraceLineNumbers.lnums_for_str(lines)
    puts expected_lnums.inspect
    puts '-' * 80
    if got_lnums != expected_lnums
      puts got_lnums.inspect
    else
      puts 'Got what was expected'
    end
  end
end

ARGV.each do |file| 
  dump_file(file, true)
end
