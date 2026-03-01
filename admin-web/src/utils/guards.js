const _processing = {};

export function btnGuard(key, fn) {
  return async function (...args) {
    if (_processing[key]) return;
    _processing[key] = true;
    const btn = document.activeElement;
    if (btn?.tagName === "BUTTON") {
      btn.disabled = true;
      btn.style.opacity = "0.6";
    }
    try {
      await fn(...args);
    } finally {
      _processing[key] = false;
      if (btn?.tagName === "BUTTON") {
        btn.disabled = false;
        btn.style.opacity = "1";
      }
    }
  };
}
