// Lambda@Edge Authentication Function
exports.handler = async (event, context) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;
    
    // Add security headers
    const response = {
        status: '200',
        statusDescription: 'OK',
        headers: {
            'strict-transport-security': [{
                key: 'Strict-Transport-Security',
                value: 'max-age=31536000; includeSubDomains'
            }],
            'x-content-type-options': [{
                key: 'X-Content-Type-Options',
                value: 'nosniff'
            }],
            'x-frame-options': [{
                key: 'X-Frame-Options',
                value: 'DENY'
            }],
            'x-xss-protection': [{
                key: 'X-XSS-Protection',
                value: '1; mode=block'
            }],
            'content-security-policy': [{
                key: 'Content-Security-Policy',
                value: "default-src 'self'"
            }]
        }
    };
    
    return response;
};