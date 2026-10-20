set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
open_project video_improve.al -noanalyze
puts "PROJECT_OPENED"
close_project
exit
