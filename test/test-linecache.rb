#!/usr/bin/env ruby
require "test/unit"

# Test of C extension ruby_debug.so
class TestLineCache < Test::Unit::TestCase
  @@TOP_SRC_DIR = File.join(File.expand_path(File.dirname(__FILE__)), 
                            '..', 'lib')
  require File.join(@@TOP_SRC_DIR, 'linecache.rb')
  
  # test current_context
  def test_basic
    fp = File.open(__FILE__, 'r')
    compare_lines = fp.readlines()
    fp.close
    
    # Test getlines to read this file.
    lines = LineCache::getlines(__FILE__)
    assert_equal(compare_lines, lines,
                 'We should get exactly the same lines as reading this file.')
    
    # Test getline to read this file. The file should now be cached,
    # so internally a different set of routines are used.
    test_line = 1
    line = LineCache::getline(__FILE__, test_line)
    assert_equal(compare_lines[test_line-1], line,
                 'We should get exactly the same line as reading this file.')
    
    # Test getting the line via a relative file name
    Dir.chdir(File.dirname(__FILE__)) do 
      short_file = File.basename(__FILE__)
      test_line = 10
      line = LineCache::getline(__FILE__, test_line)
      assert_equal(compare_lines[test_line-1], line,
                   'Short filename lookup should work')
    end

    ## FIXME: should do a better job testing update_cache.
    ## write a temporary file read contents, rewrite it and check that
    ## we get a change.
    LineCache::update_cache(__FILE__)
    LineCache::clear_file_cache
  end
end
