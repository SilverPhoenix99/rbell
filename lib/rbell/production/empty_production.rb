module Rbell
  class EmptyProduction < BaseProduction
    def initialize; end

    @instance = allocate.freeze
    class << self
      attr_reader :instance
      alias_method :new, :instance
    end

    def name
      "\u03B5"
    end

    def compile(_name)
      [[self]]
    end

    alias_method :inspect, :name

    def to_s
      "<#{self.class} \u03B5>"
    end

    def ==(other)
      other.is_a?(self.class)
    end

    def terminal?
      true
    end
  end
end