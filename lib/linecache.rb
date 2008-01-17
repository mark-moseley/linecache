#!/usr/bin/env ruby
# $Id$
# 
#   Copyright (C) 2007, 2008 Rocky Bernstein <rockyb@rubyforge.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301 USA.
#

# Author::    Rocky Bernstein  (mailto:rockyb@rubyforge.net)
#
# = linecache
# Module to read and cache lines of a file
# == Version
# :include:VERSION

# == SYNOPSIS
#
# The LineCache module allows one to get any line from any file,
# caching lines of the file on first access to the file. The may be is
# useful when a small random sets of lines are read from a single
# file, in particular in a debugger to show source lines.
#
#  require 'linecache'
#  lines = LineCache::getlines('/tmp/myruby.rb')
#  # The following lines have same effect as the above.
#  $: << '/tmp'
#  Dir.chdir('/tmp') {lines = LineCache::getlines('myruby.rb')
#
#  line = LineCache::getline('/tmp/myruby.rb', 6)
#  # Note lines[6] == line (if /tmp/myruby.rb has 6 lines)
#
#  LineCache::clear_file_cache
#  LineCache::clear_file_cache('/tmp/myruby.rb')
#  LineCache::update_cache   # Check for modifications of all cached files.
#
# Some parts of the interface is derived from the Python module of the
# same name.
#

require 'digest/sha1'

# Defining SCRIPT_LINES__ causes Ruby to cache the lines of files
# it reads. The key the setting of __FILE__ at the time when Ruby does
# its read. LineCache keeps a separate copy of the lines elsewhere
# and never destroys __SCRIPT_LINES
SCRIPT_LINES__ = {} unless defined? SCRIPT_LINES__

# require "rubygems"
# require "ruby-debug" ; Debugger.start

# = module LineCache
# Module caching lines of a file
module LineCache
  LineCacheInfo = Struct.new(:stat, :lines, :path, :sha1) unless
    defined?(LineCacheInfo)
 
  # Get line +line_number+ from file named +filename+. Return nil if
  # there was a problem. If a file named filename is not found, the
  # function will look for it in the $: path array.
  # 
  # Examples:
  # 
  #  lines = LineCache::getline('/tmp/myfile.rb)
  #  # Same as above
  #  $: << '/tmp'
  #  lines = Dir.chdir('/tmp') do 
  #     lines = LineCache::getlines ('myfile.rb')
  #  end
  #
  def getline(filename, line_number, reload_on_change=true)
    lines = getlines(filename, reload_on_change)
    if lines and (1..lines.size) === line_number
        return lines[line_number-1]
    else
        return nil
    end
  end

  module_function :getline

  # The file cache. The key is a name as would be given by Ruby for 
  # __FILE__. The value is a LineCacheInfo object. 
  @@file_cache = {} 
  
  # Maps a string full filename (a String) to name in file_cache key
  # (a String). Applications especially those that get input from users,
  # may want to map a name into a full filename and then via 
  # @@full2file_cache_key we can get the cached entry.
  @@full2file_cache_key = {} 
  
  # Clear the file cache entirely.
  def clear_file_cache()
    @@file_cache = {}
  end
  module_function :clear_file_cache

  # Return an array of cached file names
  def cached_files()
    @@file_cache.keys
  end
  module_function :cached_files

  # Read lines of +filename+ and cache the results. However +filename+ was
  # previously cached use the results from the cache. Return nil
  # if we can't get lines
  def getlines(filename, reload_on_change=false)
    checkcache(filename) if reload_on_change
    if @@file_cache.member?(filename)
      return @@file_cache[filename].lines
    else
      update_cache(filename, true)
      return @@file_cache[filename].lines if @@file_cache.member?(filename)
    end
  end

  module_function :getlines

  # Discard cache entries that are out of date. If +filename+ is +nil+
  # all entries in the file cache +@@file_cache+ are checked.
  # If we don't have stat information about a file which can happen
  # if the file was read from __SCRIPT_LINES but no corresponding file
  # is found, it will be kept. Return a list of invalidated filenames.
  # nil is returned if a filename was given but not found cached.
  def checkcache(filename=nil, use_script_lines=false)
    
    if !filename
      filenames = @@file_cache.keys()
    elsif @@file_cache.member?(filename)
      filenames = [filename]
    else
      return nil
    end

    result = []
    for filename in filenames
      next unless @@file_cache.member?(filename)
      path = @@file_cache[filename].path
      if File.exist?(path)
        cache_info = @@file_cache[filename]
        stat = File.stat(path)
        if stat && 
            (cache_info.size != stat.size or cache_info.mtime != stat.mtime)
          result << filename
          update_cache(filename, use_script_lines)
        end
      end
    end
    return result
  end
  module_function :checkcache

  # Cache filename if it's not already cached.
  # Return the expanded filename for it in the cache
  # or nil if we can't find the file.
  def cache(filename, reload_on_change=false)
    if @@file_cache.member?(filename)
      checkcache(filename) if reload_on_change
    else
      update_cache(filename, true)
    end
    if @@file_cache.member?(filename)
      @@file_cache[filename].path
    else
      nil
    end
  end
  module_function :cache
      
  # Return true if filename is cached
  def cached?(filename)
    @@file_cache.member?(filename)
  end
  module_function :cached?
      
  # Return full filename path for filename
  def path(filename)
    return nil unless @@file_cache.member?(filename)
    @@file_cache[filename].path
  end
  module_function :path

  # Return SHA1 of filename.
  def sha1(filename)
    return nil unless @@file_cache.member?(filename)
    return @@file_cache[filename].sha1.hexdigest if 
      @@file_cache[filename].sha1
    sha1 = Digest::SHA1.new
    @@file_cache[filename].lines.each do |line|
      sha1 << line
    end
    @@file_cache[filename].sha1 = sha1
    sha1.hexdigest
  end
  module_function :sha1
      
  # Return File.stat in the cache for filename.
  def stat(filename)
    return nil unless @@file_cache.member?(filename)
    @@file_cache[filename].stat
  end
  module_function :stat

  # Update a cache entry.  If something's
  # wrong, return nil. Return true if the cache was updated and false
  # if not.  If use_script_lines is true, use that as the source for the
  # lines of the file
  def update_cache(filename, use_script_lines=false)

    return nil unless filename

    @@file_cache.delete(filename)
    path = File.expand_path(filename)
    
    if use_script_lines
      list = [filename]
      list << @@full2file_cache_key[path] if 
        @@full2file_cache_key[path]
      list.each do |name| 
        if !SCRIPT_LINES__[name].nil? && SCRIPT_LINES__[name] != true
          begin 
            stat = File.stat(name)
          rescue
            stat = nil
          end
          lines = SCRIPT_LINES__[name]
          @@file_cache[filename] = LineCacheInfo.new(stat, lines, path, nil)
          @@full2file_cache_key[path] = filename
          return true
        end
      end
    end
      
    if File.exist?(path)
      stat = File.stat(path)
    elsif File.basename(filename) == filename
      # try looking through the search path.
      stat = nil
      for dirname in $:
        path = File.join(dirname, filename)
        if File.exist?(path)
            stat = File.stat(path)
            break
        end
      end
      return false unless stat
    end
    begin
      fp = File.open(path, 'r')
      lines = fp.readlines()
      fp.close()
    rescue 
      ##  print '*** cannot open', path, ':', msg
      return nil
    end
    @@file_cache[filename] = LineCacheInfo.new(File.stat(path), lines, 
                                               path, nil)
    @@full2file_cache_key[path] = filename
    return true
  end

  module_function :update_cache

end

# example usage
if __FILE__ == $0 or
    ($DEBUG and ['rcov'].include?(File.basename($0)))
  def yes_no(var) 
    return var ? "" : "not "
  end

  lines = LineCache::getlines(__FILE__)
  puts "#{__FILE__} has #{lines.size} lines"
  line = LineCache::getline(__FILE__, 6)
  puts "The 6th line is\n#{line}" 
  puts("Files cached: #{LineCache::cached_files.inspect}")
  LineCache::update_cache(__FILE__)
  LineCache::checkcache(__FILE__)
  puts("#{__FILE__} is %scached." % 
       yes_no(LineCache::cached?(__FILE__)))
  puts LineCache::stat(__FILE__).inspect
  puts "Full path: #{LineCache::path(__FILE__)}"
  LineCache::checkcache # Check all files in the cache
  LineCache::clear_file_cache 
  puts("#{__FILE__} is now %scached." % 
       yes_no(LineCache::cached?(__FILE__)))

end
