# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "nesta-plugin-wordpress/version"

Gem::Specification.new do |s|
  s.name        = "nesta-plugin-wordpress"
  s.version     = Nesta::Plugin::Wordpress::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nathanael Jones"]
  s.email       = ["nathanael.jones@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Allows easy migration from Wordpress without losing pagerank.}
  s.description = %q{Allows easy migration from Wordpress without losing pagerank.}

  s.rubyforge_project = "nesta-plugin-wordpress"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency("nesta", ">= 0.9.11")
  s.add_development_dependency("rake")
  s.add_development_dependency("hpricot")
  s.add_development_dependency("nokogiri")
  
  
end
