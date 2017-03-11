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

      def mathes_token?(current_token, name)
        raise "Please override `mathes_token?' method."
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
  end
end
