module Rbell
  class BaseProduction
    def |(prod, &block)
      prod = AlternativeProduction.new([self, prod])
      self.class.compact(prod, &block)
    end

    def &(prod, &block)
      prod = SequenceProduction.new([self, prod])
      self.class.compact(prod, &block)
    end

    def opt(&block)
      prod = OptionalProduction.new(self)
      self.class.compact(prod, &block)
    end

    def *(*args, &block)
      prod = StarProduction.new(self)
      self.class.compact(prod, *args, &block)
    end

    def +(*args, &block)
      prod = PlusProduction.new(self)
      self.class.compact(prod, *args, &block)
    end

    def self.compact(prod, *args, &block)
      prod = args.reduce(prod, &:&) unless args.length == 0
      return prod unless block
      action = ActionProduction.new(block)
      prod & action
    end
  end

  class Production < BaseProduction
    attr_reader :name, :clause

    def initialize(name, &block)
      @name   = name
      @clause = block
    end
  end

  class AlternativeProduction < BaseProduction
    attr_reader :productions

    def initialize(productions)
      @productions  = productions
    end

    def |(prod, &block)
      productions << prod
      self.class.compact(self, &block)
    end
  end

  class SequenceProduction < BaseProduction
    attr_reader :productions

    def initialize(productions)
      @productions  = productions
    end

    def &(prod, &block)
      productions << prod
      self.class.compact(self, &block)
    end
  end

  class OptionalProduction < BaseProduction
    attr_reader :production

    def initialize(production)
      @production = production
    end
  end

  class StarProduction < OptionalProduction
  end

  class PlusProduction < OptionalProduction
  end

  class ActionProduction < BaseProduction
    attr_reader :action

    def initialize(action)
      @action = action
    end
  end

  class Terminal < BaseProduction
    attr_reader :token

    def initialize(token)
      @token = token
    end
  end
end
