module RedminePrivateFiles
  module Patches
    # Keeps private-note files out of the history thumbnail strip.
    # journal_thumbnail_attachments builds its list straight from the journal's
    # details, bypassing visible_details, so an image attached alongside a
    # private note (and landing on a public journal) could otherwise still show
    # a thumbnail. Redefined in place for the same Ruby 2.6 reason as
    # AttachmentsHelperPatch.
    module JournalsHelperPatch
      def self.apply!
        return if JournalsHelper.private_method_defined?(:journal_thumbnail_attachments_with_private_files)

        JournalsHelper.class_eval do
          alias_method :journal_thumbnail_attachments_without_private_files, :journal_thumbnail_attachments

          def journal_thumbnail_attachments(journal)
            attachments = journal_thumbnail_attachments_without_private_files(journal)
            return attachments unless RedminePrivateFiles.enabled?
            attachments.select { |a| a.visible?(User.current) }
          end

          alias_method :journal_thumbnail_attachments_with_private_files, :journal_thumbnail_attachments
        end
      end
    end
  end
end
