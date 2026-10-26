# SSL Configuration

The TCP output can connect to Logstash over TLS. The server certificate is always
verified, and so is the hostname, unless you opt out explicitly.

Enable TLS and verify the server against the system trust store:

```ruby
LogStashLogger.new(type: :tcp, host: 'logstash.example.com', port: 5228, ssl_enable: true)
```

If your Logstash server uses a self-signed certificate or a private CA, pass that
certificate (or CA bundle) as `ssl_certificate`. It is trusted in addition to the
system trust store, and TLS is enabled implicitly:

```ruby
LogStashLogger.new(type: :tcp, host: 'logstash.example.com', port: 5228, ssl_certificate: "/path/to/certificate.crt")
```

The file is checked when the logger is created, and an `ArgumentError` is raised
if it is missing or is not a certificate.

A self-signed certificate and key for the Logstash server can be generated with

    openssl req -x509 -batch -nodes -newkey rsa:2048 -subj "/CN=logstash.example.com" \
      -addext "subjectAltName=DNS:logstash.example.com" -keyout logstash.key -out logstash.crt

Use the name your clients connect to in the certificate.

Specify an SSL context for full control over the connection. For example, to
trust a private CA:

```ruby
ctx = OpenSSL::SSL::SSLContext.new
ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER, ca_file: '/path/to/ca.pem')
LogStashLogger.new(type: :tcp, host: 'logstash.example.com', port: 5228, ssl_context: ctx)
```

### Turning verification off

Verification can only be turned off with an explicit context. This exposes the
log stream to anyone who can intercept the connection, so use it only for local
testing:

```ruby
ctx = OpenSSL::SSL::SSLContext.new
ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
LogStashLogger.new(type: :tcp, host: 'localhost', port: 5228, ssl_context: ctx, verify_hostname: false)
```

Before 1.1.0, `ssl_enable: true` without an `ssl_context` did not verify the
server certificate. If you relied on that, either pass `ssl_certificate` with the
server's certificate, or use the explicit context above.

## Logstash Configuration for SSL

The following Logstash configuration is required for SSL:

```ruby
input {
  tcp {
    host => "0.0.0.0"
    port => 5228
    codec => json_lines
    ssl_enable => true
    ssl_cert => "/path/to/certificate.crt"
    ssl_key => "/path/to/key.key"
  }
}
```

## Hostname Verification

Hostname verification is enabled by default whenever TLS is used. The hostname
supplied to `:host` is checked against the server's certificate, and it is also
sent as the TLS server name (SNI) unless it is an IP address.

**Verify a hostname different from the `:host` option**

This is useful when connecting by IP address:

```ruby
LogStashLogger.new \
  type: :tcp,
  host: '1.2.3.4',
  port: 5228,
  ssl_certificate: '/path/to/certificate.crt',
  verify_hostname: 'logstash.example.com'
```

**Disable hostname verification**

The certificate chain is still verified:

```ruby
LogStashLogger.new \
  type: :tcp,
  host: '1.2.3.4',
  port: 5228,
  ssl_certificate: '/path/to/certificate.crt',
  verify_hostname: false
```
