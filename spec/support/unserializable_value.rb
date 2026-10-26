# A value whose JSON conversion always raises, with or without ActiveSupport
class UnserializableValue
  def to_json(*)
    raise JSON::GeneratorError, 'cannot serialize'
  end

  def as_json(*)
    raise JSON::GeneratorError, 'cannot serialize'
  end
end
