# Usage Examples

## Basic Usage

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
```

## Using Formatters

```ruby
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
```

## Multiple Outputs

```ruby
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
```

## Logging Messages

```ruby
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
