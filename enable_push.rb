require 'xcodeproj'
project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)
app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }

attributes = project.root_object.attributes['TargetAttributes'] || {}
target_attributes = attributes[app_target.uuid] || {}
target_attributes['SystemCapabilities'] ||= {}
target_attributes['SystemCapabilities']['com.apple.Push'] = { 'enabled' => 1 }
target_attributes['SystemCapabilities']['com.apple.BackgroundModes'] = { 'enabled' => 1 }
attributes[app_target.uuid] = target_attributes
project.root_object.attributes['TargetAttributes'] = attributes
project.save
puts "Successfully enabled Push Notifications capability in WeeklyAcca.xcodeproj"
