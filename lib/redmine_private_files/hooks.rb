module RedminePrivateFiles
  class Hooks < Redmine::Hook::ViewListener
    # Loads a small script that removes the orphaned "Files" header left on the
    # issue page when all of an issue's attachments belong to private notes the
    # current user may not see. The files themselves are already removed
    # server-side; this is purely cosmetic.
    def view_layouts_base_html_head(context = {})
      return '' unless RedminePrivateFiles.enabled?
      javascript_include_tag('redmine_private_files', :plugin => 'redmine_private_files')
    end
  end
end
