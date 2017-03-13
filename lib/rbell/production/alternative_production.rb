module Rbell
  class AlternativeProduction < BaseProduction
    attr_reader :productions

    def initialize(grammar, productions)
      super grammar
      @productions  = productions
    end

    def |(prod, &block)
      productions << prod
      clause(self, &block)
    end

    def compile
      prods = productions.map(&:compile)
      prods.reduce(&:+)
    end

    def ==(other)
      other.is_a?(self.class) && other.productions == productions
    end
  end
end