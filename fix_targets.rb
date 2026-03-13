require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'WeeklyAcca' }
widget_target = project.targets.find { |t| t.name == 'WeeklyAccaWidgetExtension' }

if main_target.nil? || widget_target.nil?
  puts "Error: Targets not found. Main: #{!main_target.nil?}, Widget: #{!widget_target.nil?}"
  exit 1
end

# Find the Live Activity file
widget_file = project.files.find { |f| f.path =~ /WeeklyAccaWidgetLiveActivity.swift/ }
if widget_file.nil?
    widget_group = project.main_group.groups.find { |g| g.name == 'WeeklyAccaWidget' }
    if widget_group
        widget_file = widget_group.files.find { |f| f.path =~ /WeeklyAccaWidgetLiveActivity.swift/ }
    end
end

if widget_file.nil?
  puts 'Error: Widget file not found in project.'
else
  unless main_target.source_build_phase.files_references.include?(widget_file)
    main_target.source_build_phase.add_file_reference(widget_file)
    puts 'Added WeeklyAccaWidgetLiveActivity.swift to WeeklyAcca target'
  else
    puts 'WeeklyAccaWidgetLiveActivity.swift is already in WeeklyAcca target'
  end
end

project.save
puts 'Project saved successfully.'
