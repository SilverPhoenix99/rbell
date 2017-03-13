require 'set'

module Rbell
  class Grammar
    attr_reader :productions

    def initialize
      @productions = {}
      @terminals = {}
      @end_of_input = Terminal.new(self, :EOF)
    end

    def end_of_input(token = nil)
      if token
        token = token.to_sym
        tokens(token)
        @end_of_input = @terminals[token]
      end
      @end_of_input
    end

    def compile(&block)
      instance_eval(&block) if block

      compile_productions
      simplify_productions
      calculate_firsts_set
      calculate_follows_set
      calculate_parser_table
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

    def find_production(name)
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
    def compile_productions
      parsed_productions = parse_productions
      @productions = {}
      parsed_productions.each { |k, v| @productions[k] = v.compile }
    end

    def parse_productions
      main_prod = @productions[:main]
      @parsed_productions = { main: main_prod }
      @parsed_productions[:main] = main_prod.parse
      remove_instance_variable(:@parsed_productions)
    end

    def simplify_productions
      loop do
        prods = @productions.select { |_, clauses| clauses.length == 1 && clauses.first.length == 1 }

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

    def calculate_firsts_set
      @first = Hash.new { |hash, key| hash[key] = SortedSet.new }

      @productions.each do |name, prod|
        @first[name].merge(prod.map(&:first).select(&:terminal?))
      end

      count, new_count = nil, 0
      until count == new_count
        count = new_count
        @productions.each do |name, prod|
          prod.each do |rule|
            @first[name].merge(calculate_firsts(rule))
          end
        end
        new_count = @first.values.map(&:count).reduce(&:+)
      end
    end

    def calculate_follows_set
      @follow = Hash.new { |hash, key| hash[key] = SortedSet.new }
      @follow[:main] << @end_of_input

      productions = @first.keys.map { |name| Production.new(self, name) }

      count, new_count = nil, 0
      until count == new_count
        count = new_count
        productions.each do |prod|
          @productions.each do |name, rules|
            rules.select { |rule| rule.include?(prod) }.each do |rule|
              index = rule.find_index(prod) + 1
              set = calculate_firsts(rule[index..-1])

              @follow[prod.name].merge(@follow[name]) if set.include?(EmptyProduction.instance)
              @follow[prod.name].merge(set - [EmptyProduction.instance])
            end
          end
        end
        new_count = @follow.values.map(&:count).reduce(&:+)
      end
    end

    def calculate_firsts(rule)
      Set.new.tap do |set|
        has_epsilon = rule.each do |p|
          case p
            when Terminal
              set << p
              break
            when Production
              set.merge(@first[p.name] - [EmptyProduction.instance])
              break unless @first[p.name].include?(EmptyProduction.instance)
          end
        end

        set << EmptyProduction.instance if has_epsilon
      end
    end

    def calculate_parser_table
      @table = Hash.new { |hash, key| hash[key] = Hash.new }

      @productions.each do |name, p|
        @first[name].each do |t|
          if t.is_a?(EmptyProduction)
            @follow[name].each do |f|
              @table[name][f.name] = p
            end
          else
            @table[name][t.name] = p
          end
        end
      end
    end
  end
end
