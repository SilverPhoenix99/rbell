module Rbell
  class SequenceProduction < BaseProduction
    attr_reader :productions

    def initialize(productions, grammar = nil)
      super grammar
      @productions  = productions
    end

    def &(prod, &block)
      productions << prod
      clause(self, &block)
    end

    def compile
      prods = productions.map(&:compile)
      prods.reduce { |p1, p2| p1.product(p2).map! { |p| p.tap { |x| x.flatten!(1) } } }
    end

    def ==(other)
      other.is_a?(self.class) && other.productions == productions
    end
  end
end