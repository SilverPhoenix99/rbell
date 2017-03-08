module Rbell
  class BaseProduction
    attr_reader :grammar

    def initialize(grammar)
      @grammar = grammar
    end

    def |(prod, &block)
      prod = AlternativeProduction.new(@grammar, [self, prod])
      clause(prod, &block)
    end

    def &(prod, &block)
      prod = SequenceProduction.new(@grammar, [self, prod])
      clause(prod, &block)
    end

    def opt(&block)
      prod = OptionalProduction.new(@grammar, self)
      clause(prod, &block)
    end

    def *(*args, &block)
      prod = StarProduction.new(@grammar, self)
      clause(prod, *args, &block)
    end

    def +(*args, &block)
      prod = PlusProduction.new(@grammar, self)
      clause(prod, *args, &block)
    end

    def clause(prod, *args, &block)
      prod = args.reduce(prod, &:&) unless args.length == 0
      return prod unless block
      action = ActionProduction.new(@grammar, block)
      prod & action
    end

    def const_missing(name)
      @grammar.send(:const_missing, name)
    end

    def method_missing(name, *args, &block)
      prod = const_missing(name)
      clause(prod, *args, &block)
    end

    alias_method :star, :*
    alias_method :plus, :+

    private
    def parsed_productions
      @grammar.instance_variable_get(:@parsed_productions)
    end
  end

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
  end

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
  end

  class SequenceProduction < BaseProduction
    attr_reader :productions

    def initialize(grammar, productions)
      super grammar
      @productions  = productions
    end

    def &(prod, &block)
      productions << prod
      clause(self, &block)
    end
  end

  class OptionalProduction < BaseProduction
    attr_reader :production

    def initialize(grammar, production)
      super grammar
      @production = production
    end
  end

  class StarProduction < OptionalProduction
  end

  class PlusProduction < OptionalProduction
  end

  class ActionProduction < BaseProduction
    attr_reader :action

    def initialize(grammar, action)
      super grammar
      @action = action
    end
  end

  class Terminal < BaseProduction
    attr_reader :token

    def initialize(grammar, token)
      super grammar
      @token = token
    end
  end
end
