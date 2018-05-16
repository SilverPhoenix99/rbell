module Rbell
  class UnknownProductionError < StandardError; end
  module Parser

    class UnexpectedTokenError < StandardError; end

    module ClassMethods
      attr_reader :end_of_input, :table

      def grammar(&block)
        @grammar = Grammar.new
        @table = @grammar.compile(&block)
        @end_of_input = @grammar.end_of_input
        singleton_class.send :remove_method, :const_missing
      ensure
        remove_instance_variable :@grammar
      end
    end

    module InstanceMethods
      def parse
        processor = Processor.new(self)
        processor.parse
      end

      def current_token
        @current_token ||= next_token
      end

      def consume_token
        token = current_token
        @current_token = nil
        token
      end

      def next_token
        raise 'Please override method.'
      end

      def token_name(_token)
        raise 'Please override method.'
      end
    end

    class << self
      def included(mod)
        mod.extend ClassMethods
        mod.include InstanceMethods

        def mod.const_missing(name)
          @grammar.find_production(name)
        end
      end

      alias_method :extended, :included
    end

    class Processor
      def initialize(parser)
        @parser = parser
        @stack = [parser.class.end_of_input, Production.new(:main)]
        @result = []
      end

      def parse
        until @stack.empty?
          @production = @stack.pop

          case @production
            when Production       then predict
            when Terminal         then match
            when ActionProduction then @production.action.call(@result)
            when EmptyProduction  # no-op / consume
            else raise UnknownProductionError("unknown production type: #{@production.class}")
          end

        end

        @result
      end

      def predict
        token = @parser.current_token
        name = @parser.token_name(token)
        rule = @parser.class.table[@production.name][name]
        raise UnexpectedTokenError.new("unexpected token #{token}. expected #{@parser.class.table[@production.name].keys.join(', ')}.") unless rule
        @stack.push(*rule)
      end

      def match
        token = @parser.consume_token
        name = @parser.token_name(token)
        raise UnexpectedTokenError.new("unexpected token #{token}. expected #{@production.name}.") unless @production.name == name
        @result << token
      end
    end
  end
end
