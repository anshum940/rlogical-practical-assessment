'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { after, before, describe, it } = require('node:test');

const { createApp, parsePort } = require('../server');

function request(port, path) {
  return new Promise((resolve, reject) => {
    const clientRequest = http.get(
      {
        hostname: '127.0.0.1',
        port,
        path,
        timeout: 2000,
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => {
          body += chunk;
        });
        response.on('end', () => {
          resolve({ statusCode: response.statusCode, body });
        });
      },
    );

    clientRequest.on('error', reject);
    clientRequest.on('timeout', () => {
      clientRequest.destroy(new Error('Request timed out'));
    });
  });
}

describe('HTTP service', () => {
  let server;
  let port;

  before(async () => {
    server = createApp();
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    port = server.address().port;
  });

  after(async () => {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  it('returns a healthy status', async () => {
    const response = await request(port, '/health');

    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), { status: 'ok' });
  });

  it('returns the application response', async () => {
    const response = await request(port, '/');

    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), {
      message: 'DevOps practical application',
    });
  });

  it('returns 404 for an unknown path', async () => {
    const response = await request(port, '/missing');

    assert.equal(response.statusCode, 404);
    assert.deepEqual(JSON.parse(response.body), { error: 'not_found' });
  });
});

describe('port validation', () => {
  it('accepts a valid TCP port', () => {
    assert.equal(parsePort('3000'), 3000);
  });

  it('rejects an invalid TCP port', () => {
    assert.throws(() => parsePort('70000'), /Invalid PORT value/);
  });
});
