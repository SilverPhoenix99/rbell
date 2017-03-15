module Rbell
  class Terminal < BaseProduction
    attr_reader :token

    def initialize(token, grammar = nil)
      super grammar
      @token = token
    end

    alias_method :name, :token

    def compile
      [[self]]
    end

    def inspect
      token.to_s
    end

    def to_s
      "<#{self.class} #{token}>"
    end

    def ==(other)
      other.is_a?(self.class) && other.token == token
    end

    def terminal?
      true
    end
  end
end