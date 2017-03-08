module Rbell
  module Parser
    module ClassMethods
      def grammar(&block)
        @grammar = Grammar.new
        @grammar.compile(&block)
        @grammar
      end

      def const_missing(name)
        @grammar.send(:const_missing, name)
      end
    end

    module InstanceMethods
      def parse
        raise 'TODO'
      end

      def next_token
        raise "Please override `next_token' method."
      end
    end

    class << self
      def included(mod)
        mod.extend ClassMethods
        mod.include InstanceMethods
      end

      alias_method :extended, :included
    end
  end
end
