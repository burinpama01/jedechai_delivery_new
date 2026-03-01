export function showToast(message, type = "success") {
  const toast = document.createElement("div");
  const styles = {
    success: "background:linear-gradient(135deg,#10b981,#14b8a6); color:white;",
    error: "background:linear-gradient(135deg,#f43f5e,#ec4899); color:white;",
    info: "background:linear-gradient(135deg,#6366f1,#818cf8); color:white;",
  };
  const icons = { success: "check_circle", error: "error", info: "info" };
  toast.className = "fixed bottom-6 right-6 z-50 fade-in";
  toast.innerHTML = `<div class="flex items-center gap-3 px-5 py-3.5 rounded-2xl shadow-2xl text-sm font-semibold" style="${styles[type] || styles.info}">
    <span class="material-icons-round text-lg">${icons[type] || "info"}</span> ${message}
  </div>`;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transition = "opacity 0.5s";
    setTimeout(() => toast.remove(), 500);
  }, 3000);
}
