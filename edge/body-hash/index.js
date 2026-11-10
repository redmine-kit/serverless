// redmine-body-hash: Lambda@Edge on the origin request of Redmine's behaviors
// (docs/lambda.md#function-that-adds-the-body-hash-lambdaedge). CloudFront
// signs requests to the Lambda function URL with origin access control,
// which needs the SHA256 of the body in x-amz-content-sha256 for requests
// with a body. On the attachments' /tmp/* behavior it adds the checksum of
// an upload instead: browsers PUT to /tmp/incoming/<UUID>.<SHA256 hex>, a
// signed URL, and S3 checks the body against x-amz-checksum-sha256, taken
// from that key, so that no viewer header has to be forwarded to S3.
// node:crypto only, no npm packages. CommonJS, because the template carries
// this file as the function's inline code (index.js).
'use strict';
const { createHash } = require('node:crypto');

const HEADER = 'x-amz-content-sha256';
const CHECKSUM = 'x-amz-checksum-sha256';
const UPLOAD = /^\/tmp\/incoming\/[0-9a-f-]{36}\.([0-9a-f]{64})$/;

// The SHA256 of the body as CloudFront passes it: base64 (IncludeBody) is
// decoded to bytes first, so binary bodies and multipart forms hash the same
// as the bytes the browser sent.
function bodyHash(body) {
  const hash = createHash('sha256');
  if (body && body.data) {
    hash.update(Buffer.from(body.data, body.encoding === 'text' ? 'utf8' : 'base64'));
  }
  return hash.digest('hex');
}

// The checksum S3 checks an upload against, from the key; nothing for other
// requests to S3.
function uploadChecksum(request) {
  const match = request.method === 'PUT' && UPLOAD.exec(request.uri);
  return match ? Buffer.from(match[1], 'hex').toString('base64') : null;
}

async function handler(event) {
  const { request } = event.Records[0].cf;

  if (request.origin && request.origin.s3) {
    const checksum = uploadChecksum(request);
    if (checksum) {
      request.headers[CHECKSUM] = [{ key: CHECKSUM, value: checksum }];
    }
    return request;
  }

  // Over 1 MB, CloudFront passes only the start of the body. A hash of that
  // would not match, and the function URL would refuse the request anyway.
  if (request.body && request.body.inputTruncated) {
    return {
      status: '413',
      statusDescription: 'Payload Too Large',
      headers: {
        'content-type': [{ key: 'Content-Type', value: 'text/plain; charset=utf-8' }],
        'cache-control': [{ key: 'Cache-Control', value: 'no-store' }],
      },
      body: 'The request body is larger than 1 MB.\n',
    };
  }

  request.headers[HEADER] = [{ key: HEADER, value: bodyHash(request.body) }];
  return request;
}

module.exports = { bodyHash, handler, uploadChecksum };
