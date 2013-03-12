# LogStashLogger [![Build Status](https://travis-ci.org/dwbutler/logstash-logger.png?branch=master)](https://travis-ci.org/dwbutler/logstash-logger)

This gem implements a subclass of Ruby's Logger class that logs directly to [logstash](http://logstash.net).
It writes to a logstash listener over a TCP connection, in logstash JSON format. This is an improvement over
writing to a file or syslog since logstash can receive the structured data directly.

## Features

* Writes directly to logstash over a TCP connection.
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

## Usage

First set up a logstash agent to receive input over a TCP port.

```ruby
logger = LogStashLogger.new('localhost', 5228)
logger.info 'test'
# Logs {"@source":"server-host-name","@tags":[],"@fields":{"severity":"INFO"},"@message":"test","@timestamp":"2012-12-15T00:48:29+00:00"}
```

## Rails integration

Add the following to your config/environments/production.rb:

```ruby
config.logger = ActiveSupport::TaggedLogging.new(LogStashLogger.new('localhost', 5228))
```

To get Rails to nicely output its logs in structured logstash format, try one of the following gems:

* [lograge](https://github.com/roidrage/lograge)
* [yarder](https://github.com/rurounijones/yarder)

Currently these gems output a JSON string, which LogStashLogger then parses.
Future versions of these gems could potentially have deeper integration with LogStashLogger.

## Ruby compatibility

Verified to work with:

* Ruby 1.9.3
* Ruby 2.0.0
* JRuby 1.7+ (1.9 mode)

Ruby 1.8.7 is not supported because LogStash::Event is not compatible with Ruby 1.8.7. This might change in the future.

Rubinius might work, but I haven't been able to test it.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
