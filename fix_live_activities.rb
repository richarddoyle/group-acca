require 'xcodeproj'

project_path = '/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'WeeklyAcca' }
if app_target
  app_target.build_configurations.each do |config|
     config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
  end
  puts "Added NSSupportsLiveActivities to WeeklyAcca"
end

widget_target = project.targets.find { |t| t.name == 'WeeklyAccaWidgetExtension' }
if widget_target
  widget_target.build_configurations.each do |config|
     config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
  end
  puts "Added NSSupportsLiveActivities to WeeklyAccaWidgetExtension"
end

project.save
puts "Saved project."
