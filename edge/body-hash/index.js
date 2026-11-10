// redmine-body-hash: Lambda@Edge on the origin request of Redmine's behaviors
// (docs/lambda.md#function-that-adds-the-body-hash-lambdaedge). CloudFront
// signs requests to the Lambda function URL with origin access control,
// which needs the SHA256 of the body in x-amz-content-sha256 for requests
// with a body. node:crypto only, no npm packages. CommonJS, because the
// template carries this file as the function's inline code (index.js).
'use strict';
const { createHash } = require('node:crypto');

const HEADER = 'x-amz-content-sha256';

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

async function handler(event) {
  const { request } = event.Records[0].cf;

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

module.exports = { bodyHash, handler };
