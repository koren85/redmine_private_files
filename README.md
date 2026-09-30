# Redmine Private Files

Restricts access to files that were attached **inside a private issue note**.
Such a file can only be seen and downloaded by users who are allowed to view
private notes in the issue's project (or by the author of that note). Users
without the `view_private_notes` permission do not see the file anywhere in the
issue and cannot download it via its direct URL.

Compatible with **Redmine 4.1.x** (tested on 4.1.3, Ruby 2.6.10).

## How it works

When a file is attached while adding an issue note, Redmine stores the file on
the **Issue** (not on the note). The link to the note that introduced the file
lives in `journal_details` (`property = 'attachment'`). A file is treated as
private when it was added together with a private note — covering both vanilla
Redmine (file detail on the private journal) and installs that split one submit
into several journals (file detail on a public journal, note text on a private
sibling journal created at the same instant).

Enforcement happens at these points:

| Vector | Patched |
| --- | --- |
| Download / inline view / thumbnail / single-file API | `Attachment#visible?` (drives `AttachmentsController#read_authorize`) |
| Top "Files" list on the issue page | `AttachmentsHelper#link_to_attachments` |
| Issue history, REST API journals, e-mail, PDF, activity | `Journal#visible_details` |
| REST API `?include=attachments` | `AttachmentsHelper#render_api_attachment` |
| History thumbnail strip | `JournalsHelper#journal_thumbnail_attachments` |

A small script removes the now-empty "Files" header on the issue page when every
file is hidden.

## Settings

Administration → Plugins → Redmine Private Files → Configure. A single toggle
(*Restrict files attached to private notes*, on by default) lets you disable the
restriction without uninstalling.

## Notes

- One migration: a partial index on `journal_details (prop_key) WHERE property = 'attachment'`.
  Every file visibility check looks up the journal that added the file; without the
  index that lookup is a full scan of `journal_details` (~200 ms on a 4M-row table,
  repeated for every file on every page). Run
  `bundle exec rake redmine:plugins:migrate NAME=redmine_private_files RAILS_ENV=production`
  after installing or upgrading. The migration builds the index `CONCURRENTLY` and
  skips it if an index with the same name already exists.
- In production, restart Redmine after installing or upgrading the plugin.
- Files attached to the issue description or to **public** notes are unaffected.
