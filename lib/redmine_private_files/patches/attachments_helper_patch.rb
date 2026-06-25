module RedminePrivateFiles
  module Patches
    # Filters the attachment list rendered by link_to_attachments so files
    # belonging to private notes are not shown (neither as links nor thumbnails)
    # to users who may not see them.
    #
    # NOTE: this redefines the method *in place* on AttachmentsHelper rather than
    # using `prepend`. Under Ruby 2.6 (this Redmine runs 2.6.10) prepending a
    # module to a helper that ActionView already mixed in at boot does not update
    # the view's method resolution, so the patch would silently do nothing.
    # Redefining the method within the helper module itself does propagate to
    # every including view class.
    module AttachmentsHelperPatch
      def self.apply!
        return if AttachmentsHelper.private_method_defined?(:link_to_attachments_with_private_files)

        AttachmentsHelper.class_eval do
          def link_to_attachments(container, options = {})
            options.assert_valid_keys(:author, :thumbnails)

            all_attachments =
              if container.attachments.loaded?
                container.attachments
              else
                container.attachments.preload(:author).to_a
              end

            attachments =
              if RedminePrivateFiles.enabled?
                all_attachments.select { |a| a.visible?(User.current) }
              else
                all_attachments
              end

            if attachments.any?
              options = {
                :editable => container.attachments_editable?,
                :deletable => container.attachments_deletable?,
                :author => true
              }.merge(options)
              render :partial => 'attachments/links',
                     :locals => {
                       :container => container,
                       :attachments => attachments,
                       :options => options,
                       :thumbnails => (options[:thumbnails] && Setting.thumbnails_enabled?)
                     }
            elsif all_attachments.any?
              # Everything was filtered out: emit a sentinel so the client-side
              # script can remove the now-empty "Files" header on the issue page.
              content_tag(:div, ''.html_safe, :class => 'rpf-attachments-hidden', :style => 'display:none')
            end
          end

          # Marker so apply! is idempotent across reloads.
          alias_method :link_to_attachments_with_private_files, :link_to_attachments

          # Keep private-note files out of the REST API attachments array
          # (GET /issues/:id.json?include=attachments). The single-attachment
          # API endpoint is already guarded by the controller's read_authorize,
          # so a hidden attachment never reaches this path there.
          alias_method :render_api_attachment_without_private_files, :render_api_attachment
          def render_api_attachment(attachment, api, options = {})
            return if RedminePrivateFiles.enabled? && !attachment.visible?(User.current)
            render_api_attachment_without_private_files(attachment, api, options)
          end
        end
      end
    end
  end
end
