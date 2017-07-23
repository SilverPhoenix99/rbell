module Rbell
  class BaseProduction
    attr_reader :grammar

    def initialize(grammar = nil)
      @grammar = grammar if grammar
    end

    def |(prod, &block)
      prod = AlternativeProduction.new([self, prod], @grammar)
      clause(prod, &block)
    end

    def &(prod, &block)
      prod = SequenceProduction.new([self, prod], @grammar)
      clause(prod, &block)
    rescue Exception => e
      puts prod
      puts block
      puts e.message
      puts e.backtrace.inspect
    end

    def _?(*args, &block)
      prod = OptionalProduction.new(self, @grammar)
      clause(prod, *args, &block)
    end

    def *(*args, &block)
      prod = StarProduction.new(self, @grammar)
      clause(prod, *args, &block)
    end

    def +(*args, &block)
      prod = PlusProduction.new(self, @grammar)
      clause(prod, *args, &block)
    end

    def clause(prod, *args, &block)
      prod = args.reduce(prod, &:&) unless args.length == 0
      return prod unless block
      action = ActionProduction.new(block, @grammar)
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
    alias_method :opt, :_?

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
    def gen_production
      name = :"##{@grammar.productions.length}"
      prod = Production.new(name, @grammar)
      @grammar.productions[name] = [[prod]]
      prod
    end
  end
end