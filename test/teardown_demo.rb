# Removes the end-to-end demo fixture created by setup_demo.rb and the browser
# test (project "RPF Demo", user rpf_plain, role, and the test issue + file).
# Safe to run repeatedly.
#
#   bin/rails runner plugins/redmine_private_files/test/teardown_demo.rb -e production

project = Project.find_by(:identifier => 'rpf-demo')
if project
  project.issues.each do |issue|
    issue.attachments.each { |a| a.destroy }
    issue.destroy
  end
  Member.where(:project_id => project.id).destroy_all
  project.destroy
  puts "Removed project RPF Demo and its issues."
else
  puts "No RPF Demo project found."
end

if (u = User.find_by(:login => 'rpf_plain'))
  u.destroy
  puts "Removed user rpf_plain."
end

if (r = Role.find_by(:name => 'RPF Plain (no private notes)'))
  r.destroy
  puts "Removed role 'RPF Plain (no private notes)'."
end

puts "Done."
