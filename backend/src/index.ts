import app, { startServer } from './app';

if (!process.env.VERCEL) {
  startServer();
}

// @ts-ignore
module.exports = app;
// @ts-ignore
module.exports.default = app;

export default app;

