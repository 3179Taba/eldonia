const express = require('express');
const router = express.Router();

// ログイン
router.post('/login', (req, res) => {
  const { email, password } = req.body;
  
  // TODO: 実際の認証ロジックを実装
  if (email && password) {
    res.json({
      message: 'Login successful',
      token: 'dummy-jwt-token',
      user: { email, id: '1' }
    });
  } else {
    res.status(400).json({ error: 'Email and password required' });
  }
});

// 登録
router.post('/register', (req, res) => {
  const { email, password, name } = req.body;
  
  // TODO: 実際の登録ロジックを実装
  if (email && password && name) {
    res.status(201).json({
      message: 'User registered successfully',
      user: { email, name, id: '1' }
    });
  } else {
    res.status(400).json({ error: 'All fields required' });
  }
});

module.exports = router;
