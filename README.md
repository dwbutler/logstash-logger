# LogStashLogger
[![Build Status](https://travis-ci.org/dwbutler/logstash-logger.png?branch=master)](https://travis-ci.org/dwbutler/logstash-logger) [![Code Climate](https://codeclimate.com/github/dwbutler/logstash-logger.png)](https://codeclimate.com/github/dwbutler/logstash-logger)

This gem implements a subclass of Ruby's Logger class that logs directly to [logstash](http://logstash.net).
It writes to a logstash listener over a UDP (default) or TCP connection, in logstash JSON format. This is an improvement over
writing to a file or syslog since logstash can receive the structured data directly.

## Features

* Writes directly to logstash over a UDP or TCP connection.
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

# Defaults to UDP
logger = LogStashLogger.new('localhost', 5228)

# Specify UDP or TCP explicitly
udp_logger = LogStashLogger.new('localhost', 5228, :udp)
tcp_logger = LogStashLogger.new('localhost', 5229, :tcp)

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

## Logstash configuration

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

## Rails integration

Add the following to your `config/environments/production.rb`:

```ruby
# Optional, defaults to 'localhost'
config.logstash.host = 'localhost'

# Required
config.logstash.port = 5228

# Optional, defaults to :udp. Possible values are :udp or :tcp
config.logstash.type = :udp

# Optional, Rails sets the default to :info
config.log_level = :debug
```

To get Rails to nicely output its logs in structured logstash format, try one of the following gems:

* [lograge](https://github.com/roidrage/lograge)
* [yarder](https://github.com/rurounijones/yarder)

Currently these gems output a JSON string, which LogStashLogger then parses.
Future versions of these gems could potentially have deeper integration with LogStashLogger (i.e. by writing LogStash::Event objects).

## UDP vs TCP
Should you write to a UDP or TCP listener? It depends on your specific needs, but most applications should use the default (UDP).

* UDP is faster because it's asynchronous (fire-and-forget). However, this means that log messages could get dropped. This is okay for most applications.
* TCP verifies that every message has been received via two-way communication . This could slow your app down to a crawl if the TCP listener is under heavy load.

For a more detailed discussion of UDP vs TCP, I recommend reading this article: [UDP vs. TCP](http://gafferongames.com/networking-for-game-programmers/udp-vs-tcp/)

## Ruby compatibility

Verified to work with:

* MRI Ruby 1.9.3, 2.0+, 2.1+
* JRuby 1.7+

Ruby 1.8.7 is not supported because `LogStash::Event` is not compatible with Ruby 1.8.7. This will probably not change.

The specs don't pass in Rubinius yet, but the logger does work.

## Breaking changes

### Version 0.5+ (Unreleased)
The `source` key has been replaced with `host` to better match the latest logstash.

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
