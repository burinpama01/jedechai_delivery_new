const _state = {
  supabase: null,
  supabaseAuth: null,
  currentUser: null,
  session: null,
  currentPage: "dashboard",
};

export function getState() {
  return _state;
}

export function setState(patch) {
  Object.assign(_state, patch || {});
  return _state;
}
