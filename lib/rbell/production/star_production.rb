module Rbell
  class StarProduction < OptionalProduction
    def compile
      # x -> y (a ...)* z ;   =>   x  -> y p2 z ;
      #                            p1 -> a ... ;
      #                            p2 -> p1 p2 | ~ ;

      prod = production.compile
      prod1 = gen_production

      if prod.length == 1 && prod.first.length == 1
        prod2 = prod1
        prod1 = prod.first.first
      else
        prod2 = gen_production
        @grammar.productions[prod1.name] = prod
      end

      @grammar.productions[prod2.name] = [[prod1, prod2], [EmptyProduction.instance]]

      [[prod2]]
    end
  end
end