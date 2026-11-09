// Runs the CloudFront Function's source as CloudFront does: a plain script
// whose handler(event) is called, with the limit written in. The script
// keeps the file's URL, so that the coverage counts it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const url = new URL('./index.js', import.meta.url);
const source = readFileSync(url, 'utf8');

export function load(maxBytes) {
  const context = vm.createContext({});
  // Padded to the placeholder's length, so that the offsets in the coverage
  // match the file.
  const limit = String(maxBytes).padStart('__MAX_BYTES__'.length);
  new vm.Script(source.replace('__MAX_BYTES__', limit), { filename: url.href }).runInContext(context);
  return context.handler;
}

const handler = load(1000);
const put = (length) => ({
  request: {
    method: 'PUT',
    uri: '/tmp/incoming/a',
    headers: length === undefined ? {} : { 'content-length': { value: String(length) } },
  },
});

test('a PUT within the limit passes', () => {
  assert.equal(handler(put(1000)).uri, '/tmp/incoming/a');
  assert.equal(handler(put(0)).uri, '/tmp/incoming/a');
});

test('a PUT over the limit gets 413', () => {
  assert.equal(handler(put(1001)).statusCode, 413);
});

test('a PUT without a valid Content-Length gets 411', () => {
  assert.equal(handler(put(undefined)).statusCode, 411);
  assert.equal(handler(put('12abc')).statusCode, 411);
  assert.equal(handler(put('-1')).statusCode, 411);
});

test('other methods pass', () => {
  const event = { request: { method: 'OPTIONS', uri: '/tmp/incoming/a', headers: {} } };
  assert.equal(handler(event).uri, '/tmp/incoming/a');
});

test('the template carries the same source', () => {
  const template = readFileSync(new URL('../../infra/instance.yaml', import.meta.url), 'utf8');
  const start = template.indexOf('// redmine-incoming-size');
  assert.notEqual(start, -1, 'the function source is not in infra/instance.yaml');
  const lines = source.trimEnd().split('\n');
  const inTemplate = template.slice(start).split('\n').slice(0, lines.length).map((line) => line.replace(/^ {10}/, ''));
  assert.deepEqual(inTemplate.map((l) => l.replace('${MaxUploadBytes}', '__MAX_BYTES__')), lines);
});
