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

      simplify_productions

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

    def inspect
      @productions.map do |name, clauses|
        ws = ' ' * name.length
        clauses = clauses.map { |clause| clause.map(&:inspect).join(' ') }.join("\n#{ws} | ")
        "#{name.to_s} : #{clauses}\n"
      end.join("\n")
    end

    private
    def parse
      main_prod = @productions[:main]
      @parsed_productions = { main: main_prod }
      @parsed_productions[:main] = main_prod.parse
      remove_instance_variable(:@parsed_productions)
    end

    def simplify_productions
      loop do
        prods = @productions.select { |_, clauses| clauses.length == 1 && clauses[0].length == 1 }

        break if prods.empty?

        prods.each do |name, clauses|
          @productions.delete(name)

          name = Production.new(self, name)
          rule = clauses.first.first

          @productions.each do |_, cs|
            cs.each do |clause|
              clause.map! { |r| r == name ? rule : r }
            end
          end
        end
      end
    end

  end
end
