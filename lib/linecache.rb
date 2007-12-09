#!/usr/bin/env ruby
# $Id$
# 
#   Copyright (C) 2007 Rocky Bernstein <rockyb@rubyforge.net>
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
# caching lines of the file on first access to the file. The common
# case where many lines are read from a single file. This can be used
# for example in a debugger to show source lines.
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
# This code is derived from the Python module of the same name.
#

# require "rubygems"
# require "ruby-debug" ; Debugger.start

# = module LineCache
# Module caching lines of a file
module LineCache
  LineCacheInfo = Struct.new(:stat, :lines, :fullname) 
 
  # Get line +lineno+ from file named +filename+. Return nil if there was
  # a problem. If a file named filename is not found, the function will
  # look for it in the $: path array.
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
  def getline(filename, lineno)
    lines = getlines(filename)
    if (1..lines.size) === lineno
        return lines[lineno-1]
    else
        return nil
    end
  end

  module_function :getline

  @@file_cache = {} # the cache

  # Clear the file cache entirely.
  def clear_file_cache()
    @@file_cache = {}
  end

  module_function :clear_file_cache

  # Read lines of +filename+ and cache the results. However +filename+ was
  # previously cached use the results from the cache.
  def getlines(filename)
    if @@file_cache.member?(filename)
        return @@file_cache[filename].lines
    else
        return update_cache(filename)
    end
  end

  module_function :getlines

  # Discard cache entries that are out of date. If +filename+ is +nil+
  # all entries in the file cache +@@file_cache+ are checked.
  def checkcache(filename=nil)
    
    if !filename
      filenames = @@file_cache.keys()
    elsif @@file_cache.member?(filename)
      filenames = [filename]
    else
      return nil
    end

    for filename in filenames
      next unless @@file_cache.member?(filename)
      fullname = @@file_cache[filename].fullname
      if File.exist?(fullname)
        cache_info = @@file_cache[filename]
        stat = File.stat(fullname)
        if cache_info.size != stat.size or cache_info.mtime != stat.mtime
          @@file_cache.delete(filename)
        end
      else
        @@file_cache.delete(filename)
      end
    end
  end

  module_function :checkcache
      
  # Update a cache entry and return its list of lines.  if something's
  # wrong, discard the cache entry, and return an empty list.
  def update_cache(filename)

    return [] unless filename

    @@file_cache.delete(filename)
      
    fullname = File.expand_path(filename)

    if File.exist?(fullname)
      stat = File.stat(fullname)
    else
      basename = File.basename(filename)

      # try looking through the search path.
      stat = nil
      for dirname in $:
        fullname = File.join(dirname, basename)
        if File.exist?(fullname)
            stat = File.stat(fullname)
            break
        end
      end
      return [] unless stat
    end
    begin
      fp = File.open(fullname, 'r')
      lines = fp.readlines()
      fp.close()
    rescue 
      ##  print '*** cannot open', fullname, ':', msg
      return []
    end
    @@file_cache[filename] = LineCacheInfo.new(File.stat(fullname), lines, 
                                               fullname)
    return lines
  end

  module_function :update_cache

end

# example usage
if __FILE__ == $0 or
    ($DEBUG and ['rdebug', 'rcov'].include?(File.basename($0)))
  lines = LineCache::getlines(__FILE__)
  line = LineCache::getline(__FILE__, 6)
  LineCache::update_cache(__FILE__)
  LineCache::checkcache(__FILE__)
  LineCache::checkcache # Check all files in the cache
  LineCache::clear_file_cache 
end
