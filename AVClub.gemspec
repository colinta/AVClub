# -*- encoding: utf-8 -*-
require File.expand_path('../lib/AVClub/version.rb', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'AVClub'
  gem.version       = AVClub::Version

  gem.authors  = ['Colin T.A. Gray <colinta@gmail.com>']
  gem.email          = 'colinta@gmail.com'

  gem.description = <<-DESC
Setup an AVCaptureSession with video, multiple cameras, and still image
capabilities.  You can also easily have touch-to-focus and flash-on-picture
features.
DESC

  gem.summary = 'A wrapper for AVFoundation to make it easy to implement a custom camera view.'
  gem.homepage = 'https://github.com/rubymotion/AVClub'

  gem.files       = `git ls-files`.split($\)
  gem.require_paths = ['lib']
  gem.test_files  = gem.files.grep(%r{^spec/})

  gem.add_dependency 'rake'
  gem.add_development_dependency 'rspec'

end
