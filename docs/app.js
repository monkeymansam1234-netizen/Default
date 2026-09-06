/* Nightly — a ten-second end-of-day check-in.
   Everything lives in localStorage on this device. No accounts, no network. */
(function () {
  'use strict';

  var KEYS = { entries: 'nightly.entries.v1', settings: 'nightly.settings.v1' };

  /* Check-ins before 4am belong to the night before: logging at 1am is the end
     of yesterday, not a skipped day and a fresh one. */
  var CUTOFF_HOUR = 4;

  var BUILT_INS = [
    { id: 'accomplished', text: 'Happy with what you got done?', emoji: '✅', enabled: true, builtIn: true },
    { id: 'food', text: 'Happy with how you ate?', emoji: '🍽️', enabled: true, builtIn: true },
    { id: 'bedtime', text: 'Getting to bed at a decent hour?', emoji: '🌙', enabled: true, builtIn: true },
    { id: 'movement', text: 'Did you move your body?', emoji: '🚶', enabled: false, builtIn: true },
    { id: 'people', text: 'Any real contact with someone?', emoji: '💬', enabled: false, builtIn: true },
    { id: 'kindness', text: 'Were you kind to yourself?', emoji: '💛', enabled: false, builtIn: true },
    { id: 'screens', text: 'Happy with your screen time?', emoji: '📱', enabled: false, builtIn: true }
  ];

  /* Weather rather than faces or thumbs — a rainy day isn't a failing grade. */
  var GLYPHS = {
    rough: '<svg viewBox="0 0 24 24" class="glyph"><path d="M7.2 16.4h9.3a3.6 3.6 0 0 0 .3-7.2 5.3 5.3 0 0 0-10.2-1 3.7 3.7 0 0 0 .6 8.2Z"/><path d="M9 19l-.9 2.2M13 19l-.9 2.2M17 19l-.9 2.2"/></svg>',
    okay: '<svg viewBox="0 0 24 24" class="glyph"><circle cx="8.6" cy="7.4" r="2.9"/><path d="M8.6 2.4v1.3M3.7 7.4H2.4M5.1 3.9 4.2 3M12.1 3.9l.9-.9M14.8 7.4h-1.3"/><path d="M9.6 19.6h7.9a3.4 3.4 0 0 0 .3-6.8 5 5 0 0 0-9.6-.9 3.5 3.5 0 0 0 1.4 7.7Z"/></svg>',
    good: '<svg viewBox="0 0 24 24" class="glyph"><circle cx="12" cy="12" r="4.3"/><path d="M12 2.4v2.1M12 19.5v2.1M2.4 12h2.1M19.5 12h2.1M5.2 5.2l1.5 1.5M17.3 17.3l1.5 1.5M18.8 5.2l-1.5 1.5M6.7 17.3l-1.5 1.5"/></svg>'
  };

  var RATINGS = [
    { value: -1, key: 'rough', label: 'Not really' },
    { value: 0, key: 'okay', label: 'Kind of' },
    { value: 1, key: 'good', label: 'Yeah' }
  ];

  // ---------------------------------------------------------------- storage

  function read(key, fallback) {
    try {
      var raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }

  function write(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      /* Private browsing or a full disk — the session still works, it just
         won't survive a reload. Not worth interrupting bedtime over. */
    }
  }

  var entries = read(KEYS.entries, {});
  var settings = read(KEYS.settings, null) || {};
  if (!Array.isArray(settings.prompts)) {
    settings.prompts = BUILT_INS.map(function (p) { return Object.assign({}, p); });
  }
  if (!settings.theme) settings.theme = 'dark';
  mergeNewBuiltIns();

  /* Keeps saved settings working when a new built-in question ships. */
  function mergeNewBuiltIns() {
    var known = {};
    settings.prompts.forEach(function (p) { known[p.id] = true; });
    BUILT_INS.forEach(function (p) {
      if (!known[p.id]) settings.prompts.push(Object.assign({}, p, { enabled: false }));
    });
  }

  function saveEntries() { write(KEYS.entries, entries); }
  function saveSettings() { write(KEYS.settings, settings); }

  // ------------------------------------------------------------------ days

  function pad(n) { return n < 10 ? '0' + n : String(n); }

  function keyOf(date) {
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
  }

  function todayKey(now) {
    now = now || new Date();
    return keyOf(new Date(now.getTime() - CUTOFF_HOUR * 3600000));
  }

  function parseKey(key) {
    var p = key.split('-');
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }

  function shiftKey(key, days) {
    var d = parseKey(key);
    d.setDate(d.getDate() + days);
    return keyOf(d);
  }

  function pastMidnight() { return keyOf(new Date()) !== todayKey(); }

  var longFmt = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
  var shortFmt = new Intl.DateTimeFormat(undefined, { weekday: 'short', month: 'short', day: 'numeric' });

  function relativeDay(key) {
    var today = todayKey();
    if (key === today) return 'Tonight';
    if (key === shiftKey(today, -1)) return 'Yesterday';
    return shortFmt.format(parseKey(key));
  }

  // --------------------------------------------------------------- entries

  function entryFor(key) { return entries[key]; }

  function ensure(key) {
    if (!entries[key]) {
      entries[key] = { day: key, answers: {}, note: '', loggedAt: new Date().toISOString() };
    }
    entries[key].updatedAt = new Date().toISOString();
    return entries[key];
  }

  /* Tapping the answer you already chose clears it — no long-press, no undo menu. */
  function toggleRating(key, promptId, value) {
    var entry = ensure(key);
    if (entry.answers[promptId] === value) delete entry.answers[promptId];
    else entry.answers[promptId] = value;
    saveEntries();
  }

  function setNote(key, text) {
    var existing = entries[key];
    // Don't create an entry just because an empty note field lost focus.
    if (!existing && !text.trim()) return;
    if (existing && existing.note === text) return;
    ensure(key).note = text;
    saveEntries();
  }

  function score(entry) {
    if (!entry) return null;
    var vals = Object.keys(entry.answers).map(function (k) { return entry.answers[k]; });
    if (!vals.length) return null;
    var total = vals.reduce(function (sum, v) { return sum + (v + 1) / 2; }, 0);
    return total / vals.length;
  }

  /* Phrased so a bad day never reads as a verdict. */
  function summary(entry) {
    var s = score(entry);
    if (s === null) return (entry && entry.note.trim()) ? 'Noted. That counts.' : 'Logged. That counts.';
    if (s >= 0.85) return 'Sounds like a good one.';
    if (s >= 0.6) return 'Mostly a decent day.';
    if (s >= 0.4) return 'A mixed one. Fair enough.';
    if (s >= 0.15) return 'Rough day — you still showed up.';
    return 'Hard day. Logging it anyway is the win.';
  }

  /* Counts back from yesterday when tonight isn't in yet, so the number never
     sits at 0 all day as a guilt trip. */
  function streak() {
    var cursor = todayKey();
    if (!entries[cursor]) cursor = shiftKey(cursor, -1);
    var count = 0;
    while (entries[cursor]) {
      count += 1;
      cursor = shiftKey(cursor, -1);
    }
    return count;
  }

  function recentKeys(days) {
    var out = [];
    var cursor = todayKey();
    for (var i = 0; i < days; i++) {
      out.push(cursor);
      cursor = shiftKey(cursor, -1);
    }
    return out.reverse();
  }

  function positivity(promptId, days) {
    var vals = recentKeys(days)
      .map(function (k) { return entries[k] && entries[k].answers[promptId]; })
      .filter(function (v) { return v === 0 || v === 1 || v === -1; });
    if (!vals.length) return null;
    var total = vals.reduce(function (sum, v) { return sum + (v + 1) / 2; }, 0);
    return { share: total / vals.length, days: vals.length };
  }

  function enabledPrompts() {
    return settings.prompts.filter(function (p) { return p.enabled; });
  }

  // ----------------------------------------------------------------- utils

  function esc(text) {
    return String(text).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function $(sel, root) { return (root || document).querySelector(sel); }

  function buzz() {
    // No-op on iOS, but harmless and nice on Android.
    if (navigator.vibrate) { try { navigator.vibrate(8); } catch (e) {} }
  }

  function tone(value) { return value === -1 ? 'rough' : value === 0 ? 'okay' : 'good'; }

  function toneFor(s) { return s < 0.4 ? 'rough' : s < 0.7 ? 'okay' : 'good'; }

  function isInstalled() {
    return window.navigator.standalone === true ||
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  }

  // ----------------------------------------------------------- the card

  function cardHTML(day) {
    var isToday = day === todayKey();
    var entry = entryFor(day);
    var prompts = enabledPrompts();
    var run = streak();

    var head = '<div class="card-head">' +
      '<h1>' + (isToday ? 'How was today?' : esc(relativeDay(day))) + '</h1>' +
      '<p class="date">' + esc(longFmt.format(parseKey(day))) + '</p>' +
      (isToday && run > 1 ? '<span class="streak">' + run + ' nights in a row</span>' : '') +
      '</div>';

    var body = prompts.map(function (p) {
      var chosen = entry && entry.answers[p.id];
      var hasAnswer = entry && Object.prototype.hasOwnProperty.call(entry.answers, p.id);
      return '<section class="card" data-prompt-card="' + esc(p.id) + '">' +
        '<div class="card-title"><span class="emoji">' + p.emoji + '</span>' + esc(p.text) + '</div>' +
        '<div class="ratings">' + RATINGS.map(function (r) {
          var on = hasAnswer && chosen === r.value;
          return '<button type="button" class="rating" data-key="' + r.key + '"' +
            ' data-action="rate" data-day="' + esc(day) + '" data-prompt="' + esc(p.id) + '" data-value="' + r.value + '"' +
            ' aria-pressed="' + (on ? 'true' : 'false') + '" aria-label="' + esc(p.text + ' ' + r.label) + '">' +
            GLYPHS[r.key] + '<span>' + r.label + '</span></button>';
        }).join('') + '</div></section>';
    }).join('');

    if (!prompts.length) {
      body = '<section class="card"><div class="card-title">No questions turned on</div>' +
        '<p class="foot" style="text-align:left">Add some in settings, or just leave a note below — that works too.</p></section>';
    }

    var noteCard = '<section class="card">' +
      '<div class="card-title"><span class="emoji">✍️</span>Anything worth remembering?</div>' +
      '<textarea class="note-input" data-day="' + esc(day) + '" rows="2" ' +
      'placeholder="Optional. One line is plenty.">' + esc(entry ? entry.note : '') + '</textarea>' +
      '</section>';

    var doneLabel = isToday
      ? (entry ? 'Saved — tap to update' : 'Log tonight')
      : (entry ? 'Save changes' : 'Log this day');

    var done = '<button type="button" class="done" data-action="finish" data-day="' + esc(day) + '">' +
      (entry
        ? '<svg viewBox="0 0 24 24" class="glyph"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>'
        : '<svg viewBox="0 0 24 24" class="glyph"><path d="M20 14.5A8.6 8.6 0 0 1 9.2 4a8.6 8.6 0 1 0 10.8 10.5Z"/></svg>') +
      esc(doneLabel) + '</button>';

    var foot = '<p class="foot">' +
      (isToday && pastMidnight()
        ? 'Past midnight — this still counts for ' + esc(shortFmt.format(parseKey(day))) + '.<br>'
        : '') +
      'Skipping questions is fine. Logging nothing at all still counts.</p>';

    var install = (isToday && !isInstalled() && !settings.hideInstall)
      ? '<div class="install"><div>Keep it one tap away: tap the <b>Share</b> button below, then ' +
        '<b>Add to Home Screen</b>.</div><button data-action="hide-install" aria-label="Dismiss">✕</button></div>'
      : '';

    return head + body + noteCard + done + foot + install;
  }

  function renderToday() {
    $('#today').innerHTML = cardHTML(todayKey());
    autosizeAll();
  }

  // --------------------------------------------------------------- history

  function historyHTML() {
    var keys = recentKeys(35);
    var logged = keys.filter(function (k) { return entries[k]; }).length;
    var all = Object.keys(entries).sort().reverse();
    var today = todayKey();

    if (!all.length) {
      return '<div class="empty"><b>Nothing logged yet</b>Tonight can be the first one.</div>';
    }

    var stats = '<div class="stats">' +
      '<div class="stat"><b>' + streak() + '</b><span>' + (streak() === 1 ? 'night streak' : 'nights in a row') + '</span></div>' +
      '<div class="stat"><b>' + logged + '/35</b><span>days logged</span></div>' +
      '<div class="stat"><b>' + all.length + '</b><span>total entries</span></div>' +
      '</div>';

    var grid = '<div class="section-title">Last five weeks</div><div class="grid">' +
      keys.map(function (k) {
        var entry = entries[k];
        var cls = 'cell';
        if (entry) {
          var s = score(entry);
          cls += s === null ? ' blank-logged' : ' ' + toneFor(s);
        }
        if (k === today) cls += ' today';
        return '<div class="' + cls + '" title="' + esc(shortFmt.format(parseKey(k))) + '"></div>';
      }).join('') +
      '</div><div class="legend">' +
      '<span><i style="background:var(--rough)"></i>Not really</span>' +
      '<span><i style="background:var(--okay)"></i>Kind of</span>' +
      '<span><i style="background:var(--good)"></i>Yeah</span>' +
      '<span><i style="background:var(--chip)"></i>Not logged</span></div>';

    var prompts = enabledPrompts();
    var patterns = '';
    if (prompts.length) {
      patterns = '<div class="section-title">Patterns · last 30 days</div>' +
        prompts.map(function (p) {
          var stat = positivity(p.id, 30);
          var pct = stat ? Math.round(stat.share * 100) : 0;
          var color = stat ? 'var(--' + toneFor(stat.share) + ')' : 'var(--chip)';
          return '<div class="pattern"><div class="pattern-head">' +
            '<div>' + p.emoji + ' ' + esc(p.text) + '</div>' +
            '<span>' + (stat ? pct + '% · ' + stat.days + ' days' : 'no answers yet') + '</span>' +
            '</div><div class="bar"><i style="width:' + pct + '%;background:' + color + '"></i></div></div>';
        }).join('');
    }

    var list = '<div class="section-title">Entries</div>' + all.map(function (k) {
      var entry = entries[k];
      var dots = settings.prompts.map(function (p) {
        var v = entry.answers[p.id];
        if (v !== 0 && v !== 1 && v !== -1) return '';
        return '<i style="background:var(--' + tone(v) + ')"></i>';
      }).join('');
      var line = entry.note.trim()
        ? '<p>' + esc(entry.note.trim()) + '</p>'
        : '<p class="dim">' + esc(summary(entry)) + '</p>';
      return '<button type="button" class="entry" data-action="edit" data-day="' + esc(k) + '">' +
        '<span class="entry-top"><b>' + esc(relativeDay(k)) + '</b><span class="dots">' + dots + '</span></span>' +
        line + '</button>';
    }).join('');

    return stats + grid + patterns + list;
  }

  function renderHistory() { $('#history-body').innerHTML = historyHTML(); }

  // -------------------------------------------------------------- settings

  function settingsHTML() {
    var questions = settings.prompts.map(function (p, i) {
      return '<label class="row">' +
        '<span class="emoji">' + p.emoji + '</span>' +
        '<span class="label">' + esc(p.text) + '</span>' +
        (p.builtIn ? '' :
          '<button type="button" class="trash" data-action="delete-prompt" data-index="' + i + '" aria-label="Delete question">' +
          '<svg viewBox="0 0 24 24"><path d="M4.5 6.5h15M9 6.5V4.8h6v1.7M6.5 6.5l1 13h9l1-13"/></svg></button>') +
        '<span class="switch"><input type="checkbox" data-action="toggle-prompt" data-index="' + i + '"' +
        (p.enabled ? ' checked' : '') + ' aria-label="' + esc(p.text) + '"><span></span></span>' +
        '</label>';
    }).join('');

    var add = '<div class="add">' +
      '<input id="new-question" type="text" placeholder="Add your own question" autocapitalize="sentences">' +
      '<button type="button" data-action="add-prompt">Add</button></div>' +
      '<p class="note-text">Fewer is better. Three questions takes about ten seconds — which is the whole point.</p>';

    var theme = '<div class="section-title">Appearance</div><div class="segmented">' +
      ['dark', 'light', 'system'].map(function (t) {
        return '<button type="button" data-action="theme" data-theme="' + t + '" aria-pressed="' +
          (settings.theme === t ? 'true' : 'false') + '">' + t.charAt(0).toUpperCase() + t.slice(1) + '</button>';
      }).join('') + '</div>' +
      '<p class="note-text">Dark by default — this gets opened with the lights off.</p>';

    var reminder = '<div class="section-title">Reminder</div>' +
      '<p class="note-text">A web app can’t schedule its own nightly notification on iPhone. The reliable ' +
      'trick: set a repeating alarm, or a Shortcuts automation at your bedtime that opens Nightly.</p>';

    var backup = '<div class="section-title">Backup</div>' +
      '<button type="button" class="wide-btn" data-action="copy-backup">Copy all entries as JSON</button>' +
      '<a class="wide-btn" id="download-backup" download="nightly-backup.json">Download backup file</a>' +
      '<textarea class="paste" id="restore-input" placeholder="Paste a backup here to restore it"></textarea>' +
      '<button type="button" class="wide-btn" data-action="restore">Restore from pasted backup</button>' +
      '<p class="note-text">Everything is stored on this phone only — nothing is sent anywhere. ' +
      'That also means clearing Safari’s website data would wipe it, so grab a backup now and then.</p>';

    var danger = '<div class="section-title">Danger</div>' +
      '<button type="button" class="wide-btn danger" data-action="delete-all">Delete all entries</button>';

    var about = '<div class="section-title">About</div>' +
      '<p class="note-text">Checking in at 1am is still last night’s entry — the day rolls over at ' +
      CUTOFF_HOUR + 'am.<br>Nightly · works offline once added to your home screen.</p>';

    return '<div class="section-title">Questions</div>' + questions + add + theme + reminder + backup + danger + about;
  }

  function renderSettings() {
    $('#settings-body').innerHTML = settingsHTML();
    var link = $('#download-backup');
    if (link) {
      try {
        link.href = URL.createObjectURL(new Blob([backupJSON()], { type: 'application/json' }));
      } catch (e) {
        link.remove();
      }
    }
  }

  function backupJSON() {
    return JSON.stringify({ app: 'nightly', version: 1, entries: entries, settings: settings }, null, 2);
  }

  // ---------------------------------------------------------------- sheets

  function openSheet(id) {
    flushNote();
    if (id === 'sheet-history') renderHistory();
    if (id === 'sheet-settings') renderSettings();
    var sheet = document.getElementById(id);
    sheet.classList.add('open');
    sheet.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  }

  function closeSheets() {
    flushNote();
    var open = document.querySelectorAll('.sheet.open');
    for (var i = 0; i < open.length; i++) {
      open[i].classList.remove('open');
      open[i].setAttribute('aria-hidden', 'true');
    }
    document.body.style.overflow = '';
    renderToday();
  }

  function openEditor(day) {
    $('#edit-title').textContent = shortFmt.format(parseKey(day));
    $('#edit-body').innerHTML = cardHTML(day);
    autosizeAll();
    var sheet = document.getElementById('sheet-edit');
    sheet.classList.add('open');
    sheet.setAttribute('aria-hidden', 'false');
  }

  function closeEditor() {
    flushNote();
    var sheet = document.getElementById('sheet-edit');
    sheet.classList.remove('open');
    sheet.setAttribute('aria-hidden', 'true');
    // Drop the card so a stale note field can't be written back later.
    $('#edit-body').innerHTML = '';
    renderHistory();
    renderToday();
  }

  // ----------------------------------------------------------- confirmation

  var confirmTimer = null;

  function showConfirmation(day) {
    $('#confirm-line').textContent = summary(entryFor(day));
    var overlay = $('#confirm');
    overlay.classList.add('open');
    overlay.setAttribute('aria-hidden', 'false');
    clearTimeout(confirmTimer);
    confirmTimer = setTimeout(hideConfirmation, 1700);
  }

  function hideConfirmation() {
    clearTimeout(confirmTimer);
    var overlay = $('#confirm');
    overlay.classList.remove('open');
    overlay.setAttribute('aria-hidden', 'true');
  }

  // ------------------------------------------------------------------ note

  var noteTimer = null;

  function autosize(el) {
    el.style.height = 'auto';
    el.style.height = Math.max(62, el.scrollHeight) + 'px';
  }

  function autosizeAll() {
    var areas = document.querySelectorAll('.note-input');
    for (var i = 0; i < areas.length; i++) autosize(areas[i]);
  }

  /* Writes any pending note text before anything re-renders the card. */
  function flushNote() {
    clearTimeout(noteTimer);
    var areas = document.querySelectorAll('.note-input');
    for (var i = 0; i < areas.length; i++) setNote(areas[i].dataset.day, areas[i].value);
  }

  // ---------------------------------------------------------------- theme

  function applyTheme() {
    var chosen = settings.theme;
    var dark = chosen === 'dark' ||
      (chosen === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', dark ? '#0e0f16' : '#f4f4fa');
  }

  // --------------------------------------------------------------- events

  document.addEventListener('click', function (event) {
    var el = event.target.closest('[data-action]');
    if (!el) {
      if (event.target.closest('#confirm')) hideConfirmation();
      return;
    }
    var action = el.dataset.action;

    if (action === 'rate') {
      var day = el.dataset.day;
      toggleRating(day, el.dataset.prompt, Number(el.dataset.value));
      buzz();
      // Update in place so the note field keeps focus and the caret.
      var group = el.closest('.ratings');
      var buttons = group.querySelectorAll('.rating');
      for (var i = 0; i < buttons.length; i++) {
        var on = buttons[i] === el && entries[day].answers[el.dataset.prompt] === Number(el.dataset.value);
        buttons[i].setAttribute('aria-pressed', on ? 'true' : 'false');
      }
      refreshDoneButton(day);
      return;
    }

    if (action === 'finish') {
      var finishDay = el.dataset.day;
      flushNote();
      ensure(finishDay);
      saveEntries();
      buzz();
      if (finishDay === todayKey() && !el.closest('#sheet-edit')) {
        renderToday();
        showConfirmation(finishDay);
      } else {
        closeEditor();
      }
      return;
    }

    if (action === 'open-history') { openSheet('sheet-history'); return; }
    if (action === 'open-settings') { openSheet('sheet-settings'); return; }
    if (action === 'close-sheet') {
      if (el.closest('#sheet-edit')) closeEditor();
      else closeSheets();
      return;
    }
    if (action === 'edit') { openEditor(el.dataset.day); return; }

    if (action === 'hide-install') { settings.hideInstall = true; saveSettings(); renderToday(); return; }

    if (action === 'add-prompt') {
      var input = $('#new-question');
      var text = input.value.trim();
      if (!text) return;
      settings.prompts.push({
        id: 'custom-' + Date.now(),
        text: text,
        emoji: '✨',
        enabled: true,
        builtIn: false
      });
      saveSettings();
      renderSettings();
      return;
    }

    if (action === 'delete-prompt') {
      settings.prompts.splice(Number(el.dataset.index), 1);
      saveSettings();
      renderSettings();
      return;
    }

    if (action === 'theme') {
      settings.theme = el.dataset.theme;
      saveSettings();
      applyTheme();
      renderSettings();
      return;
    }

    if (action === 'copy-backup') {
      var payload = backupJSON();
      var done = function () { el.textContent = 'Copied ✓'; setTimeout(function () { el.textContent = 'Copy all entries as JSON'; }, 1800); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(payload).then(done, function () { window.prompt('Copy your backup:', payload); });
      } else {
        window.prompt('Copy your backup:', payload);
      }
      return;
    }

    if (action === 'restore') {
      var raw = $('#restore-input').value.trim();
      if (!raw) return;
      try {
        var parsed = JSON.parse(raw);
        var incoming = parsed.entries || parsed;
        if (typeof incoming !== 'object') throw new Error('bad shape');
        Object.keys(incoming).forEach(function (k) { entries[k] = incoming[k]; });
        if (parsed.settings && Array.isArray(parsed.settings.prompts)) {
          settings = parsed.settings;
          mergeNewBuiltIns();
          saveSettings();
          applyTheme();
        }
        saveEntries();
        renderSettings();
        renderToday();
        window.alert('Restored. Nothing was deleted — the backup was merged in.');
      } catch (e) {
        window.alert("That doesn't look like a Nightly backup.");
      }
      return;
    }

    if (action === 'delete-all') {
      if (!window.confirm('Delete every entry? This cannot be undone.')) return;
      entries = {};
      saveEntries();
      renderSettings();
      renderToday();
      return;
    }
  });

  document.addEventListener('change', function (event) {
    var el = event.target.closest('[data-action="toggle-prompt"]');
    if (!el) return;
    settings.prompts[Number(el.dataset.index)].enabled = el.checked;
    saveSettings();
    renderToday();
  });

  document.addEventListener('input', function (event) {
    var el = event.target;
    if (!el.classList.contains('note-input')) return;
    autosize(el);
    clearTimeout(noteTimer);
    noteTimer = setTimeout(function () { setNote(el.dataset.day, el.value); }, 400);
  });

  document.addEventListener('focusout', function (event) {
    if (event.target.classList && event.target.classList.contains('note-input')) {
      setNote(event.target.dataset.day, event.target.value);
    }
  });

  function refreshDoneButton(day) {
    var button = document.querySelector('.done[data-day="' + day + '"]');
    if (!button) return;
    var isToday = day === todayKey();
    button.innerHTML = '<svg viewBox="0 0 24 24" class="glyph"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>' +
      esc(isToday ? 'Saved — tap to update' : 'Save changes');
  }

  // The day can roll over while the app sits open in the background.
  var shownKey = todayKey();
  function checkRollover() {
    if (todayKey() !== shownKey) {
      shownKey = todayKey();
      flushNote();
      renderToday();
    }
  }
  document.addEventListener('visibilitychange', function () { if (!document.hidden) checkRollover(); });
  window.addEventListener('focus', checkRollover);
  window.addEventListener('pagehide', flushNote);

  if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
      if (settings.theme === 'system') applyTheme();
    });
  }

  applyTheme();
  renderToday();

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('./sw.js').catch(function () { /* offline support is a bonus */ });
    });
  }
})();
