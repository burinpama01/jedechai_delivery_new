const _registry = {};
let _activePage = null;

export function registerPage(name, renderer, opts = {}) {
  _registry[name] = {
    render: renderer,
    dispose: typeof opts.dispose === "function" ? opts.dispose : null,
  };
}

export function hasPage(name) {
  return !!_registry[name]?.render;
}

export function getActivePage() {
  return _activePage;
}

export async function disposeActivePage(ctx) {
  const name = _activePage;
  if (!name) return;
  const entry = _registry[name];
  const dispose = entry?.dispose;
  if (typeof dispose === "function") {
    await dispose(ctx);
  }
}

export async function renderPage(name, el, ctx) {
  const entry = _registry[name];
  const fn = entry?.render;
  if (typeof fn !== "function") {
    throw new Error(`unknown_page:${name}`);
  }
  _activePage = name;
  return await fn(el, ctx);
}

export function getRegistry() {
  return { ..._registry };
}
