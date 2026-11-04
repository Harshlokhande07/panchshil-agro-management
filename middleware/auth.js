// ---------------------------------------------------------------------------
// Session-based authentication and role-based authorization.
// Roles: admin, staff, accountant
// ---------------------------------------------------------------------------

// Must be logged in
function requireLogin(req, res, next) {
  if (req.session && req.session.user) {
    return next();
  }
  if (req.accepts('html')) {
    return res.redirect('/login.html');
  }
  return res.status(401).json({ error: 'Not logged in' });
}

// Allow only the listed roles
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session || !req.session.user) {
      if (req.accepts('html')) return res.redirect('/login.html');
      return res.status(401).json({ error: 'Not logged in' });
    }
    if (roles.includes(req.session.user.role)) {
      return next();
    }
    if (req.accepts('html')) {
      return res.status(403).send('403 Forbidden: insufficient role');
    }
    return res.status(403).json({ error: 'Forbidden: insufficient role' });
  };
}

module.exports = { requireLogin, requireRole };
