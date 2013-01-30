unless defined?(Motion::Project::Config)
  raise "The AVClub gem must be required within a RubyMotion project Rakefile."
end


Motion::Project::App.setup do |app|
  # scans app.files until it finds app/ (the default)
  # if found, it inserts just before those files, otherwise it will insert to
  # the end of the list
  insert_point = 0
  app.files.each_index do |index|
    file = app.files[index]
    if file =~ /^(?:\.\/)?app\//
      # found app/, so stop looking
      break
    end
    insert_point = index + 1
  end

  Dir.glob(File.join(File.dirname(__FILE__), 'AVClub/**/*.rb')).reverse.each do |file|
    app.files.insert(insert_point, file)
  end

  app.vendor_project(File.join(File.dirname(__FILE__), '../vendor/AVClub'), :static, cflags: '-fobjc-arc')

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
