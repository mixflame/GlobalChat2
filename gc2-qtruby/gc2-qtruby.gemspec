# -*- encoding: utf-8 -*-
require File.expand_path('../lib/gc2-qtruby/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jonathan \"jsilver1er\" Silverman"]
  gem.email         = ["jsilverone@me.com"]
  gem.description   = %q{GlobalChat 2 Pro Chat Client}
  gem.summary       = %q{QTRuby crossplatform version}
  gem.homepage      = "http://globalchat2.net"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = 'globalchat'
  gem.add_dependency('qtbindings', '>= 4.8.3.0')
  gem.name          = "globalchat"
  gem.require_paths = ["."]
  gem.version       = Gc2::Qtruby::VERSION
end
