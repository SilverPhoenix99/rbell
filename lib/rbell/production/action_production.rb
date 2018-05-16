module Rbell
  class ActionProduction < BaseProduction
    attr_reader :action

    def initialize(action, grammar = nil)
      super grammar
      @action = action
    end

    def name
      action.to_s
    end

    def compile(_name)
      [[self]]
    end

    def to_s
      id = (object_id << 1).to_s(16)
      "#<#{self.class.name}:0x#{id}>"
    end

    def ==(other)
      other.is_a?(self.class) && other.action == action
    end

    alias_method :inspect, :to_s
  end
end