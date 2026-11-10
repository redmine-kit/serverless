// Runs the CloudFront Function's source as CloudFront does: a plain script
// whose handler(event) is called. The script keeps the file's URL, so that
// the coverage counts it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const url = new URL('./index.js', import.meta.url);
const source = readFileSync(url, 'utf8');
const context = vm.createContext({});
new vm.Script(source, { filename: url.href }).runInContext(context);
const { handler } = context;

const CSP = "default-src 'none'; style-src 'unsafe-inline'; sandbox";
const event = (querystring = {}, statusCode = 200) => ({
  request: { method: 'GET', uri: '/files/2026/11/a.html', querystring },
  response: { statusCode, headers: { 'content-type': { value: 'application/octet-stream' } } },
});

test('every response gets the sandbox CSP', () => {
  for (const status of [200, 403, 404]) {
    const { headers } = handler(event({}, status));
    assert.equal(headers['content-security-policy'].value, CSP);
  }
});

test('the signed overrides set the file name and type', () => {
  const { headers } = handler(event({
    'response-content-disposition': { value: "attachment%3B%20filename%3D%22a.txt%22%3B%20filename*%3DUTF-8''%25E6%2597%25A5.txt" },
    'response-content-type': { value: 'text%2Fplain' },
  }));
  assert.equal(headers['content-disposition'].value, "attachment; filename=\"a.txt\"; filename*=UTF-8''%E6%97%A5.txt");
  assert.equal(headers['content-type'].value, 'text/plain');
});

test('without overrides, S3 headers stay', () => {
  const { headers } = handler(event());
  assert.equal(headers['content-type'].value, 'application/octet-stream');
  assert.equal(headers['content-disposition'], undefined);
});

test('malformed or header-splitting values are ignored', () => {
  const { headers } = handler(event({
    'response-content-disposition': { value: '%E0%A4%A' },
    'response-content-type': { value: 'text%2Fhtml%0D%0ASet-Cookie%3A%20x' },
  }));
  assert.equal(headers['content-disposition'], undefined);
  assert.equal(headers['content-type'].value, 'application/octet-stream');
  const raw = handler(event({ 'response-content-disposition': { value: 'attachment%3B%20filename%3D%22%E6%97%A5%22' } })).headers;
  assert.equal(raw['content-disposition'], undefined);
  assert.equal(headers['content-type'].value, 'application/octet-stream');
});

test('error responses get no overrides', () => {
  const { headers } = handler(event({ 'response-content-type': { value: 'text%2Fhtml' } }, 403));
  assert.equal(headers['content-type'].value, 'application/octet-stream');
});

test('the template carries the same source', () => {
  const template = readFileSync(new URL('../../infra/instance.yaml', import.meta.url), 'utf8');
  const start = template.indexOf('// redmine-attachment-headers');
  assert.notEqual(start, -1, 'the function source is not in infra/instance.yaml');
  const lines = source.trimEnd().split('\n');
  const inTemplate = template.slice(start).split('\n').slice(0, lines.length).map((line) => line.replace(/^ {10}/, ''));
  assert.deepEqual(inTemplate, lines);
});
