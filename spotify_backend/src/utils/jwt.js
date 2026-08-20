const jwt = require('jsonwebtoken');

function signToken(userId) {
  const secret = process.env.JWT_SECRET || 'fallback_secret_do_not_use_in_prod';
  return jwt.sign({ sub: userId }, secret, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

module.exports = { signToken };
