module RedminePrivateFiles
  module Patches
    # Hides "attachment" journal details (the "File X added" lines in the issue
    # history) when the referenced file belongs to a private note the user may
    # not see.
    #
    # This matters because some installs split a single submit into several
    # journals, placing the file's detail on a *public* journal while the note
    # text lives on a *private* one. The public journal — and therefore the file
    # detail — would otherwise be visible to everyone.
    #
    # visible_details is the shared chokepoint used by the issue history, the
    # REST API, e-mail notifications, PDF export and the activity feed, so a
    # single patch covers them all.
    module JournalPatch
      def visible_details(user = User.current)
        return super unless RedminePrivateFiles.enabled?

        super.select do |detail|
          if detail.property == 'attachment'
            attachment = Attachment.find_by(:id => detail.prop_key)
            attachment.nil? || attachment.visible?(user)
          else
            true
          end
        end
      end
    end
  end
end
