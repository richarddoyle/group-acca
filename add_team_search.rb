require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }

file_path = 'WeeklyAcca/Views/TeamSearchView.swift'

# Create a top-level file reference
file_ref = project.new_file(file_path)

if app_target && !app_target.source_build_phase.files_references.include?(file_ref)
  app_target.add_file_references([file_ref])
  puts "Added #{file_path} to WeeklyAcca target"
else
  puts "Already in target"
end

project.save
puts "Saved."
