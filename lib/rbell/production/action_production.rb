module Rbell
  class ActionProduction < BaseProduction
    attr_reader :action

    def initialize(grammar, action)
      super grammar
      @action = action
    end

    def name
      action.to_s
    end

    def compile
      [[self]]
    end

    def ==(other)
      other.is_a?(self.class) && other.action == action
    end
  end
end