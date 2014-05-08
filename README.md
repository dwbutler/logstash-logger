# LogStashLogger [![Build Status](https://travis-ci.org/dwbutler/logstash-logger.png?branch=master)](https://travis-ci.org/dwbutler/logstash-logger)

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
Then in ruby, create a LogStashLogger that writes to that port.

```ruby
require 'logstash-logger'

# Defaults to UDP
logger = LogStashLogger.new('localhost', 5228)
logger.info 'test'
# Writes the following to UDP port 5228:
# {"@source":"server-host-name","@tags":[],"@fields":{"severity":"INFO"},"@message":"test","@timestamp":"2013-04-08T18:56:23.767273+00:00"}

# Specify UDP or TCP explicitly
udp_logger = LogStashLogger.new('localhost', 5228, :udp)
tcp_logger = LogStashLogger.new('localhost', 5229, :tcp)
```

## Logstash configuration

To configure Logstash to correctly parse the event, you can create a JSON filter to point to the *message* portion:

```ruby
filter {
  json {
    source => "message"
  }
}
```

For more information on Filtering, check out the official Logstash docs.

## Rails integration

Add the following to your config/environments/production.rb:

```ruby
logger = LogStashLogger.new('localhost', 5228)
logger.level = Logger::INFO # default is Logger::DEBUG
config.logger = ActiveSupport::TaggedLogging.new(logger)
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

* MRI Ruby 1.9.3
* MRI Ruby 2.0.0
* JRuby 1.7+ (1.9 mode)

Ruby 1.8.7 is not supported because LogStash::Event is not compatible with Ruby 1.8.7. This will probably not change.

The specs don't pass in Rubinius yet, but the logger does work.

## Breaking changes

### Version 0.4+
Logstash::Event decided to go ahead and break the existing JSON format starting in version 1.2+. If you're using this version, you'll need to install
LogStashLogger version 0.4+. This is not backwards compatible with the old LogStash::Event v1.1.5.

### Version 0.3+
Earlier versions of this gem (<= 0.2.1) only implemented a TCP connection. Newer versions (>= 0.3) also implement UDP, and use that as the new default.
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
