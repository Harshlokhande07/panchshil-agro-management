// Main SPA shell for Panchshil Agro app
const App = {
  user: null,
  currentModule: 'dashboard',
  init() {
    this.bindNav();
    this.loadUser();
  },
  bindNav() {
    document.querySelectorAll('.nav-link[data-module]').forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
        this.currentModule = link.dataset.module;
        this.loadModule(this.currentModule);
      });
    });
    document.getElementById('btnLogout').addEventListener('click', async () => {
      await fetch('/api/logout', { method: 'POST' });
      window.location.href = '/login.html';
    });
  },
  async loadUser() {
    try {
      const res = await fetch('/api/me');
      const data = await res.json();
      if (!data.loggedIn) {
        window.location.href = '/login.html';
        return;
      }
      this.user = data.user;
      window.currentUser = data.user;
      document.getElementById('userInfo').textContent = `${this.user.username} (${this.user.role})`;
      // hide admin-only nav
      if (this.user.role !== 'admin') {
        document.querySelectorAll('.admin-only').forEach(el => el.style.display = 'none');
      }
      this.loadModule('dashboard');
    } catch (e) {
      window.location.href = '/login.html';
    }
  },
  loadModule(name) {
    const container = document.getElementById('moduleContainer');
    container.innerHTML = '<div class="text-muted p-3">Loading...</div>';
    fetch(`/modules/${name}.html`)
      .then(r => r.text())
      .then(html => {
        container.innerHTML = html;
        // execute scripts in loaded module
        container.querySelectorAll('script').forEach(oldScript => {
          const newScript = document.createElement('script');
          Array.from(oldScript.attributes).forEach(attr => newScript.setAttribute(attr.name, attr.value));
          newScript.textContent = oldScript.textContent;
          oldScript.parentNode.replaceChild(newScript, oldScript);
        });
        // call init if exists
        const modName = `Module${name.charAt(0).toUpperCase() + name.slice(1).replace(/-([a-z])/g, g=>g[1].toUpperCase())}`;
        let mod = window[modName];
        if (!mod) {
          try {
            mod = eval(`(typeof ${modName} !== 'undefined') ? ${modName} : null`);
          } catch(e) {}
        }
        if (mod && typeof mod.init === 'function') {
          mod.init(this.user);
        }
      })
      .catch(err => {
        container.innerHTML = `<div class="alert alert-danger">Failed to load module: ${name}. ${err.message}</div>`;
      });
  }
};

function showToast(msg, type='success') {
  const container = document.getElementById('toastContainer');
  if(!container) return;
  const toast = document.createElement('div');
  toast.className = `toast align-items-center text-bg-${type === 'error' ? 'danger' : 'success'} border-0 show`;
  toast.innerHTML = `<div class="d-flex"><div class="toast-body">${msg}</div><button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>`;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

document.addEventListener('DOMContentLoaded', () => App.init());
window.showToast = showToast;
