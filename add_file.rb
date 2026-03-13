require 'xcodeproj'

project_path = 'WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
main_target = project.targets.find { |t| t.name == 'WeeklyAcca' }

# Find the file reference
# It might be in a group, so recursively find
file_ref = project.files.find { |f| f.path && f.path.include?('WeeklyAccaWidgetLiveActivity.swift') }

if file_ref && main_target
  unless main_target.source_build_phase.files_references.include?(file_ref)
    main_target.source_build_phase.add_file_reference(file_ref)
    project.save
    puts "Added WeeklyAccaWidgetLiveActivity.swift to WeeklyAcca target"
  else
    puts "Already in target"
  end
else
  puts "Could not find file: #{file_ref.inspect} or target: #{main_target.inspect}"
end
