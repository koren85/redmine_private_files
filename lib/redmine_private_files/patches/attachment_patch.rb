module RedminePrivateFiles
  module Patches
    # Adds the private-note restriction to Attachment#visible?.
    #
    # Attachment#visible? is the single chokepoint used by
    # AttachmentsController#read_authorize (show / download / thumbnail) and by
    # the views that list attachments, so restricting it here is enough to block
    # both viewing and downloading of files attached to private notes.
    module AttachmentPatch
      def visible?(user = User.current)
        return false unless super
        RedminePrivateFiles.visible_to?(self, user)
      end
    end
  end
end
