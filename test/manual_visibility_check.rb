# Isolated, non-destructive check of the private-files visibility rule.
#
# Builds a throwaway object graph (project, roles, users, issue, a private note
# with an attachment, and a public attachment) inside a transaction that is
# always rolled back, then asserts Attachment#visible? for every relevant actor.
#
# Run from the Redmine root:
#   bin/rails runner plugins/redmine_private_files/test/manual_visibility_check.rb -e production

failures = []
def check(failures, label, actual, expected)
  ok = (actual == expected)
  puts format('  [%s] %-55s expected=%s got=%s', ok ? 'OK' : 'FAIL', label, expected, actual)
  failures << label unless ok
end

ActiveRecord::Base.transaction do
  suffix = "rpf_#{Time.now.to_i}"

  project = Project.create!(:name => "RPF Test #{suffix}", :identifier => "rpf-#{Time.now.to_i}")
  project.enabled_module_names = ['issue_tracking']
  project.save!

  role_priv = Role.create!(:name => "RPF priv #{suffix}",
                           :issues_visibility => 'all',
                           :permissions => [:view_issues, :view_private_notes])
  role_plain = Role.create!(:name => "RPF plain #{suffix}",
                            :issues_visibility => 'all',
                            :permissions => [:view_issues])

  def make_user(login, suffix)
    u = User.new(:login => "#{login}_#{suffix}", :firstname => login, :lastname => 'Test',
                 :mail => "#{login}_#{suffix}@example.test")
    u.status = User::STATUS_ACTIVE
    u.save!(:validate => false) # bypass unrelated cross-plugin User validations
    u
  end

  user_priv   = make_user('priv', suffix)    # may view private notes
  user_plain  = make_user('plain', suffix)   # may NOT view private notes
  user_author = make_user('author', suffix)  # author of the private note, no permission

  Member.create!(:project => project, :user => user_priv,   :roles => [role_priv])
  Member.create!(:project => project, :user => user_plain,  :roles => [role_plain])
  Member.create!(:project => project, :user => user_author, :roles => [role_plain])

  tracker  = project.trackers.first || Tracker.first
  status   = IssueStatus.first
  priority = IssuePriority.first || IssuePriority.create!(:name => "RPF prio #{suffix}", :is_default => true)

  issue = Issue.new(:project => project, :tracker => tracker, :status => status,
                    :priority => priority, :author => user_author, :subject => "RPF issue #{suffix}")
  issue.save!(:validate => false)

  def make_attachment(issue, author, name, suffix)
    a = Attachment.new
    a.container_type = 'Issue'
    a.container_id   = issue.id
    a.filename       = "#{name}_#{suffix}.txt"
    a.disk_filename  = "#{Time.now.to_i}_#{name}.txt"
    a.filesize       = 10
    a.content_type   = 'text/plain'
    a.digest         = 'deadbeef'
    a.author_id      = author.id
    a.created_on     = Time.now
    a.save!(:validate => false)
    a
  end

  private_att = make_attachment(issue, user_author, 'secret', suffix)
  public_att  = make_attachment(issue, user_author, 'public', suffix)

  # Private note that introduced private_att.
  jpriv = Journal.new(:journalized => issue, :user => user_author, :notes => 'private', :private_notes => true)
  jpriv.save!(:validate => false)
  JournalDetail.create!(:journal => jpriv, :property => 'attachment',
                        :prop_key => private_att.id.to_s, :value => private_att.filename)

  # Public note that introduced public_att.
  jpub = Journal.new(:journalized => issue, :user => user_author, :notes => 'public', :private_notes => false)
  jpub.save!(:validate => false)
  JournalDetail.create!(:journal => jpub, :property => 'attachment',
                        :prop_key => public_att.id.to_s, :value => public_att.filename)

  # Make sure the plugin treats itself as enabled for the test.
  Setting.plugin_redmine_private_files = { 'enabled' => '1' }

  puts "\n== Private-note file (#{private_att.filename}) =="
  check(failures, 'user WITH view_private_notes can see it',     private_att.visible?(user_priv),         true)
  check(failures, 'user WITHOUT view_private_notes is blocked',  private_att.visible?(user_plain),        false)
  check(failures, 'author of the private note can see it',       private_att.visible?(user_author),       true)
  check(failures, 'anonymous is blocked',                        private_att.visible?(User.anonymous),    false)

  puts "\n== Public-note file (#{public_att.filename}) — control =="
  check(failures, 'user WITHOUT view_private_notes can see it',  public_att.visible?(user_plain),         true)
  check(failures, 'user WITH view_private_notes can see it',     public_att.visible?(user_priv),          true)

  puts "\n== Plugin disabled — restriction lifted =="
  Setting.plugin_redmine_private_files = { 'enabled' => '0' }
  check(failures, 'private file visible to everyone when disabled', private_att.visible?(user_plain),     true)

  raise ActiveRecord::Rollback
end

puts "\n" + ('=' * 50)
if failures.empty?
  puts 'ALL CHECKS PASSED'
else
  puts "FAILURES (#{failures.size}): #{failures.join('; ')}"
  exit 1
end
