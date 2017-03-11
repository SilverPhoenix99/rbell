module Rbell
  module Parser
    module ClassMethods
      def grammar(&block)
        @grammar = Grammar.new
        @parser_table = @grammar.compile(&block)
        singleton_class.send :remove_method, :const_missing
        remove_instance_variable :@grammar
      end
    end

    module InstanceMethods
      attr_reader :current_token

      def parse
        raise 'TODO'
      end

      def advance_token
        raise "Please override `advance_token' method."
      end

      def current_token_name
        raise "Please override `current_token_name' method."
      end
    end

    class << self
      def included(mod)
        mod.extend ClassMethods
        mod.include InstanceMethods

        def mod.const_missing(name)
          @grammar.send(:const_missing, name)
        end
      end

      alias_method :extended, :included
    end
  end
end
