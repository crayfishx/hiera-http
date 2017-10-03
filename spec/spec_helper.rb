

class FakeFunction
  def self.dispatch(name, &block)
  end
end


module Puppet
  module Functions
    def self.create_function(name, &block)
      FakeFunction.class_eval(&block)
    end
  end
  class DataBinding
    class LookupError < RuntimeError
    end
  end
end

