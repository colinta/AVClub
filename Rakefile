# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'
if File.exists?(File.expand_path('~/.rubymotion.rb'))
  require '~/.rubymotion.rb'
end


Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'AVClub-Demo'
  app.files.insert(0, 'lib/AVClub/AVClubController.rb')

  app.vendor_project('vendor/AVClub', :xcode)
  app.frameworks.concat [
    'MediaPlayer',
    'QuartzCore',
    'CoreVideo',
    'CoreMedia',
    'AssetsLibrary',
    'MobileCoreServices',
    'AVFoundation',
  ]
end
