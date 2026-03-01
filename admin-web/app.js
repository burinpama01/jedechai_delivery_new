;(function () {
  function loadScript(src, opts) {
    return new Promise(function (resolve, reject) {
      try {
        var s = document.createElement('script');
        s.src = src;
        if (opts && opts.type) s.type = opts.type;
        s.onload = function () { resolve(true); };
        s.onerror = function (e) { reject(e); };
        document.head.appendChild(s);
      } catch (e) {
        reject(e);
      }
    });
  }

  async function bootstrap() {
    try {
      if (!window.__adminWebBridge || typeof window.__adminWebBridge.initSupabase !== 'function') {
        var hasMain = Array.from(document.scripts || []).some(function (s) {
          var u = String((s && s.src) || '');
          return u.includes('/src/main.js') || u.endsWith('src/main.js');
        });
        if (!hasMain) {
          await loadScript('src/main.js', { type: 'module' });
        }
      }
    } catch (_) {
      // ignore
    }

    try {
      await loadScript('app.legacy.js');
    } catch (e) {
      try { console.error('Failed to load app.legacy.js', e); } catch (_) {}
    }
  }

  bootstrap();
})();