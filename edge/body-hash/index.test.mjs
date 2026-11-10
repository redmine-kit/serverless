import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';

const { bodyHash, handler } = createRequire(import.meta.url)('./index.js');

const EMPTY = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

function event(body, headers = {}) {
  return { Records: [{ cf: { request: { method: 'POST', uri: '/issues', headers, body } } }] };
}

test('no body gets the hash of an empty body', async () => {
  const request = await handler(event(undefined));
  assert.equal(request.headers['x-amz-content-sha256'][0].value, EMPTY);
});

test('an empty body gets the hash of an empty body', async () => {
  const request = await handler(event({ inputTruncated: false, action: 'read-only', encoding: 'base64', data: '' }));
  assert.equal(request.headers['x-amz-content-sha256'][0].value, EMPTY);
});

test('a base64 body is hashed over its bytes', async () => {
  const form = Buffer.from('utf8=%E2%9C%93&issue%5Bsubject%5D=%E6%97%A5%E6%9C%AC%E8%AA%9E');
  const request = await handler(event({ encoding: 'base64', data: form.toString('base64') }));
  assert.equal(request.headers['x-amz-content-sha256'][0].value, sha256(form));
});

test('a binary body is hashed over its bytes, not a string', async () => {
  const bytes = randomBytes(4096);
  assert.equal(bodyHash({ encoding: 'base64', data: bytes.toString('base64') }), sha256(bytes));
  assert.notEqual(sha256(bytes), sha256(Buffer.from(bytes.toString('latin1'), 'utf8')));
});

test('a multipart form is hashed over its bytes', () => {
  const boundary = '----x';
  const bytes = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="a.png"\r\n\r\n`),
    randomBytes(512),
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);
  assert.equal(bodyHash({ encoding: 'base64', data: bytes.toString('base64') }), sha256(bytes));
});

test('a text body is hashed as UTF-8', () => {
  assert.equal(bodyHash({ encoding: 'text', data: '日本語' }), sha256(Buffer.from('日本語', 'utf8')));
});

test('a header sent by the viewer is replaced', async () => {
  const headers = { 'x-amz-content-sha256': [{ key: 'x-amz-content-sha256', value: 'forged' }] };
  const request = await handler(event(undefined, headers));
  assert.equal(request.headers['x-amz-content-sha256'].length, 1);
  assert.equal(request.headers['x-amz-content-sha256'][0].value, EMPTY);
});

test('a truncated body gets 413 and is not sent to the origin', async () => {
  const response = await handler(event({ inputTruncated: true, encoding: 'base64', data: 'AAAA' }));
  assert.equal(response.status, '413');
  assert.equal(response.uri, undefined);
});

test('the other parts of the request are kept', async () => {
  const request = await handler(event(undefined, { host: [{ key: 'Host', value: 'example.com' }] }));
  assert.equal(request.uri, '/issues');
  assert.equal(request.method, 'POST');
  assert.equal(request.headers.host[0].value, 'example.com');
});

const s3 = (method, uri, headers = {}) => ({
  Records: [{ cf: { request: { method, uri, headers, origin: { s3: { domainName: 'b.s3.amazonaws.com' } } } } }],
});

test('an upload to S3 gets the checksum from its key', async () => {
  const bytes = randomBytes(64);
  const hex = sha256(bytes);
  const request = await handler(s3('PUT', `/tmp/incoming/0f8fad5b-d9cb-469f-a165-70867728950e.${hex}`));
  assert.equal(request.headers['x-amz-checksum-sha256'][0].value, Buffer.from(hex, 'hex').toString('base64'));
  assert.equal(request.headers['x-amz-content-sha256'], undefined, 'origin access control hashes S3 requests');
});

test('other requests to S3 get no header', async () => {
  for (const [method, uri] of [['GET', '/tmp/thumbnails/d_1_100.thumb'], ['PUT', '/tmp/incoming/no-checksum'],
    ['PUT', '/tmp/bulk/z.zip'], ['GET', '/files/2026/11/a.txt']]) {
    const request = await handler(s3(method, uri));
    assert.deepEqual(request.headers, {}, `${method} ${uri}`);
  }
});

test('the template carries the same source', () => {
  const source = readFileSync(new URL('./index.js', import.meta.url), 'utf8');
  const template = readFileSync(new URL('../../infra/shared-edge.yaml', import.meta.url), 'utf8');
  const start = template.indexOf('// redmine-body-hash');
  assert.notEqual(start, -1, 'the function source is not in infra/shared-edge.yaml');
  const lines = source.trimEnd().split('\n');
  const inTemplate = template.slice(start).split('\n').slice(0, lines.length).map((line) => line.replace(/^ {10}/, ''));
  assert.deepEqual(inTemplate, lines);
});
