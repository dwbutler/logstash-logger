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

## Logger Silencing

LogStashLogger provides support for Rails-style logger silencing. The
implementation was extracted from Rails, but has no dependencies, so it can be
used outside of a Rails app. The interface is the same as in Rails:

```ruby
logger.silence(temporary_level) do
  ...
end
```

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
