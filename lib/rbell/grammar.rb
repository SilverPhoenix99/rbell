module Rbell
  class Grammar
    def initialize(parser_module)
      @parser_module = parser_module
      @productions = {}
      @terminals = {}
    end

    def compile(&block)
      instance_eval(&block) if block

      parse
      # TODO simplification thomson
      raise 'TODO'
    end

    def main(&block)
      production(:main, &block)
    end

    def production(name, prod = nil, &block)
      name = name.to_sym
      prod ||= Production.new(name, &block)
      @productions[name] = prod
    end

    def tokens(*args)
      args.each do |arg|
        name = arg.to_sym
        @terminals[name] ||= Terminal.new(name)
      end
    end

    def const_missing(name)
      prod = @terminals[name]
      return prod if prod

      prod = @productions[name] || raise("Unknown production `#{name}'")

      unless @parsed_productions.has_key?(name)
        @parsed_productions[name] = prod
        @parsed_productions[name] = instance_eval(&prod.clause)
      end

      prod
    end

    def method_missing(name, *args, &block)
      prod = const_missing(name)
      prod = args.reduce(prod, &:&) unless args.length == 0
      clause(prod, &block)
    end

    def clause(prod, &block)
      BaseProduction.compact(prod, &block)
    end

    def star(prod, *args, &block)
      prod.*(*args, &block)
    end

    def plus(prod, *args, &block)
      prod.+(*args, &block)
    end

    alias_method :terminals, :tokens

    private
    def parse
      main_prod = @productions[:main]
      @parsed_productions = { main: main_prod }
      @parsed_productions[:main] = instance_eval(&main_prod.clause)
      remove_instance_variable(:@parsed_productions)
    end
  end
end
