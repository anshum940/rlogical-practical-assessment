'use strict';

const http = require('node:http');

function createApp() {
  return http.createServer((request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ status: 'ok' }));
      return;
    }

    if (request.method === 'GET' && request.url === '/') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ message: 'DevOps practical application' }));
      return;
    }

    response.writeHead(404, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'not_found' }));
  });
}

function parsePort(value) {
  const port = Number.parseInt(value, 10);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Invalid PORT value: ${value}`);
  }

  return port;
}

function start() {
  const port = parsePort(process.env.PORT || '3000');
  const server = createApp();

  server.listen(port, '0.0.0.0', () => {
    console.log(`Application listening on port ${port}`);
  });

  const shutdown = (signal) => {
    console.log(`Received ${signal}; shutting down`);

    server.close((error) => {
      if (error) {
        console.error('Graceful shutdown failed', error);
        process.exitCode = 1;
      }
    });

    setTimeout(() => {
      console.error('Graceful shutdown timed out');
      process.exit(1);
    }, 10000).unref();
  };

  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT', () => shutdown('SIGINT'));

  return server;
}

if (require.main === module) {
  start();
}

module.exports = { createApp, parsePort };
