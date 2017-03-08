module Rbell
  class Grammar
    attr_reader :productions

    def initialize
      @productions = {}
      @terminals = {}
    end

    def compile(&block)
      instance_eval(&block) if block

      parsed_productions = parse
      @productions = {}
      parsed_productions.each { |k, v| @productions[k] = v.compile }

      # TODO simplification thompson
      # TODO calculate first set
      # TODO calculate follow set
      # TODO calculate parser table

      raise 'TODO'
    end

    def main(&block)
      production(:main, &block)
    end

    def production(name, prod = nil, &block)
      name = name.to_sym
      prod ||= Production.new(self, name, &block)
      @productions[name] = prod
    end

    def tokens(*args)
      args.each do |arg|
        name = arg.to_sym
        @terminals[name] ||= Terminal.new(self, name)
      end
    end

    def const_missing(name)
      prod = @terminals[name]
      return prod if prod

      prod = @productions[name] || raise("Unknown production `#{name}'")

      unless @parsed_productions.has_key?(name)
        @parsed_productions[name] = prod
        @parsed_productions[name] = prod.parse
      end

      prod
    end

    def method_missing(name, *args, &block)
      super if args.length != 0 || !block
      production(name, &block)
    end

    alias_method :terminals, :tokens

    private
    def parse
      main_prod = @productions[:main]
      @parsed_productions = { main: main_prod }
      @parsed_productions[:main] = main_prod.parse
      remove_instance_variable(:@parsed_productions)
    end
  end
end
