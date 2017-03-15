module Rbell
  class OptionalProduction < BaseProduction
    attr_reader :production

    def initialize(production, grammar = nil)
      super grammar
      @production = production
    end

    def compile
      # x -> y (a ...)? z ;   =>   x  -> y p1 z ;
      #                            p1 -> a ... | ~ ;

      prod = gen_production

      compiled_prod = production.compile << [EmptyProduction.instance]
      @grammar.productions[prod.name] = compiled_prod

      [[prod]]
    end

    def ==(other)
      other.is_a?(self.class) && other.production == production
    end
  end
end