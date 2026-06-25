require 'redmine'

Redmine::Plugin.register :redmine_private_files do
  name 'Redmine Private Files'
  author 'Aleksandr Cernaev'
  description 'Restricts access to files attached inside private issue notes. ' \
              'Such files can only be seen and downloaded by users who are allowed ' \
              'to view private notes (or by the author of the private note).'
  version '1.0.0'
  url 'https://github.com/your-repo/redmine_private_files'

  requires_redmine :version_or_higher => '4.1.0'

  settings :default => { 'enabled' => '1' },
           :partial => 'settings/redmine_private_files_settings'
end

require_relative 'lib/redmine_private_files'
