const express = require('express');
const router = express.Router();

// Simple in-memory log (for demo) - just echoes back last queries from client? 
// Frontend will display query text per request; this is a fallback
router.get('/log', (req, res) => {
  res.json({ log: [] });
});

module.exports = router;
