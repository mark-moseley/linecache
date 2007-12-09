#!/usr/bin/env rake
# -*- Ruby -*-
require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'

# ------- Default Package ----------
PACKAGE_VERSION = open(File.join(File.dirname(__FILE__), 'VERSION')) do 
  |f| f.readlines[0].chomp
end

FILES = FileList[
  'README',
  'NEWS',
  'COPYING',
  'ChangeLog',
  'Rakefile',
  'AUTHORS',
  'lib/*.rb',
  'test/*.rb'
]                        

desc "Test everything."
test_task = task :test => :lib do 
  Rake::TestTask.new(:test) do |t|
    t.libs << ['./lib']
    t.pattern = 'test/test-*.rb'
    t.verbose = true
  end
end

desc "Test everything - same as test."
task :check => :test

desc "Create a GNU-style ChangeLog via svn2cl"
task :ChangeLog do
  system("svn2cl")
end

# Base GEM Specification
default_spec = Gem::Specification.new do |spec|
  spec.name = "linecache"
  
  spec.homepage = "http://rubyforge.org/projects/rocky-hacks/linecache"
  spec.summary = "Read file with caching"
  spec.description = <<-EOF
ruby-debug is a fast implementation of the standard Ruby debugger debug.rb.
It is implemented by utilizing a new Ruby C API hook.
EOF

  spec.version = PACKAGE_VERSION

  spec.author = "R. Bernstein"
  spec.email = "rockyb@rubyforge.net"
  spec.platform = Gem::Platform::RUBY
  spec.require_path = "lib"
  spec.files = FILES.to_a  

  spec.required_ruby_version = '>= 1.8.2'
  spec.date = Time.now
  spec.rubyforge_project = 'rocky-hacks'
  
  # rdoc
  spec.has_rdoc = true
  spec.extra_rdoc_files = ['README', 'lib/linecache.rb']
end

# Rake task to build the default package
  Rake::GemPackageTask.new(default_spec) do |pkg|
  pkg.need_tar = true
end

task :default => [:package]

desc "Publish linecache to RubyForge."
task :publish do 
  require 'rake/contrib/sshpublisher'
  
  # Get ruby-debug path
  ruby_debug_path = File.expand_path(File.dirname(__FILE__))

  publisher = Rake::SshDirPublisher.new("rockyb@rubyforge.org",
        "/var/www/gforge-projects/rocky-hacks/linecache", ruby_debug_path)
end

desc "Remove built files"
task :clean do
  rm_rf 'pkg'
end

# ---------  RDoc Documentation ------
desc "Generate rdoc documentation"
Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ruby-debug"
  # Show source inline with line numbers
  rdoc.options << "--inline-source" << "--line-numbers"
  # Make the readme file the start page for the generated html
  rdoc.options << '--main' << 'README'
  rdoc.rdoc_files.include('bin/**/*',
                          'lib/**/*.rb',
                          'ext/**/ruby_debug.c',
                          'README',
                          'LICENSE')
end

