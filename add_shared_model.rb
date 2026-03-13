require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }
widget_target = project.targets.find { |t| t.name == 'WeeklyAccaWidgetExtension' }

# Find the Models group
models_group = project.main_group.find_subpath('WeeklyAcca/Models', true)
models_group.set_source_tree('<group>')
models_group.set_path('WeeklyAcca/Models')

file_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca/Models/AccaActivityAttributes.swift'
file_ref = models_group.files.find { |file| file.path == 'AccaActivityAttributes.swift' || file.real_path.to_s == file_path }

unless file_ref
  file_ref = models_group.new_file('AccaActivityAttributes.swift')
end

if app_target && !app_target.source_build_phase.files_references.include?(file_ref)
  app_target.add_file_references([file_ref])
  puts "Added to WeeklyAcca target"
end

if widget_target && !widget_target.source_build_phase.files_references.include?(file_ref)
  widget_target.add_file_references([file_ref])
  puts "Added to WeeklyAccaWidgetExtension target"
end

project.save
puts "Project saved successfully"
