const jwt = require('jsonwebtoken');

/// Similar to requireAuth, but does not block if the token is missing or invalid.
/// If a valid token is provided, it attaches req.userId.
function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.sub;
  } catch (err) {
    // Ignore invalid tokens for optional auth
  }
  
  next();
}

module.exports = optionalAuth;
