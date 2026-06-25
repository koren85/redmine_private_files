// Removes the orphaned "Files" header (label + preceding <hr>) that is left on
// the issue page when every attachment of the issue belongs to a private note
// the current user is not allowed to see. The files have already been filtered
// out server-side; this only cleans up the empty header.
(function () {
  function cleanup() {
    var sentinels = document.querySelectorAll('.rpf-attachments-hidden');
    for (var i = 0; i < sentinels.length; i++) {
      var el = sentinels[i];
      var label = el.previousElementSibling;
      if (label && label.tagName === 'P') {
        var rule = label.previousElementSibling;
        if (rule && rule.tagName === 'HR') {
          rule.parentNode.removeChild(rule);
        }
        label.parentNode.removeChild(label);
      }
      el.parentNode.removeChild(el);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', cleanup);
  } else {
    cleanup();
  }
})();
