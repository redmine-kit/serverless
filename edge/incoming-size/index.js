// redmine-incoming-size: CloudFront Function (cloudfront-js-2.0) on the
// viewer request of /incoming/*, where browsers PUT attachments to S3
// through signed URLs. A signed URL cannot limit the size, so this rejects a
// request whose Content-Length is over the limit before it reaches S3. The
// limit is written in when the deployment creates the function.
var MAX_BYTES = __MAX_BYTES__;

function handler(event) {
  var request = event.request;
  if (request.method !== 'PUT') {
    return request;
  }
  var header = request.headers['content-length'];
  if (!header || !/^[0-9]+$/.test(header.value)) {
    return reply(411, 'Length Required', 'A Content-Length is required.\n');
  }
  if (Number(header.value) > MAX_BYTES) {
    return reply(413, 'Payload Too Large', 'The file is larger than the upload limit.\n');
  }
  return request;
}

function reply(statusCode, statusDescription, body) {
  return {
    statusCode: statusCode,
    statusDescription: statusDescription,
    headers: { 'content-type': { value: 'text/plain; charset=utf-8' }, 'cache-control': { value: 'no-store' } },
    body: body,
  };
}
