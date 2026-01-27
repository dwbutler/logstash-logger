# SSL Configuration

If you are using TCP then there is the option of adding an SSL certificate to the options hash on initialize.

```ruby
LogStashLogger.new(type: :tcp, port: 5228, ssl_certificate: "/path/to/certificate.crt")
```

The SSL certificate and key can be generated using

    openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout logstash.key -out logstash.crt

You can also enable SSL without a certificate:

```ruby
LogStashLogger.new(type: :tcp, port: 5228, ssl_enable: true)
```

Specify an SSL context to have more control over the behavior. For example,
set the verify mode:

```ruby
ctx = OpenSSL::SSL::SSLContext.new
ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
LogStashLogger.new(type: :tcp, port: 5228, ssl_context: ctx)
```

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

Hostname verification is enabled by default. Without further configuration,
the hostname supplied to `:host` will be used to verify the server's certificate
identity.

If you don't pass an `:ssl_context` or pass a falsey value to the
`:verify_hostname` option, hostname verification will not occur.

### Examples

**Verify the hostname from the `:host` option**

```ruby
ctx = OpenSSL::SSL::SSLContext.new
ctx.cert = '/path/to/cert.pem'
ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER

LogStashLogger.new \
  type: :tcp,
  host: 'logstash.example.com'
  port: 5228,
  ssl_context: ctx
```

**Verify a hostname different from the `:host` option**

```ruby
LogStashLogger.new \
  type: :tcp,
  host: '1.2.3.4'
  port: 5228,
  ssl_context: ctx,
  verify_hostname: 'server.example.com'
```

**Explicitly disable hostname verification**

```ruby
LogStashLogger.new \
  type: :tcp,
  host: '1.2.3.4'
  port: 5228,
  ssl_context: ctx,
  verify_hostname: false
```
