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
    rescue Exception => e
      puts prod
      puts block
      puts e.message
      puts e.backtrace.inspect
    end

    def opt(*args, &block)
      prod = OptionalProduction.new(@grammar, self)
      clause(prod, *args, &block)
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
      @grammar.find_production(name)
    end

    def method_missing(name, *args, &block)
      prod = const_missing(name)
      clause(prod, *args, &block)
    end

    alias_method :star, :*
    alias_method :plus, :+

    def compile
      raise "Please override `compile' method."
    end

    def terminal?
      false
    end

    def <=>(other)
      name.to_s <=> other.name.to_s
    end

    private
    def parsed_productions
      @grammar.instance_variable_get(:@parsed_productions)
    end

    def gen_production
      name = :"##{@grammar.productions.length}"
      prod = Production.new(@grammar, name)
      @grammar.productions[name] = [[prod]]
      prod
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

    def compile
      prods = productions.map(&:compile)
      prods.reduce { |p1, p2| p1.product(p2).map! { |p| p.tap { |x| x.flatten!(1) } } }
    end

    def ==(other)
      other.is_a?(self.class) && other.productions == productions
    end
  end

  class OptionalProduction < BaseProduction
    attr_reader :production

    def initialize(grammar, production)
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

  class PlusProduction < OptionalProduction
    def compile
      # x -> y (a ...)* z ;   =>   x  -> y p1 p2 z ;
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

      [[prod1, prod2]]
    end
  end

  class ActionProduction < BaseProduction
    attr_reader :action

    def initialize(grammar, action)
      super grammar
      @action = action
    end

    def name
      action.to_s
    end

    def compile
      [[self]]
    end

    def ==(other)
      other.is_a?(self.class) && other.action == action
    end
  end

  class Terminal < BaseProduction
    attr_reader :token

    def initialize(grammar, token)
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

    def compile
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
