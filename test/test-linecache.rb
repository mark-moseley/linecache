#!/usr/bin/env ruby
require "test/unit"
require "fileutils"
require "tempfile"

# Test LineCache module
class TestLineCache < Test::Unit::TestCase
  @@TEST_DIR = File.expand_path(File.dirname(__FILE__))
  @@TOP_SRC_DIR = File.join(@@TEST_DIR, '..', 'lib')
  require File.join(@@TOP_SRC_DIR, 'linecache.rb')
  
  def setup
    LineCache::clear_file_cache
  end
  
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

    # Write a temporary file; read contents, rewrite it and check that
    # we get a change when calling getline.
    tf = Tempfile.new("testing")
    test_string = "Now is the time.\n"
    tf.puts(test_string)
    tf.close
    line = LineCache::getline(tf.path, 1)
    assert_equal(test_string, line,
                 "C'mon - a simple line test like this worked before.")
    tf.open
    test_string = "Now is another time.\n"
    tf.puts(test_string)
    tf.close
    LineCache::checkcache
    line = LineCache::getline(tf.path, 1)
    assert_equal(test_string, line,
                 "checkcache should have reread the temporary file.")
    FileUtils.rm tf.path

    LineCache::update_cache(__FILE__)
    LineCache::clear_file_cache
  end

  def test_cached
    assert_equal(false, LineCache::cached?(__FILE__),
                 "file #{__FILE__} shouldn't be cached - just cleared cache.")
    line = LineCache::getline(__FILE__, 1)
    assert line
    assert_equal(true, LineCache::cached?(__FILE__),
                 "file #{__FILE__} should now be cached")
  end

  def test_stat
    assert_equal(nil, LineCache::stat(__FILE__),
                 "stat for #{__FILE__} shouldn't be nil - just cleared cache.")
    line = LineCache::getline(__FILE__, 1)
    assert line
    assert(LineCache::stat(__FILE__),
           "file #{__FILE__} should now have a stat")
  end

  def test_sha1
    test_file = File.join(@@TEST_DIR, 'short-file') 
    LineCache::cache(test_file)
    assert_equal('d7ae2d65d8815607ddffa005e91a8add77ef4a1e', 
                 LineCache::sha1(test_file))
  end

end
