require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)
app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }

# We have duplicate references to AccaActivityAttributes.swift. Let's remove the explicit file reference 
# from the WeeklyAcca target since Xcode 16 is already syncing the Models folder.
if app_target
  duplicate_refs = app_target.source_build_phase.files.select { |bf| bf.file_ref && bf.file_ref.path == 'WeeklyAcca/Models/AccaActivityAttributes.swift' }
  duplicate_refs.each do |bf|
    app_target.source_build_phase.remove_build_file(bf)
  end
  puts "Cleaned up duplicate from main app target."
end

project.save
