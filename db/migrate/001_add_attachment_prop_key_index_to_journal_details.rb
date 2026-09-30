# Index for RedminePrivateFiles.introducing_journals: finds the journal that
# added a file by journal_details(property = 'attachment', prop_key = <id>).
# Redmine core indexes journal_details only by journal_id, so without this
# every file visibility check was a parallel full scan of journal_details
# (4.2M rows on production, ~200 ms per check, ~80% of all database time).
#
# Partial index: only 'attachment' rows are indexed, so it stays small (~7 MB).
# Idempotent: on production the index was created by hand on 2026-09-30 with the
# same name; the migration then only records its version.
class AddAttachmentPropKeyIndexToJournalDetails < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  INDEX_NAME = 'index_journal_details_on_prop_key_attachment'.freeze

  def up
    return if index_exists?(:journal_details, :prop_key, :name => INDEX_NAME)

    add_index :journal_details, :prop_key,
              :name => INDEX_NAME,
              :where => "property = 'attachment'",
              :algorithm => :concurrently
  end

  def down
    return unless index_exists?(:journal_details, :prop_key, :name => INDEX_NAME)

    remove_index :journal_details, :name => INDEX_NAME, :algorithm => :concurrently
  end
end
