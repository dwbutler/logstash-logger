# LogStashLogger
[![Build Status](https://travis-ci.org/dwbutler/logstash-logger.svg?branch=master)](https://travis-ci.org/dwbutler/logstash-logger) [![Code Climate](https://codeclimate.com/github/dwbutler/logstash-logger/badges/gpa.svg)](https://codeclimate.com/github/dwbutler/logstash-logger) [![codecov.io](http://codecov.io/github/dwbutler/logstash-logger/coverage.svg?branch=master)](http://codecov.io/github/dwbutler/logstash-logger?branch=master)

LogStashLogger extends Ruby's `Logger` class to log directly to [logstash](http://logstash.net).
It supports writing to various outputs in logstash JSON format. This is an improvement over
writing to a file or syslog since logstash can receive the structured data directly.

## Features

* Can write directly to a logstash listener over a UDP or TCP/SSL connection.
* Can write to a file, Redis, Kafka, a unix socket, syslog, stdout, or stderr.
* Logger can take a string message, a hash, a `LogStash::Event`, an object, or a JSON string as input.
* Events are automatically populated with message, timestamp, host, and severity.
* Writes in logstash JSON format, but supports other formats as well.
* Can write to multiple outputs.
* Log messages are buffered and automatically re-sent if there is a connection problem.
* Easily integrates with Rails via configuration.

## Installation

Add this line to your application's Gemfile:

    gem 'logstash-logger'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install logstash-logger

## Usage Examples

```ruby
require 'logstash-logger'

# Defaults to UDP on 0.0.0.0
logger = LogStashLogger.new(port: 5228)

# Specify host and type (UDP or TCP) explicitly
udp_logger = LogStashLogger.new(type: :udp, host: 'localhost', port: 5228)
tcp_logger = LogStashLogger.new(type: :tcp, host: 'localhost', port: 5229)

# Other types of loggers
file_logger = LogStashLogger.new(type: :file, path: 'log/development.log', sync: true)
unix_logger = LogStashLogger.new(type: :unix, path: '/tmp/sock')
syslog_logger = LogStashLogger.new(type: :syslog)
redis_logger = LogStashLogger.new(type: :redis)
kafka_logger = LogStashLogger.new(type: :kafka)
stdout_logger = LogStashLogger.new(type: :stdout)
stderr_logger = LogStashLogger.new(type: :stderr)
io_logger = LogStashLogger.new(type: :io, io: io)

# Use a different formatter
cee_logger = LogStashLogger.new(
  type: :tcp,
  host: 'logsene-receiver-syslog.sematext.com',
  port: 514,
  formatter: :cee_syslog
)

custom_formatted_logger = LogStashLogger.new(
  type: :redis,
  formatter: MyCustomFormatter
)

lambda_formatted_logger = LogStashLogger.new(
  type: :stdout,
  formatter: ->(severity, time, progname, msg) { "[#{progname}] #{msg}" }
)

ruby_default_formatter_logger = LogStashLogger.new(
  type: :file,
  path: 'log/development.log',
  formatter: ::Logger::Formatter
)

# Send messages to multiple outputs. Each output will have the same format.
# Syslog cannot be an output because it requires a separate logger.
multi_delegating_logger = LogStashLogger.new(
  type: :multi_delegator,
  outputs: [
    { type: :file, path: 'log/development.log' },
    { type: :udp, host: 'localhost', port: 5228 }
  ])

# Balance messages between several outputs.
# Works the same as multi delegator, but randomly chooses an output to send each message.
balancer_logger = LogStashLogger.new(
  type: :balancer,
  outputs: [
    { type: :udp, host: 'host1', port: 5228 },
    { type: :udp, host: 'host2', port: 5228 }
  ])

# Send messages to multiple loggers.
# Use this if you need to send different formats to different outputs.
# If you need to log to syslog, you must use this.
multi_logger = LogStashLogger.new(
  type: :multi_logger,
  outputs: [
    { type: :file, path: 'log/development.log', formatter: ::Logger::Formatter },
    { type: :tcp, host: 'localhost', port: 5228, formatter: :json }
  ])

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

## URI Configuration
You can use a URI to configure your logstash logger instead of a hash. This is useful in environments
such as Heroku where you may want to read configuration values from the environment. The URI scheme
is `type://host:port/path?key=value`. Some sample URI configurations are given below.

```
udp://localhost:5228
tcp://localhost:5229
unix:///tmp/socket
file:///path/to/file
redis://localhost:6379
kafka://localhost:9092
stdout:/
stderr:/
```

Pass the URI into your logstash logger like so:

```ruby
# Read the URI from an environment variable
logger = LogStashLogger.new(uri: ENV['LOGSTASH_URI'])
```

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

See the [samples](https://github.com/dwbutler/logstash-logger/tree/master/samples) directory for more configuration samples.

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

## Custom Log Fields

`LogStashLogger` by default will log a JSON object with the format below.

```json
{
  "message":"Some Message",
  "@timestamp":"2015-01-29T10:43:32.196-05:00",
  "@version":"1",
  "severity":"INFO",
  "host":"hostname"
}
```

Some applications may need to attach additional metadata to each message.
The `LogStash::Event` can be manipulated directly by specifying a `customize_event` block in the `LogStashLogger` configuration.

```ruby
config = LogStashLogger.configure do |config|
  config.customize_event do |event|
    event["other_field"] = "some_other_value"
  end
end
```

This configuration would result in the following output.

```json
{
    "message": "Some Message",
    "@timestamp": "2015-01-29T10:43:32.196-05:00",
    "@version": "1",
    "severity": "INFO",
    "host": "hostname",
    "other_field": "some_other_value"
}
```

## Buffering / Automatic Retries

Log messages are buffered internally, and automatically re-sent if there is a connection problem.
Outputs that support batch writing (Redis and Kafka) will write log messages in bulk from the
buffer. This functionality is implemented using
[Stud::Buffer](https://github.com/jordansissel/ruby-stud/blob/master/lib/stud/buffer.rb).
You can configure its behavior by passing the following options to LogStashLogger:

    :buffer_max_items - Max number of items to buffer before flushing. Defaults to 50.
    :buffer_max_interval - Max number of seconds to wait between flushes. Defaults to 5.

You can turn this behavior off by setting `buffer_max_items` to `1` or `sync` to `true`.

Please be aware of the following caveats to this behavior:

 * It's possible for duplicate log messages to be sent when retrying. For outputs like Redis and
   Kafka that write in batches, the whole batch could get re-sent. If this is a problem, you
   can add a UUID field to each event to uniquely identify it. You can either do this
   in a `customize_event` block, or by using logstash's
   [UUID filter](https://www.elastic.co/guide/en/logstash/current/plugins-filters-uuid.html).
 * It's still possible to lose log messages. Ruby won't detect a TCP/UDP connection problem
   immediately. In my testing, it took Ruby about 4 seconds to notice the receiving end was down
   and start raising exceptions. Since logstash listeners over TCP/UDP do not acknowledge received
   messages, it's not possible to know which log messages to re-send.
 * If your output source is unavailable long enough, writing to the log will block until it is
   available again. This could make your application unresponsive.
 * If your application suddenly terminates (for example, by SIGKILL or a power outage), the whole
   buffer will be lost.

You can make message loss and application blockage less likely by increasing `buffer_max_items`
(so that more events can be held in the buffer), and increasing `buffer_max_interval` (to wait
longer between flushes). This will increase memory pressure on your application as log messages
accumulate in the buffer, so make sure you have allocated enough memory to your process.

## Rails Integration

Verified to work with both Rails 3 and 4.

By default, every Rails log message will be written to logstash in `LogStash::Event` JSON format.

For minimal, more-structured logstash events, try one of the following gems:

* [lograge](https://github.com/roidrage/lograge)
* [yarder](https://github.com/rurounijones/yarder)

Currently these gems output a JSON string, which LogStashLogger then parses.
Future versions of these gems could potentially have deeper integration with LogStashLogger
(e.g. by directly writing `LogStash::Event` objects).

### Rails Configuration

Add the following to your `config/environments/production.rb`:

#### Common Options

```ruby
# Optional, Rails sets the default to :info
config.log_level = :debug

# Optional, Rails 4 defaults to true in development and false in production
config.autoflush_log = true

# Optional, use a URI to configure. Useful on Heroku
config.logstash.uri = ENV['LOGSTASH_URI']

# Optional. Defaults to :json_lines. If there are multiple outputs,
# they will all share the same formatter.
config.logstash.formatter = :json_lines

# Optional, max number of items to buffer before flushing. Defaults to 50
config.logstash.buffer_max_items = 50

# Optional, max number of seconds to wait between flushes. Defaults to 5
config.logstash.buffer_max_interval = 5
```

#### UDP
```ruby
# Optional, defaults to '0.0.0.0'
config.logstash.host = 'localhost'

# Optional, defaults to :udp.
config.logstash.type = :udp

# Required, the port to connect to
config.logstash.port = 5228
```

#### TCP

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

#### Unix Socket

```ruby
# Required
config.logstash.type = :unix

# Required
config.logstash.path = '/tmp/sock'
```

#### Syslog

If you're on Ruby 1.9, add `Syslog::Logger` v2 to your Gemfile:

    gem 'SyslogLogger', '2.0'

If you're on Ruby 2+, `Syslog::Logger` is already built into the standard library.

```ruby
# Required
config.logstash.type = :syslog

# Optional. Defaults to 'ruby'
config.logstash.program_name = 'MyApp'

# Optional default facility level. Only works in Ruby 2+
config.logstash.facility = Syslog::LOG_LOCAL0
```

#### Redis

Add the redis gem to your Gemfile:

    gem 'redis'

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

#### Kafka

Add the poseidon gem to your Gemfile:

    gem 'poseidon'

```ruby
# Required
config.logstash.type = :kafka

# Optional, will default to the 'logstash' topic
config.logstash.path = 'logstash'

# Optional, will default to the 'logstash-logger' producer
config.logstash.producer = 'logstash-logger'

# Optional, will default to localhost:9092 host/port
config.logstash.hosts = ['localhost:9092']

# Optional, will default to 1s backoff
config.logstash.backoff = 1

```

#### File

```ruby
# Required
config.logstash.type = :file

# Optional, defaults to Rails log path
config.logstash.path = 'log/production.log'
```

#### IO

```ruby
# Required
config.logstash.type = :io

# Required
config.logstash.io = io
```

#### Multi Delegator

```ruby
# Required
config.logstash.type = :multi_delegator

# Required
config.logstash.outputs = [
  {
    type: :file,
    path: 'log/production.log'
  },
  {
    type: :udp,
    port: 5228,
    host: 'localhost'
  }
]
```

#### Multi Logger

```ruby
# Required
config.logstash.type = :multi_logger

# Required. Each logger may have its own formatter.
config.logstash.outputs = [
  {
    type: :file,
    path: 'log/production.log',
    formatter: ::Logger::Formatter
  },
  {
    type: :udp,
    port: 5228,
    host: 'localhost'
  }
]
```

### Logging HTTP request data

In web applications, you can log data from HTTP requests (such as headers) using the
[RequestStore](https://github.com/steveklabnik/request_store) middleware. The following
example assumes Rails.

```ruby
# in Gemfile
gem 'request_store'
```

```ruby
# in application.rb
LogStashLogger.configure do |config|
  config.customize_event do |event|
    event["session_id"] = RequestStore.store[:load_balancer_session_id]
  end
end
```

```ruby
# in app/controllers/application_controller.rb
before_filter :track_load_balancer_session_id

def track_load_balancer_session_id
  RequestStore.store[:load_balancer_session_id] = request.headers["X-LOADBALANCER-SESSIONID"]
end
```

## Ruby Compatibility

Verified to work with:

* MRI Ruby 1.9.3, 2.0, 2.1, 2.2, 2.3
* JRuby 1.7, 9.0
* Rubinius 2.2

Ruby 1.8.7 is not supported.

## What type of logger should I use?

It depends on your specific needs, but most applications should use the default (UDP). Here are the advantages and
disadvantages of each type:

* UDP is faster than TCP because it's asynchronous (fire-and-forget). However, this means that log messages could get dropped.
  This is okay for many applications.
* TCP verifies that every message has been received via two-way communication. It also supports SSL for secure transmission
  of log messages over a network. This could slow your app down to a crawl if the TCP listener is under heavy load.
* A file is simple to use, but you will have to worry about log rotation and running out of disk space.
* Writing to a Unix socket is faster than writing to a TCP or UDP port, but only works locally.
* Writing to Redis is good for distributed setups that generate tons of logs. However, you will have another moving part and
  have to worry about Redis running out of memory.
* Writing to stdout is only recommended for debugging purposes.

For a more detailed discussion of UDP vs TCP, I recommend reading this article:
[UDP vs. TCP](http://gafferongames.com/networking-for-game-programmers/udp-vs-tcp/)

## Troubleshooting

### JSON::GeneratorError
Your application is probably attempting to log data that is not encoded in a valid way. When this happens, Ruby's
standard JSON library will raise an exception. You may be able to overcome this by swapping out a different JSON encoder
such as Oj. Use the [oj_mimic_json](https://github.com/ohler55/oj_mimic_json) gem to use Oj for JSON generation.

### No logs getting sent on Heroku
Heroku recommends installing the [rails_12factor](https://github.com/heroku/rails_12factor) so that logs get sent to STDOUT.
Unfortunately, this overrides LogStashLogger, preventing logs from being sent to their configured destination. The solution
is to remove `rails_12factor` from your Gemfile.

### Logging eventually stops in production
This is most likely not a problem with LogStashLogger, but rather a different gem changing the log level of `Rails.logger`.
This is especially likely if you're using a threaded server such as Puma, since gems often change the log level of
`Rails.logger` in a non thread-safe way. See [#17](https://github.com/dwbutler/logstash-logger/issues/17) for more information.

### Sometimes two lines of JSON log messages get sent as one message
If you're using UDP output and writing to a logstash listener, you are most likely encountering a bug in the UDP implementation
of the logstash listener. There is no known fix at this time. See [#43](https://github.com/dwbutler/logstash-logger/issues/43)
for more information.

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

## Contributors
* [David Butler](https://github.com/dwbutler)
* [pctj101](https://github.com/pctj101)
* [Gary Rennie](https://github.com/Gazler)
* [Nick Ethier](https://github.com/nickethier)
* [Arron Mabrey](https://github.com/arronmabrey)
* [Jan Schulte](https://github.com/schultyy)
* [Kurt Preston](https://github.com/KurtPreston)
* [Chris Blatchley](https://github.com/chrisblatchley)
* [Felix Bechstein](https://github.com/felixb)
* [Vadim Kazakov](https://github.com/yads)
* [Anil Rhemtulla](https://github.com/AnilRh)
* [Nikita Vorobei](https://github.com/Nikita-V)
* [fireboy1919](https://github.com/fireboy1919)
* [Mike Gunderloy](https://github.com/ffmike)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
