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

Note the parameter is `url` and not `uri`. Relies on [Net:HTTP](https://ruby-doc.org/stdlib-2.7.1/libdoc/net/http/rdoc/Net/HTTP.html#class-Net::HTTP-label-HTTPS) to auto-detect SSL usage from the scheme.
