# Persistent demo fixture for end-to-end testing (idempotent).
# Creates a project, a plain user WITHOUT view_private_notes, and a membership.
# Prints the credentials/identifiers to drive the browser test.
#
#   bin/rails runner plugins/redmine_private_files/test/setup_demo.rb -e production

ident = 'rpf-demo'
PASSWORD = 'Privatefiles2026'

project = Project.find_by(:identifier => ident)
unless project
  project = Project.new(:name => 'RPF Demo', :identifier => ident)
  project.save!(:validate => false)
end
project.enabled_module_names = ['issue_tracking']
project.save!(:validate => false)

# Admin must be a member too so they can add notes; ensure admin membership.
admin = User.find_by(:login => 'bazisadmin')

role_plain = Role.find_by(:name => 'RPF Plain (no private notes)')
unless role_plain
  role_plain = Role.new(:name => 'RPF Plain (no private notes)', :issues_visibility => 'all')
  role_plain.permissions = [:view_issues, :add_issues, :add_issue_notes]
  role_plain.save!(:validate => false)
end

manager = Role.find_by(:builtin => 0, :name => 'Manager') || Role.where(:builtin => 0).first

plain = User.find_by(:login => 'rpf_plain')
unless plain
  plain = User.new(:login => 'rpf_plain', :firstname => 'Plain', :lastname => 'User',
                   :mail => 'rpf_plain@example.test')
  plain.status = User::STATUS_ACTIVE
end
plain.password = PASSWORD
plain.must_change_passwd = false
plain.save!(:validate => false)

def ensure_member(project, user, role)
  m = Member.find_by(:project_id => project.id, :user_id => user.id)
  unless m
    m = Member.new(:project => project, :user => user)
    m.roles = [role]
    m.save!(:validate => false)
  end
  m
end

ensure_member(project, plain, role_plain)
ensure_member(project, admin, manager) if admin && manager

puts "PROJECT_IDENTIFIER=#{project.identifier}"
puts "PROJECT_ID=#{project.id}"
puts "PLAIN_LOGIN=rpf_plain"
puts "PLAIN_PASSWORD=#{PASSWORD}"
puts "ADMIN_LOGIN=bazisadmin"
puts "PLAIN_CAN_VIEW_PRIVATE_NOTES=#{plain.reload.allowed_to?(:view_private_notes, project)}"
