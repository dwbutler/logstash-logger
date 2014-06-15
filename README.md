# LogStashLogger
[![Build Status](https://travis-ci.org/dwbutler/logstash-logger.png?branch=master)](https://travis-ci.org/dwbutler/logstash-logger) [![Code Climate](https://codeclimate.com/github/dwbutler/logstash-logger.png)](https://codeclimate.com/github/dwbutler/logstash-logger)

This gem implements a subclass of Ruby's Logger class that logs directly to [logstash](http://logstash.net).
It writes to a logstash listener over a UDP (default) or TCP connection, in logstash JSON format. This is an improvement over
writing to a file or syslog since logstash can receive the structured data directly.

## Features

* Can write directly to logstash over a UDP or TCP/SSL connection.
* Can write to a file or to stdout (for debugging).
* Always writes in logstash JSON format.
* Logger can take a string message, a hash, a LogStash::Event, or a logstash-formatted json string as input.
* Events are automatically populated with message, timestamp, host, and severity.

## Installation

Add this line to your application's Gemfile:

    gem 'logstash-logger'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install logstash-logger

## Basic Usage

First set up a logstash agent to receive input over a UDP or TCP port.
Then in ruby, create a `LogStashLogger` that writes to that port.

The logger accepts a string message, a JSON string, a hash, or a `LogStash::Event`.

```ruby
require 'logstash-logger'

# Defaults to UDP on 0.0.0.0
logger = LogStashLogger.new(port: 5228)

# Specify host and type (UDP or TCP) explicitly
udp_logger = LogStashLogger.new(host: 'localhost', port: 5228, type: :udp)
tcp_logger = LogStashLogger.new(host: 'localhost', port: 5229, type: :tcp)

# Other types of loggers
stdout_logger = LogStashLogger.new(type: :stdout)
file_logger = LogStashLogger.new(type: :file, path: 'log/development.log', sync: true)
unix_logger = LogStashLogger.new(type: :unix, path: '/tmp/sock')
redis_logger = LogStashLogger.new(type: :redis)

# The following messages are written to UDP port 5228:

logger.info 'test'
# {"message":"test","@timestamp":"2014-05-22T09:37:19.204-07:00","@version":"1","severity":"INFO","host":"[hostname]"}

logger.error '{"message": "error"}'
# {"message":"error","@timestamp":"2014-05-22T10:10:55.877-07:00","@version":"1","severity":"ERROR","host":"[hostname]"}

logger.debug message: 'test', foo: 'bar'
# {"message":"test","foo":"bar","@timestamp":"2014-05-22T09:43:24.004-07:00","@version":"1","severity":"DEBUG","host":"[hostname]"}

logger.warn LogStash::Event.new(message: 'test', foo: 'bar')
# {"message":"test","foo":"bar","@timestamp":"2014-05-22T16:44:37.364Z","@version":"1","severity":"WARN","host":"[hostname]"}

# Tagged logging
logger.tagged('foo') { logger.fatal('bar') }
# {"message":"bar","@timestamp":"2014-05-26T20:35:14.685-07:00","@version":"1","severity":"FATAL","host":"[hostname]","tags":["foo"]}
```

## Logstash Configuration

In order for Logstash to correctly receive and parse the event, you will need to
configure and run a UDP listener that uses the `json_lines` codec:

```ruby
input {
  udp {
    host => "0.0.0.0"
    port => 5228
    codec => json_lines
  }
}
```

See the [samples](https://github.com/dwbutler/logstash-logger/tree/master/samples) directory for more configuration samples.

## UDP vs TCP
Should you write to a UDP or TCP listener? It depends on your specific needs, but most applications should use the default (UDP).

* UDP is faster because it's asynchronous (fire-and-forget). However, this means that log messages could get dropped. This is okay for most applications.
* TCP verifies that every message has been received via two-way communication . This could slow your app down to a crawl if the TCP listener is under heavy load.

For a more detailed discussion of UDP vs TCP, I recommend reading this article: [UDP vs. TCP](http://gafferongames.com/networking-for-game-programmers/udp-vs-tcp/)

## SSL

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

## Rails Integration

Verified to work with both Rails 3 and 4.

Add the following to your `config/environments/production.rb`:

### Common Options

```ruby
# Optional, Rails sets the default to :info
config.log_level = :debug

# Optional, Rails 4 defaults to true in development and false in production
config.autoflush_log = true
```

### UDP
```ruby
# Optional, defaults to '0.0.0.0'
config.logstash.host = 'localhost'

# Optional, defaults to :udp.
config.logstash.type = :udp

# Required, the port to connect to
config.logstash.port = 5228
```

### TCP

```ruby
# Optional, defaults to '0.0.0.0'
config.logstash.host = 'localhost'

# Required, the port to connect to
config.logstash.port = 5228

# Required
config.logstash.type = :tcp

# Optional, enables SSL
config.logstash.ssl_enable = true
```

### Unix Socket

```ruby
# Required
config.logstash.type = :unix

# Required
config.logstash.path = '/tmp/sock'
```

### Redis

```ruby
# Required
config.logstash.type = :redis

# Optional, will default to the 'logstash' list
config.logstash.list = 'logstash'

# All other options are passed in to the Redis client
# Supported options include host, port, path, password, url
# Example:

# Optional, Redis will default to localhost
config.logstash.host = 'localhost'

# Optional, Redis will default to port 6379
config.logstash.port = 6379
```

### File

```ruby
# Required
config.logstash.type = :file

# Optional, defaults to Rails log path
config.logstash.path = 'log/production.log'
```

By default, every Rails log message will be written to logstash in `LogStash::Event` JSON format.

For minimal, more-structured logstash events, try one of the following gems:

* [lograge](https://github.com/roidrage/lograge)
* [yarder](https://github.com/rurounijones/yarder)

Currently these gems output a JSON string, which LogStashLogger then parses.
Future versions of these gems could potentially have deeper integration with LogStashLogger (i.e. by writing `LogStash::Event` objects).

## Ruby Compatibility

Verified to work with:

* MRI Ruby 1.9.3, 2.0+, 2.1+
* JRuby 1.7+
* Rubinius 2.2+

Ruby 1.8.7 is not supported.

## Breaking changes

### Version 0.5+
 * The `source` event key has been replaced with `host` to better match the latest logstash.
 * The `(host, port, type)` constructor has been deprecated in favor of an options hash constructor.

### Version 0.4+
`LogStash::Event` uses the v1 format starting version 1.2+. If you're using the v1, you'll need to install
LogStashLogger version 0.4+. This is not backwards compatible with the old `LogStash::Event` v1.1.5, which uses
the v0 format.

### Version 0.3+
Earlier versions of this gem (<= 0.2.1) only implemented a TCP connection.
Newer versions (>= 0.3) also implement UDP, and use that as the new default.
Please be aware if you are using the default constructor and still require TCP, you should add an additional argument:

```ruby
# Now defaults to UDP instead of TCP
logger = LogStashLogger.new('localhost', 5228)
# Explicitly specify TCP instead of UDP
logger = LogStashLogger.new('localhost', 5228, :tcp)
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
