document.getElementById('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const username = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value;
  const msg = document.getElementById('loginMsg');
  msg.textContent = '';
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    if (!res.ok) {
      msg.textContent = data.error || 'Login failed';
      return;
    }
    window.location.href = '/app';
  } catch (err) {
    msg.textContent = 'Network error';
  }
});
