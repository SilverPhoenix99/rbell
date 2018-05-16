require 'set'

module Rbell

  class GrammarNotLLError < StandardError; end
  class FirstFollowConflict < StandardError; end
  class FirstFirstConflict < StandardError; end

  class Grammar
    attr_reader :productions

    def initialize
      @productions = {}
      @terminals = {}
      @end_of_input = Terminal.new(:EOF, self)
      @name_id = {}
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
      rewrite
      puts self.inspect
      calculate_firsts_set
      calculate_follows_set
      calculate_parser_table
    end

    def main(&block)
      production(:main, &block)
    end

    def production(name, prod = nil, &block)
      name = name.to_sym
      prod ||= Production.new(name, self, &block)
      @productions[name] = prod
    end

    def tokens(*args)
      args.each do |arg|
        name = arg.to_sym
        @terminals[name] ||= Terminal.new(name, self)
      end
    end

    def find_production(name)
      prod = @terminals[name]
      return prod if prod

      prod = @productions[name] || raise(UnknownProductionError.new(name))

      unless @parsed_productions.has_key?(name)
        @parsed_productions[name] = prod
        @parsed_productions[name] = prod.parse
      end

      prod
    end

    def gen_prod_name(name)
      name = $1.to_sym if name =~ /^(.+)'\d+$/
      id = @name_id[name] || find_last_prod_id(name) || 0
      @name_id[name] = (id += 1)

      :"#{name}'#{id}"
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
    def find_last_prod_id(name)
      regex = /^#{name}'(\d+)$/
      names = @productions.keys.map(&:to_s)
      names.map! { |y| y =~ regex && $1.to_i }
      names.compact!
      names.max
    end

    def compile_productions
      parsed_productions = parse_productions
      @productions = {}
      parsed_productions.each do |k, v|
        @productions[k] = v.compile(k)
      end
    end

    def parse_productions
      main_prod = @productions[:main]
      @parsed_productions = { main: main_prod }
      @parsed_productions[:main] = main_prod.parse
      remove_instance_variable(:@parsed_productions)
    end

    def rewrite

      max_iterations = 1000
      max_iterations.times do

        puts

        print @productions.count
        print ' '

        next if print('s') || remove_singularities
        next if print('u') || remove_unused
        next if print('r') || remove_left_recursion
        next if print('m') || remove_mutual_recursion
        next if print('c') || remove_left_corners
        next if print('f') || remove_left_factors
        # next if remove_similar_rules

        puts

        raise GrammarNotLLError.new('Grammar is not LL.') if @productions == {main: []}
        return
      end

      raise 'Reached max number of trials'
    end

    def remove_singularities
      # identify singularities
      singularities = @productions.select do |_name, rules|
        rules.size == 1 && rules.first.size == 1 && (
          rules.first.first.terminal? || rules.first.first.is_a?(ActionProduction)
        )
      end.map { |name, rules| [name, rules.first.first] }.to_h

      return false if singularities.empty? # skip if there are no singularities

      @productions.each do |_name, rules|
        rules.each do |rule|
          buffer = rule.map do |prod|
            if prod.is_a?(Production) && singularities.has_key?(prod.name)
              singularities[prod.name]
            else
              prod
            end
          end

          rule.replace(buffer)
          remove_epsilons!(rule)
        end
      end

      remove_unused

      true
    end

    def remove_unused

      productions = @productions.map do |name, rules|
        rules = rules.map { |rule| rule.select { |p| p.is_a?(Production) }.map(&:name) }.flatten(1)
        [name, Set.new(rules)]
      end.to_h

      used = Set.new << :main

      count = 0

      while count != used.count
        count = used.count
        used.merge( used.map { |name| productions[name] }.reduce(:merge) )
      end

      return false if used.count == @productions.count

      all_productions = Set.new(@productions.keys)
      unused = all_productions - used

      unused.each { |name| @productions.delete(name) }

      true
    end

    # A -> B a | ... ; B -> A d | ... ==> A -> A d a | ... ;

    def remove_mutual_recursion
      productions = @productions.map do |name, rules|
        rules = rules.select do |rule|
          rule.first.is_a?(Production) && rule.first.name != name
        end.map! { |rule| rule.first.name }.tap(&:uniq!)
        [name, rules]
      end.to_h

      # detect mutual recursions
      productions.each { |name, prods| prods.select! { |p| productions[p].include?(name) } }

      # make sure main production is preserved
      productions[:main]&.each { |p| productions[p].delete(:main) }

      # remove loops:  a=>b & b=>a  ==>  a=>b
      productions.each { |name, prods| prods.each { |p| productions[p].delete(name) } }

      # remove productions that don't have recursion
      productions.reject! { |_name, prods| prods.empty? }

      return false if productions.empty?

      p productions

      productions.each do |name, prods|
        prods.each do |prod|
          buffer = []
          @productions[name].each do |rule|
            p, *rest = rule
            if p.is_a?(Production) && p.name == prod
              buffer.push(*@productions[prod].map { |r| remove_epsilons!(r + rest) })
            else
              buffer << rule
            end
          end.replace(buffer)
        end
      end

      true
    end

    # A -> A [an] | [bn] ==> A -> [bn] A' ; A' -> [an] A' | ε
    def remove_left_recursion

      productions = @productions.map do |name, rules|
        [name, rules.partition { |rule| rule.first.is_a?(Production) && rule.first.name == name }]
      end.to_h

      found_recursive = false

      productions.each do |name, (recursive, rest)|
        next if recursive.empty?
        found_recursive = true

        new_name = gen_prod_name(name)
        new_prod = Production.new(new_name)

        recursive.each(&:shift).each { |rule| remove_epsilons!(rule << new_prod) }

        @productions[new_name] = recursive << [EmptyProduction.instance]
        @productions[name] = rest.each { |rule| remove_epsilons!(rule << new_prod) }

      end

      found_recursive
    end

    # A -> Bd;  B -> cd | ae  ==>  A -> cdd | aed
    def remove_left_corners
      found = false

      @productions.each do |name, rules|
        buffer = []
        rules.each do |rule|
          p, *rest = rule
          # if p.is_a?(Production) && ![:main, name].include?(p.name)
          if p.is_a?(Production) && name != p.name
            found = true
            buffer.push(*@productions[p.name].map { |r| remove_epsilons!(r + rest) })
          else
            buffer << rule
          end
        end.replace(buffer).uniq!
      end

      found
    end

    # A -> bcD | bcC | bcB | Bd ==> A -> bcA' | Bd   A' -> D | C | B
    def remove_left_factors

      prods = @productions.map do |name, rules|
        next if rules.size == 1
        t = Trie.new
        rules.each { |rule| t.insert(rule) }
        prefixes = t.group_by_prefixes
        next if prefixes.size == rules.size
        [name, t.group_by_prefixes]
      end.compact!

      return false if prods.empty?

      prods.each do |name, prefixes|

        rules = @productions[name] = []

        prefixes.each do |prefix, suffixes|
          if suffixes.size == 1 && suffixes.first.empty? # suffixes == [[]]
            rules << prefix
          else
            suffix = suffixes.find(&:empty?)
            suffix << EmptyProduction.instance if suffix

            new_name = @productions.find { |_name, rs| rs == suffixes }&.first
            unless new_name
              new_name = gen_prod_name(name)
              @productions[new_name] = suffixes
            end
            new_prod = Production.new(new_name)

            rules << (prefix << new_prod)
          end
        end

      end

      true
    end

    def remove_epsilons!(rule)
      return rule unless rule.size > 1
      rule.delete(EmptyProduction.instance)
      rule << EmptyProduction.instance if rule.empty?
      rule
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
      @follow[:main] << end_of_input

      productions = @first.keys.map { |name| Production.new(name, self) }

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
      table = Hash.new { |hash, key| hash[key] = Hash.new }

      @productions.each do |name, prods|
        prods.each do |prod|
          calculate_firsts(prod).each do |t|
            if t.is_a?(EmptyProduction)
              @follow[name].each do |tf|
                if table[name][tf.name]
                  raise FirstFollowConflict.new("(#{name}, #{tf.name}) : #{table[name][tf.name]}")
                end
                table[name][tf.name] = prod
              end
            else
              raise FirstFirstConflict.new("(#{name}, #{t.name}) : #{table[name][t.name]} ? #{prod}") if table[name][t.name]
              table[name][t.name] = prod
            end
          end
        end
      end

      # reverse all rules
      rules = {}.compare_by_identity
      table.values.flat_map(&:values).each { |rule| rules[rule] = true }
      rules.keys.each(&:reverse!)

      table
    end

  end
end
