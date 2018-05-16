module Rbell
  class AlternativeProduction < BaseProduction
    attr_reader :productions

    def initialize(productions, grammar = nil)
      super grammar
      @productions  = productions
    end

    def |(prod, &block)
      productions << prod
      clause(self, &block)
    end

    def compile(name)
      prods = productions.map { |p| p.compile(name) }
      prods.reduce(&:+)
    end

    def ==(other)
      other.is_a?(self.class) && other.productions == productions
    end
  end
end