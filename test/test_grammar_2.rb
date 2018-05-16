require_relative '../lib/rbell'

class Grammar
  extend Rbell::Parser

  grammar {

    end_of_input :EOS

    tokens :ADD, :SUB, :MUL, :DIV, :ID, :LPAREN, :RPAREN

    # E -> E + T | E - T | T
    # T -> T * F | T / F | F
    # F -> ( E ) | id

    main { ( main ADD t ) | ( main SUB t ) | t }

    t { ( t MUL f ) | ( t DIV f ) | f }

    f { ( LPAREN main RPAREN ) | ID }
  }
end

parser = Grammar.new
puts parser