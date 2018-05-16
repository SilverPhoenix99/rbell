require_relative '../lib/rbell'
require '../lib/rbell/production/empty_production'

class Grammar
  extend Rbell::Parser


  grammar {

    end_of_input :EOS

    tokens :LBRACKET, :RBRACKET, :STRING, :NUMBER, :COLON, :COMMA, :T, :F, :NULL, :LBRACE, :RBRACE

    # object → '{' pairs '}'
    #
    # pairs → pair pairs_tail | ε
    # pair → STRING ':' value
    # pairs_tail → ',' pairs | ε
    #
    # value → STRING | NUMBER | 'true' | 'false' | 'null' | object | array
    # array → '[' elements ']'
    #
    # elements → value elements_tail | ε
    # elements_tail → ',' elements | ε

    main { (LBRACE pairs RBRACE) }

    pairs { ( pair pairs_tail ) | Rbell::EmptyProduction.instance }

    pair { STRING COLON value }

    pairs_tail { ( COMMA pairs ) | Rbell::EmptyProduction.instance }

    value { STRING | NUMBER | T | F | NULL | main | array }

    array { LBRACKET elements RBRACKET }

    elements { ( value elements_tail ) | Rbell::EmptyProduction.instance }

    elements_tail { ( COMMA elements ) | Rbell::EmptyProduction.instance }
  }
end

parser = Grammar.new
puts parser