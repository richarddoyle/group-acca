require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }
widget_target = project.targets.find { |t| t.name == 'WeeklyAccaWidgetExtension' }

# Find the file WeeklyAccaWidgetLiveActivity.swift
file_ref = project.files.find { |f| f.path =~ /WeeklyAccaWidgetLiveActivity\.swift$/ }

if file_ref && app_target
  # Check if it's already in the app target
  unless app_target.source_build_phase.files_references.include?(file_ref)
    app_target.source_build_phase.add_file_reference(file_ref)
    puts "Added WeeklyAccaWidgetLiveActivity.swift to WeeklyAcca target"
  else
    puts "Already in WeeklyAcca target"
  end
end

project.save
puts "Saved project."
