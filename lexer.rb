require 'rltk'
require 'logger'

class RLTK::Token
  def to_a
    [type, *value, [position&.line_number, position&.line_offset]]
  end

  def inspect
    to_a.inspect
  end
end

module C
  class Lexer < RLTK::Lexer
    LOGGER = Logger.new(STDOUT)
    # LOGGER.level = Logger::INFO

    # comments
    rule(%r'//.*$') { |t| LOGGER.debug("read comment #{t}"); nil }

    # block comment
    rule(%r'/\*') { push_state :block_comment }
    rule(/./m, :block_comment)
    rule(%r'\*/', :block_comment) { pop_state }

    # directives
    rule(/\#[^\S\n]*(
              define
            | import
            | undef
            | elif
            | using
            | else
            | ifdef
            | line
            | endif
            | ifndef
            | if
            | exec_macro_expression
          )/x) do
      LOGGER.debug("read DIR_#{match[1].upcase}")
      set_flag :directive
      "DIR_#{match[1].upcase}".to_sym
    end
    rule(/\\\n/, :default, [:directive])
    rule(/\n/, :default, [:directive]) { unset_flag :directive; :NEWLINE }

    # pragma|warning
    rule(/#[^\S\n]*(pragma|warning)/) do
      LOGGER.debug("DIR_#{match[1].upcase}")
      push_state :diagnostic
      "DIR_#{match[1].upcase}".to_sym
    end

    # macro text
    rule(/(\\.|[^\n])+/m, :diagnostic) { |t| LOGGER.debug("diagnostic MACRO_TEXT: #{t}"); [:MACRO_TEXT, t] }
    rule(/\n/, :diagnostic)            { LOGGER.debug("diagnostic: newline");pop_state; :NEWLINE  }

    # error
    rule(/#[^\S\n]*error/)         { LOGGER.debug('error');push_state :error; :DIR_ERROR }
    rule(/(\\.|[^\n])*/m, :error) { |t| LOGGER.debug("error MACRO_TEXT: #{t}"); [:MACRO_TEXT, t]      }
    rule(/\n/, :error)            { LOGGER.debug("diagnostic: newline");pop_state; :NEWLINE       }

    # include
    rule(/#[^\S\n]*(include|include_next)[^\S\n]*/) do
      LOGGER.debug('reading include...')
      set_flag :directive
      set_flag :include_string
      :DIR_INCLUDE
    end

    rule(/[^\S\n]*\n/m, :default, [:directive]) do
      LOGGER.debug('read :NEWLINE')
      unset_flag :directive
      unset_flag :include_string
      :NEWLINE
    end

    rule(/\\\n/, :default, [:directive]) # ignore

    rule(/</, :default, [:include_string]) do
      LOGGER.debug('entering <...>...')
      push_state :include_string
    end
    rule(/[^>\n]*/m, :include_string) { |t| [:STRING, t] }
    rule(/>/, :include_string) { pop_state }

    rule(/(
              auto
            | break
            | case
            | char
            | const
            | continue
            | defined
            | double
            | do
            | else
            | enum
            | extern
            | float
            | for
            | if
            | int
            | long
            | register
            | return
            | short
            | signed
            | sizeof
            | static
            | struct
            | switch
            | typedef
            | union
            | unsigned
            | void
            | volatile
            | while
          )/x)     { match[1].upcase.to_sym }

    # numbers
    rule(/0[xX][a-fA-F0-9]+[u|U|l|L]?/)     { |t| [:HEXADECIMAL, t] } # 0xF1
    rule(/0[0-7]+[u|U|l|L]?/)               { |t| [:OCTAL,       t] } # 09
    rule(/[0-9]+[u|U|l|L]?/)                { |t| [:DECIMAL,     t] } # 1

    # floats
    rule(/[0-9]+[Ee][+-]?[0-9]+[f|F|l|L]?/)         { |t| [:FLOAT, t] } # 1e99
    rule(/[0-9]*\.[0-9]+[Ee][+-]?[0-9]+[f|F|l|L]?/) { |t| [:FLOAT, t] } # .2e99
    rule(/[0-9]+\.[0-9]*[Ee][+-]?[0-9]+[f|F|l|L]?/) { |t| [:FLOAT, t] } # 1.e99

    # character
    rule(%r<'>) { push_state :char }
    rule(%r<(\\.|[^'])>, :char) { |t| [:CHAR, t] }
    rule(%r<'>, :char) { pop_state }

    # string
    rule(/"/) { push_state :string }
    rule(/(\\.|[^"\n])*"/m, :string) { |t| pop_state; [:STRING, t[0..-2]] }

    #
    rule(/#_#_/)   { :STRINGIFICATION }
    rule(/##/)     { :SHARPSHARP      }
    rule(/::/)     { :SCOPE           }
    rule(/\.\.\./) { :ELLIPSIS        }
    rule(/>>=/)    { :RIGHT_ASSIGN    }
    rule(/<<=/)    { :LEFT_ASSIGN     }
    rule(/\+=/)    { :ADD_ASSIGN      }
    rule(/-=/)     { :SUB_ASSIGN      }
    rule(/\*=/)    { :MUL_ASSIGN      }
    rule(%r'/=')   { :DIV_ASSIGN      }
    rule(/%=/)     { :MOD_ASSIGN      }
    rule(/&=/)     { :AND_ASSIGN      }
    rule(/^=/)     { :XOR_ASSIGN      }
    rule(/|=/)     { :OR_ASSIGN       }
    rule(/>>/)     { :RIGHT_OP        }
    rule(/<</)     { :LEFT_OP         }
    rule(/\+\+/)   { :INC_OP          }
    rule(/--/)     { :DEC_OP          }
    rule(/->/)     { :PTR_OP          }

    rule(/&&/)     { :AND_OP          }
    rule(/||/)     { :OR_OP           }

    rule(/<=/)     { :LE_OP           }
    rule(/>=/)     { :GE_OP           }
    rule(/==/)     { :EQ_OP           }
    rule(/!=/)     { :NE_OP           }

    rule(/;/)      { :SEMICOLON       }

    rule(/\{|<%/)  { :LBRACE          }
    rule(/\}|%>/)  { :RBRACE          }

    rule(/\(/)     { :LPAREN          }
    rule(/\)/)     { :RPAREN          }
    rule(/,/)      { :COMMA           }
    rule(/:/)      { :COLON           }
    rule(/=/)      { :ASSIGN          }
    rule(/\?/)     { :QMARK           }

    rule(/\[|<:/)  { :LBRACKET        }
    rule(/\]|:>/)  { :RBRACKET        }

    rule(/\./)     { :DOT             }
    rule(%r'[&!~\-+*/%<>^|]') { |t| t.to_sym  }

    rule(/[a-z_][a-z0-9_]*/i)  { |t| [:IDENTIFIER, t] }

    # ignore white spaces
    rule(/\s/)
  end
end
