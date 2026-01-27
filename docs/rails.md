# Rails Integration

Supports Rails 7.2, 8.0, and 8.1.

By default, every Rails log message will be written to logstash in `LogStash::Event` JSON format.

For minimal, more-structured logstash events, try one of the following gems:

* [lograge](https://github.com/roidrage/lograge)
* [yarder](https://github.com/rurounijones/yarder)

Currently these gems output a JSON string, which LogStashLogger then parses.
Future versions of these gems could potentially have deeper integration with LogStashLogger
(e.g. by directly writing `LogStash::Event` objects).

## Rails Configuration

Add the following to your `config/environments/production.rb`:

### Common Options

```ruby
# Optional, Rails sets the default to :info
config.log_level = :debug

# Optional, defaults to true in development and false in production
config.autoflush_log = false

# Optional, use a URI to configure
config.logstash.uri = ENV['LOGSTASH_URI']

# Optional. Defaults to :json_lines. If there are multiple outputs,
# they will all share the same formatter.
config.logstash.formatter = :json_lines

# Optional, the logger to log writing errors to. Defaults to logging to $stderr
config.logstash.error_logger = Logger.new($stderr)

# Optional, max number of items to buffer before flushing. Defaults to 50
config.logstash.buffer_max_items = 50

# Optional, max number of seconds to wait between flushes. Defaults to 5
config.logstash.buffer_max_interval = 5

# Optional, drop message when a connection error occurs. Defaults to false
config.logstash.drop_messages_on_flush_error = false

# Optional, drop messages when the buffer is full. Defaults to true
config.logstash.drop_messages_on_full_buffer = true
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

### Syslog

`Syslog::Logger` is built into the standard library for Ruby 3.2+.

```ruby
# Required
config.logstash.type = :syslog

# Optional. Defaults to 'ruby'
config.logstash.program_name = 'MyApp'

# Optional default facility level. Only works in Ruby 2+
config.logstash.facility = Syslog::LOG_LOCAL0
```

### Redis

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

### Kafka

Add the ruby-kafka gem to your Gemfile:

    gem 'ruby-kafka'

```ruby
# Required
config.logstash.type = :kafka

# Required
config.logstash.topic = 'logstash-topic'

# Required, can be in one of two formats:
# String format (splits on single space):
config.logstash.brokers = 'localhost:9092 some-other-host.net:9300'
# Array format
config.logstash.brokers = %w(localhost:9092 some-other-host.net:9300)

# Optional, defaults to 'ruby-kafka'
config.logstash.client_id = 'logstash-client-alpha'

# Optional, transmit over TLS
# NOTE: either 0 or all 3 ssl_parameters must be provided for a
# successful connection. An exception will be raised if 1 or 2 params
# are povided
config.logstash.ssl_ca_cert: ENV['CLOUDKAFKA_CA']
config.logstash.ssl_client_cert: ENV['CLOUDKAFKA_CERT']
config.logstash.ssl_client_cert_key: ENV['CLOUDKAFKA_PRIVATE_KEY']
```

### Kinesis

Add the aws-sdk gem to your Gemfile:

    # aws-sdk >= 3.0
    gem 'aws-sdk-kinesis'

    # aws-sdk < 3.0
    gem 'aws-sdk'

```ruby
# Required
config.logstash.type = :kinesis

# Optional, will default to the 'logstash' stream
config.logstash.stream = 'my-stream-name'

# Optional, will default to 'us-east-1'
config.logstash.aws_region = 'us-west-2'

# Optional, will default to the AWS_ACCESS_KEY_ID environment variable
config.logstash.aws_access_key_id = 'ASKASKHLD12341'

# Optional, will default to the AWS_SECRET_ACCESS_KEY environment variable
config.logstash.aws_secret_access_key = 'ASKASKHLD1234123412341234'
```

### Firehose

Add the aws-sdk gem to your Gemfile:

    # aws-sdk >= 3.0
    gem 'aws-sdk-firehose'

    # aws-sdk < 3.0
    gem 'aws-sdk'

```ruby
# Required
config.logstash.type = :firehose

# Optional, will default to the 'logstash' delivery stream
config.logstash.stream = 'my-stream-name'

# Optional, will default to AWS default region config chain
config.logstash.aws_region = 'us-west-2'

# Optional, will default to AWS default credential provider chain
config.logstash.aws_access_key_id = 'ASKASKHLD12341'

# Optional, will default to AWS default credential provider chain
config.logstash.aws_secret_access_key = 'ASKASKHLD1234123412341234'
```

### File

```ruby
# Required
config.logstash.type = :file

# Optional, defaults to Rails log path
config.logstash.path = 'log/production.log'

# Optional, enable log rotation
config.logstash.shift_age = 7
config.logstash.shift_size = 10 * 1024 * 1024

# Optional, time-based rotation
config.logstash.shift_age = 'daily' # or 'weekly'/'monthly'
config.logstash.shift_period_suffix = '%Y-%m-%d'
```

### IO

```ruby
# Required
config.logstash.type = :io

# Required
config.logstash.io = io
```

### Multi Delegator

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

### Multi Logger

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

## Logging HTTP request data

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

## Cleaning up resources when forking

If your application forks (as is common with many web servers) you will need to
manage cleaning up resources on your LogStashLogger instances. The instance method
`#reset` is available for this purpose. Here is sample configuration for
several common web servers used with Rails:

### Passenger

```ruby
::PhusionPassenger.on_event(:starting_worker_process) do |forked|
  Rails.logger.reset
end
```

### Puma

```ruby
# In config/puma.rb
on_worker_boot do
  Rails.logger.reset
end
```

### Unicorn

```ruby
# In config/unicorn.rb
after_fork do |server, worker|
  Rails.logger.reset
end
```
