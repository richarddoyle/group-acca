import re
import sys

pbxproj_path = "/Users/richarddoyle/Library/Mobile Documents/com~apple~CloudDocs/WeeklyAcca/WeeklyAcca.xcodeproj/project.pbxproj"

with open(pbxproj_path, 'r') as f:
    content = f.read()

# 1. We need to find the PBXBuildFile section to add our files.
# But easier is to just use xcodeproj ruby gem if available, or just a simple ruby script

