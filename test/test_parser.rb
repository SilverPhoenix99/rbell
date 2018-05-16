require_relative 'test_helper'

module Test
  class Parser
    include Rbell::Parser

    def initialize(tokens)
      @tokens = tokens
    end

    def next_token
      @tokens.shift
    end

    grammar {

      end_of_input :EOS

      tokens :D, :E, :F, :G, :H

      # S -> A B d | C d
      # A -> C d h | S e
      # C -> g B | h f
      # B -> g | ε

      main { ( a b D ) | ( c D ) }

      a { ( c D H ) | ( main E ) }

      c { ( G b ) | ( H F ) }

      b { G._? }

    }

  end
end
