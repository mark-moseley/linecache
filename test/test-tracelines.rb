#!/usr/bin/env ruby
# $Id$
require 'test/unit'
require 'fileutils'
require 'tempfile'

# require 'rubygems'
# require 'ruby-debug'; Debugger.start

SCRIPT_LINES__ = {} unless defined? SCRIPT_LINES__
# Test TestLineNumbers module
class TestLineNumbers1 < Test::Unit::TestCase
  @@TEST_DIR = File.expand_path(File.dirname(__FILE__))
  @@TOP_SRC_DIR = File.join(@@TEST_DIR, '..', 'lib')
  require File.join(@@TOP_SRC_DIR, 'tracelines.rb')
  
  def test_for_file
    test_file = File.join(@@TEST_DIR, 'rcov-bug.rb')
    rcov_lines = TraceLineNumbers.lnums_for_file(test_file)
    assert_equal([2, 9], rcov_lines)
  end

  def test_for_string
    string = "# Some rcov bugs.\nz = \"\nNow is the time\n\"\n\nz =~ \n     /\n      5\n     /ix\n"
    rcov_lines = TraceLineNumbers.lnums_for_str(string)
    assert_equal([2, 9], rcov_lines)
  end

  def test_for_string_array
    test_file = File.join(@@TEST_DIR, 'rcov-bug.rb')
    load(test_file, 0) # 
    rcov_lines = TraceLineNumbers.lnums_for_str_array(SCRIPT_LINES__[test_file])
    assert_equal([2, 9], rcov_lines)
  end
end
