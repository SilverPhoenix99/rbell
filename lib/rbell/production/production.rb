module Rbell
  class Production < BaseProduction
    attr_reader :name, :body

    def initialize(grammar, name, &block)
      super grammar
      @name = name
      @body = block
    end

    def parse
      instance_eval(&@body)
    end

    def compile
      [[self]]
    end

    def inspect
      name.to_s
    end

    def to_s
      "<#{self.class} #{name}>"
    end

    def ==(other)
      other.is_a?(self.class) && other.name == name
    end
  end
end
