require_relative 'redmine_private_files/patches/attachment_patch'
require_relative 'redmine_private_files/patches/journal_patch'
require_relative 'redmine_private_files/patches/attachments_helper_patch'
require_relative 'redmine_private_files/patches/journals_helper_patch'

# Core logic of the plugin.
#
# In Redmine, files attached while adding an issue note are stored with the
# Issue as their container (container_type = 'Issue'). The fact that a given
# attachment was added by a particular note is recorded in `journal_details`
# (property = 'attachment', prop_key = <attachment id>). A file is therefore
# considered "private" when at least one such detail belongs to a Journal whose
# `private_notes` flag is set.
#
# A private file is visible to a user only if that user is allowed to view
# private notes in the issue's project, or is the author of the private note
# (this mirrors Redmine's own private-note visibility rule).
module RedminePrivateFiles
  module_function

  def settings
    Setting.plugin_redmine_private_files || {}
  end

  def enabled?
    settings['enabled'].to_s != '0'
  end

  # The journal(s) that introduced the attachment (i.e. carry its
  # property='attachment' detail). Normally exactly one.
  def introducing_journals(attachment)
    Journal.where(:journalized_type => 'Issue').
      joins(:details).
      where(:journal_details => { :property => 'attachment', :prop_key => attachment.id.to_s })
  end

  # Private journals tied to the attachment.
  #
  # A file is considered private when it was added together with a private
  # note. That covers two layouts:
  #   * the introducing journal is itself private (vanilla Redmine), and
  #   * the introducing journal is public but a private journal was saved in the
  #     same submit — some installs/plugins split one save into several journals,
  #     putting the file on a public journal and the text on a private one. Such
  #     sibling journals share the issue and the exact created_on timestamp.
  #
  # Returns a relation over the relevant private Journal records (their user_id
  # identifies the note authors, who keep access).
  def private_journals_for(attachment)
    ids = private_journal_ids(attachment)
    ids.empty? ? Journal.none : Journal.where(:id => ids)
  end

  # Ids of the private journals tied to the attachment (see private_journals_for).
  #
  # Memoized on the attachment instance: one page checks the same file several
  # times (file list, "File added" history lines, thumbnails), and each check
  # used to repeat the same lookups. The instance lives for one request only.
  # The lookup itself relies on the partial index
  # index_journal_details_on_prop_key_attachment (db/migrate/001) — without it
  # every call was a full scan of journal_details (~200 ms on production).
  def private_journal_ids(attachment)
    return [] unless attachment.container_type == 'Issue' && attachment.container_id

    memo = attachment.instance_variable_get(:@rpf_private_journal_ids)
    return memo if memo

    intro = introducing_journals(attachment).select(:id, :journalized_id, :created_on, :private_notes).to_a
    ids = intro.select(&:private_notes?).map(&:id)
    intro.each do |j|
      ids |= Journal.where(:journalized_type => 'Issue',
                           :journalized_id => j.journalized_id,
                           :created_on => j.created_on,
                           :private_notes => true).pluck(:id)
    end

    attachment.instance_variable_set(:@rpf_private_journal_ids, ids)
  end

  # True when the attachment was added inside (or alongside) a private issue note.
  def added_via_private_note?(attachment)
    private_journal_ids(attachment).any?
  end

  # True when +user+ is allowed to see +attachment+ with respect to the
  # private-note restriction. Files that are not tied to a private note are
  # always allowed here (normal Redmine rules still apply elsewhere).
  def visible_to?(attachment, user)
    return true unless enabled?

    ids = private_journal_ids(attachment)
    return true if ids.empty?

    user ||= User.anonymous
    project = attachment.container.try(:project)
    return true if user.allowed_to?(:view_private_notes, project)

    user.logged? && Journal.where(:id => ids, :user_id => user.id).exists?
  end
end

Rails.configuration.to_prepare do
  # Models are classes: prepend works reliably.
  require_dependency 'attachment'
  unless Attachment.included_modules.include?(RedminePrivateFiles::Patches::AttachmentPatch)
    Attachment.prepend RedminePrivateFiles::Patches::AttachmentPatch
  end

  require_dependency 'journal'
  unless Journal.included_modules.include?(RedminePrivateFiles::Patches::JournalPatch)
    Journal.prepend RedminePrivateFiles::Patches::JournalPatch
  end

  # Helper is a module already mixed into ActionView; redefine in place
  # (see AttachmentsHelperPatch for the Ruby 2.6 rationale).
  require_dependency 'attachments_helper'
  RedminePrivateFiles::Patches::AttachmentsHelperPatch.apply!

  require_dependency 'journals_helper'
  RedminePrivateFiles::Patches::JournalsHelperPatch.apply!
end

require_relative 'redmine_private_files/hooks'
