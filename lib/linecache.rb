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
  LineCacheInfo = Struct.new(:stat, :lines, :fullname, :sha1)
 
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
    if (1..lines.size) === line_number
        return lines[line_number-1]
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
  def getlines(filename, reload_on_change=false)
    checkcache(filename) if reload_on_change
    if @@file_cache.member?(filename)
        return @@file_cache[filename].lines
    else
        return update_cache(filename, true)
    end
  end

  module_function :getlines

  # Discard cache entries that are out of date. If +filename+ is +nil+
  # all entries in the file cache +@@file_cache+ are checked.
  # If we don't have stat information about a file which can happen
  # if the file was read from __SCRIPT_LINES but no corresponding file
  # is found, it will be kept.
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
        if stat && 
            (cache_info.size != stat.size or cache_info.mtime != stat.mtime)
          @@file_cache.delete(filename)
        end
      else
        @@file_cache.delete(filename)
      end
    end
  end
  module_function :checkcache

  # Cache filename if it's not already cached.
  # Return the expanded filename for it in the cache
  # or nil if we can't find the file.
  def cache(filename, reload_on_change=false)
    if @@file_cache.member?(filename)
      checkcache(filename) if reload_on_change
    else
      return update_cache(filename, true)
    end
    if @@file_cache.member?(filename)
      @@file_cache[filename].fullname
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
      
  # Return SHA1 of filename.
  def sha1(filename)
    return nil unless @@file_cache.member?(filename)
    return @@file_cache[filename].sha1.hexdigest if 
      @@file_cache[filename].sha1
    sha1 = Digest::SHA1.new
    @@file_cache[filename].lines.each do |line|
      sha1 << line
    end
    @@file.cache[file.name].sha1 = sha1
    sha1.hexdigest
  end
  module_function :sha1
      
  # Return File.stat in the cache for filename.
  def stat(filename)
    return nil unless @@file_cache.member?(filename)
    @@file_cache[filename].stat
  end
  module_function :stat

  # Update a cache entry and return its list of lines.  if something's
  # wrong, discard the cache entry, and return an empty list.
  # If use_script_lines is true, try to get the 
  def update_cache(filename, use_script_lines=false)

    return [] unless filename

    @@file_cache.delete(filename)
    fullname = File.expand_path(filename)
    
    if use_script_lines
      [filename, fullname].each do |name| 
        if !SCRIPT_LINES__[name].nil? && SCRIPT_LINES__[name] != true
          begin 
            stat = File.stat(name)
          rescue
            stat = nil
          end
          lines = SCRIPT_LINES__[name]
          @@file_cache[filename] = LineCacheInfo.new(stat, lines, fullname, nil)
          return lines
        end
      end
    end
      
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
                                               fullname, nil)
    return lines
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
  LineCache::update_cache(__FILE__)
  LineCache::checkcache(__FILE__)
  puts("#{__FILE__} is %scached." % 
       yes_no(LineCache::cached?(__FILE__)))
  LineCache::stat(__FILE__).inspect
  LineCache::checkcache # Check all files in the cache
  LineCache::clear_file_cache 
  puts("#{__FILE__} is now %scached." % 
       yes_no(LineCache::cached?(__FILE__)))

end
