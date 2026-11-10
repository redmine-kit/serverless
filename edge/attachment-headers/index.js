// redmine-attachment-headers: CloudFront Function (cloudfront-js-2.0) on the
// viewer response of the attachments' behaviors (/files/* and /tmp/*).
// Attachments are served from Redmine's origin, so they get the sandbox CSP
// that Redmine's AttachmentsController sets; nosniff comes from the managed
// SecurityHeadersPolicy. The file name and type come from the signed URL's
// response-content-disposition and response-content-type, which are not
// forwarded to S3: with the signature in the same query string, S3 would
// refuse the request.
var CSP = "default-src 'none'; style-src 'unsafe-inline'; sandbox";
var OVERRIDES = { 'response-content-disposition': 'content-disposition', 'response-content-type': 'content-type' };

function handler(event) {
  var response = event.response;
  var query = event.request.querystring;
  response.headers['content-security-policy'] = { value: CSP };
  if (response.statusCode !== 200 && response.statusCode !== 206 && response.statusCode !== 304) {
    return response;
  }
  for (var name in OVERRIDES) {
    var value = decode(query[name]);
    if (value) {
      response.headers[OVERRIDES[name]] = { value: value };
    }
  }
  return response;
}

// The value of a query string parameter, decoded; nothing if it is missing,
// malformed, or not printable ASCII, as header values must be.
function decode(param) {
  if (!param || !param.value) {
    return null;
  }
  try {
    var value = decodeURIComponent(param.value.replace(/\+/g, ' '));
    return /^[\x20-\x7e]+$/.test(value) ? value : null;
  } catch (e) {
    return null;
  }
}
