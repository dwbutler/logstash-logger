# Output Configuration

## Logstash Listener Configuration

In order for logstash to correctly receive and parse the events, you will need to
configure and run a listener that uses the `json_lines` codec. For example, to receive
events over UDP on port 5228:

```ruby
input {
  udp {
    host => "0.0.0.0"
    port => 5228
    codec => json_lines
  }
}
```

File and Redis inputs should use the `json` codec instead. For more information
read the [Logstash docs](https://www.elastic.co/guide/en/logstash/current/plugins-codecs-json_lines.html).

See the [samples](https://github.com/dwbutler/logstash-logger/tree/master/samples) directory for more configuration samples.

## HTTP

Supports rudimentary writes (buffered, non-persistent connections) to the [Logstash HTTP Input](https://www.elastic.co/guide/en/logstash/current/plugins-inputs-http.html):

```ruby
input {
  http {
    port => 8080
  }
}
```

```ruby
LogStashLogger.new \
  type: :http,
  url: 'http://localhost:8080'
```

A batch that gets an error status is retried on the next flush. If the collector rejects the content
(400, 413, 415 or 422), the records are sent one at a time and only the rejected ones are dropped.
See [Records that can never be delivered](buffering.md#records-that-can-never-be-delivered).

Note the parameter is `url` and not `uri`. Relies on [Net:HTTP](https://ruby-doc.org/stdlib-2.7.1/libdoc/net/http/rdoc/Net/HTTP.html#class-Net::HTTP-label-HTTPS) to auto-detect SSL usage from the scheme.

By default, each batch is sent as a JSON array, which is what the Logstash HTTP Input expects. For endpoints that expect newline-delimited JSON (NDJSON), with one event per line, set `format: :ndjson`:

```ruby
LogStashLogger.new \
  type: :http,
  url: 'https://example.com:8071/?token=TOKEN',
  format: :ndjson
```

The `format` option accepts `:json_array` (the default) or `:ndjson`. With `:ndjson` the request is sent with `Content-Type: application/x-ndjson`; with `:json_array` it uses `application/json`. If your endpoint expects a different header, set it explicitly with `content_type`:

```ruby
LogStashLogger.new \
  type: :http,
  url: 'https://example.com:8071/?token=TOKEN',
  format: :ndjson,
  content_type: 'application/json'
```
