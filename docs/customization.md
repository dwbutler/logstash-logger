# Customization

## Custom Log Fields

`LogStashLogger` by default will log a JSON object with the format below.

```json
{
  "@timestamp":"2015-01-29T10:43:32.196-05:00",
  "@version":"1",
  "message":"Some Message",
  "severity":"INFO",
  "host":"hostname"
}
```

Some applications may need to attach additional metadata to each message.
The `LogStash::Event` can be manipulated directly by specifying a `customize_event` block in the `LogStashLogger` configuration. (Note: this is run after the event has been generated, not before.)

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
    "@timestamp": "2015-01-29T10:43:32.196-05:00",
    "@version": "1",
    "message": "Some Message",
    "severity": "INFO",
    "host": "hostname",
    "other_field": "some_other_value"
}
```

This block has full access to the event, so you can remove fields, modify
existing fields, etc. For example, to remove the default timestamp:

```ruby
config = LogStashLogger.configure do |config|
  config.customize_event do |event|
    event.remove('@timestamp')
  end
end
```

You can also customize events on a per-logger basis by passing a callable object
(lambda or proc) to the `customize_event` option when creating a logger:

```ruby
LogStashLogger.new(customize_event: ->(event){ event['other_field'] = 'other_field' })
```

## Fields Set by the Log Call

A String message that starts with `{` is parsed as JSON, and a Hash message is
merged into the event. Those messages may set any field, except the fields
that describe the log call itself: `severity` is always the level of the
logger method that was called, `@timestamp` the time of the call and
`@version` `"1"`. If the message has its own value for one of these fields,
the value is moved under `message_fields` instead of being dropped:

```ruby
logger.error('{"message":"login failed","severity":"DEBUG"}')
# {"message":"login failed","severity":"ERROR","message_fields":{"severity":"DEBUG"},...}
```

If the message already has its own `message_fields`, nothing in it is lost: a
Hash is merged with the moved values, and its own keys win when both have the
same name; any other value is kept as `message_fields.message_fields`.

This keeps text such as a logged request body from changing how its own
record is classified or dated. A `LogStash::Event` message is used as given
and keeps its own `severity` and `@timestamp`.

A message may set `tags`. The tags of the enclosing `logger.tagged` blocks are
always added to them, and a single value such as `"tags":"api"` becomes the
Array `["api"]`. `host` is an ordinary field: a message may set it, and the
logger fills it in only when it is missing.

If every String and Hash message you log comes from code you trust, such as a
log formatter that already sets these fields, you can let messages set them:

```ruby
LogStashLogger.configure do |config|
  config.trust_message_fields = true
end
```

## Field Names

A Hash or `LogStash::Event` message may use Symbol or String keys. Every
top-level key is converted to a String before the event reaches a
`customize_event` block, so `logger.info(message: 'm', user: 'u')` is read as
`event['user']`, and a Symbol key such as `:host` names the same field as
`'host'`. If a message has both the Symbol and the String form of a key, the
String-keyed value is used.

## Logger Silencing

LogStashLogger provides support for Rails-style logger silencing. The
implementation was extracted from Rails, but has no dependencies, so it can be
used outside of a Rails app. The interface is the same as in Rails:

```ruby
logger.silence(temporary_level) do
  ...
end
```

The logger also implements `local_level` and `local_level=`, the interface
`ActiveSupport::BroadcastLogger` uses to silence the loggers it wraps. In Rails,
`Rails.logger` is a `BroadcastLogger`, so `Rails.logger.silence`,
`Rails::Rack::SilenceRequest` (`config.silence_healthcheck_path`) and
`benchmark(..., silence: true)` silence LogStashLogger output too, including
every output of a `multi_logger`.

## Custom Logger Class

By default, LogStashLogger creates a logger that extends Ruby's built in `Logger` class.
If you require a different logger implementation, you can use a different class
by passing in the class with the `logger_class` option.

Note that for syslog, the `Syslog::Logger` class is required and cannot be
changed.

## Error Handling

If an exception occurs while writing a message to the device, the exception is
logged using an internal logger. By default, this logs to $stderr. You can
change the error logger by setting `LogStashLogger.configuration.default_error_logger`, or by passing
your own logger object in the `:error_logger` configuration key when
instantiating a LogStashLogger.
