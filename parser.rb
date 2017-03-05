require_relative 'lexer'

module C
  class BaseParser
    
    def initialize(source)
      @lexer = Lexer.new.lex(source)
      puts 'Lexing Complete'
      p @lexer
    end
    
    protected
    def check_for(*tokens)
      tokens.include?(current_token.type)
    end

    def try_consume_token(*tokens) # x?
      consume_token if check_for(*tokens)
    end

    def require_token(*tokens)
      try_consume_token(*tokens) || raise("Expected #{tokens.join(', ')} got #{current_token.type} at #{current_position.join(':')}")
    end

    def current_token
      @current_token ||= @lexer.shift
    end

    def consume_token
      puts "consume_token: #{@current_token.inspect}"
      token, @current_token = @current_token, nil
      token
    end

    def delimeters(first, last)
      q = try_consume_token(first) || return
      p = yield if q
      require_token(last)
      p
    end

    def require_eol
      check_for(:EOS) || require_token(:NEWLINE)
    end

    def current_position(token = @current_token)
      [token.position.line_number, token.position.line_offset]
    end

    def kleene_plus(*tokens, &block) # x+
      raise 'Only one of tokens or block' if tokens.any? && block

      block = proc { try_consume_token(*tokens) } if tokens.any?

      p = block.() || begin
        if tokens.empty?
          raise "Unexpected token #{current_token.type} at #{current_position.join(':')}"
        else
          raise("Expected #{tokens.join(', ')} got #{current_token.type} at #{current_position.join(':')}")
        end
      end
      [p, *kleene_star(&block)]
    end

    def kleene_star(*tokens, &block) # x*
      raise 'Only one of tokens or block' if tokens.any? && block

      block = proc { try_consume_token(*tokens) } if tokens.any?

      p = []
      until check_for(:EOS)
        p << (block.() || break)
      end
      p
    end
  end
  
  class Parser < BaseParser
    def parse
      p = preprocess
      require_token(:EOS)
      p
    end

    def preprocess
      kleene_star { proc_line }
    end

    def proc_line
      p = file_inclusion || diagnostics || error || macro_define || macro_undef || conditional_compilation || line_control || macro_execution || text_line
      require_eol if p
      p
    end

    def file_inclusion
      [try_consume_token(:DIR_INCLUDE) || return, require_token(:STRING)]
    end

    def macro_define
      # #define
      p = [try_consume_token(:DIR_DEFINE) || return, require_token(:IDENTIFIER)]
      # (args*)
      p << if try_consume_token(:LPAREN)
        args = [*macro_param]
        args.push(*kleene_star { macro_param if try_consume_token(:COMMA) }) if args.any?
        require_token(:LPAREN)
        args
      else
        []
      end
      p << (macro_text || [])
    end

    def macro_text
      kleene_plus { source_text }
    end

    def macro_param
      case current_token.type
        when :IDENTIFIER
          [consume_token, *try_consume_token(:ELLIPSIS)]
        when :ELLIPSIS
          consume_token
      end
    end

    def macro_execution
      [try_consume_token(:DIR_EXEC_MACRO_EXPRESSION) || return, ifexpression]
    end

    def macro_undef
      [try_consume_token(:DIR_EXEC_MACRO_EXPRESSION) || return, require_token(:IDENTIFIER)]
    end

    def conditional_compilation
      p = [try_consume_token(:DIR_IF) || return, ifexpression, statement]
      require_token(:NEWLINE)

      # elif
      kleene_star do
        p << [try_consume_token(:DIR_ELIF) || break, ifexpression, statement]
        require_token(:NEWLINE)
      end

      # else
      q = try_consume_token(:DIR_ELSE)
      if q
        p << [q, statement]
        require_token(:NEWLINE)
      end
      require_token(:DIR_ENDIF)
      p
    end

    def line_control
      [try_consume_token(:DIR_LINE) || return, require_token(:DECIMAL), try_consume_token(:STRING)]
    end

    def diagnostics
      [try_consume_token(:DIR_WARNING, :DIR_PRAGMA) || return, require_token(:MACRO_TEXT)]
    end

    def error
      [try_consume_token(:DIR_ERROR) || return, *try_consume_token(:MACRO_TEXT)]
    end

    def text_line
      kleene_star { source_text } # kleene_plus
    end

    def statement
      kleene_star { proc_line }
    end

    def type_name
      require_token(:IDENTIFIER)
    end

    def ifexpression
      try_consume_token(:IDENTIFIER) || assignment_expression
    end

    def assignment_expression
      p = conditional_expression
      q = try_consume_token(:RIGHT_ASSIGN, :LEFT_ASSIGN, :ADD_ASSIGN, :SUB_ASSIGN, :MUL_ASSIGN, :DIV_ASSIGN, :MOD_ASSIGN, :AND_ASSIGN, :XOR_ASSIGN, :OR_ASSIGN, :ASSIGN)
      p = [q, p, assignment_expression] if q
      p
    end

    def conditional_expression
      p = logical_or_expression
      q = try_consume_token(:QMARK)
      if q
        p = [q, p, assignment_expression]
        require_token(:COLON)
        p << conditional_expression
      end
      p
    end

    def logical_or_expression
      p = logical_and_expression
      q = try_consume_token(:OR_OP)
      p = [q, p, logical_and_expression] if q
      p
    end

    def logical_and_expression
      p = inclusive_or_expression
      q = try_consume_token(:AND_OP)
      p = [q, p, inclusive_or_expression] if q
      p
    end

    def inclusive_or_expression
      p = exclusive_or_expression
      q = try_consume_token(:|)
      p = [q, p, exclusive_or_expression] if q
      p
    end

    def exclusive_or_expression
      p = and_expression
      q = try_consume_token(:XOR_OP)
      p = [q, p, and_expression] if q
      p
    end

    def and_expression
      p = equality_expression
      q = try_consume_token(:&)
      p = [q, p, equality_expression] if q
      p
    end

    def equality_expression
      p = relational_expression
      q = try_consume_token(:EQ_OP, :NE_OP)
      p = [q, p, relational_expression] if q
      p
    end

    def relational_expression
      p = shift_expression
      q = try_consume_token(:<, :>, :LE_OP, :GE_OP)
      p = [q, p, shift_expression] if q
      p
    end

    def shift_expression
      p = additive_expression
      q = try_consume_token(:RIGHT_OP, :LEFT_OP)
      p = [q, p, additive_expression] if q
      p
    end

    def additive_expression
      p = multiplicative_expression
      q = try_consume_token(:+, :-)
      p = [q, p, multiplicative_expression] if q
      p
    end

    def multiplicative_expression
      p = unary_expression
      q = try_consume_token(:*, :/)
      p = [q, p, unary_expression] if q
      p
    end

    def unary_expression
      case current_token.type
        # ++a
        when :INC_OP, :DEC_OP
          [consume_token, unary_expression]
        when :SIZEOF
          p = [consume_token]
          q = try_consume_token(:LPAREN)
          if q
            p << type_name
            require_token(:LPAREN)
          else
            p << unary_expression
          end
          p
        when :DEFINED
          p = [consume_token]
          p << delimeters(:LPAREN, :RPAREN) { type_name } || type_name
          # q = try_consume_token(:LPAREN)
          # if q
          #   p << type_name
          #   require_token(:RPAREN)
          # else
          #   p << type_name
          # end
          # p
        else unary_expression_not_plus_minus
      end
    end

    def unary_expression_not_plus_minus
      case current_token.type
        when :!, :~, :&, :*, :-, :+
          [consume_token, unary_expression]
        when :LPAREN
          [type_name, unary_expression]
        else postfix_expression
      end
    end

    def postfix_expression
      p = primary_expression || delimeters(:LBRACKET, :RBRACKET) { assignment_expression } || begin
        q = try_consume_token(:DOT, :*, :PTR_OP)
        if q
          [q, require_token(:IDENTIFIER)]
        end
      end || require_token(:INC_OP, :DEC_OP)

      # TODO
    end

    def primary_expression
      konstant || case current_token.type
        when :IDENTIFIER
          p = consume_token
          p << delimeters(:LPAREN, :RPAREN) { p = [p, arg_list] }

          # q = try_consume_token(:LPAREN)
          # if q
          #   p = [p, arg_list]
          #   require_token(:RPAREN)
          # end
          # p
        when :LPAREN
          p = assignment_expression
          require_token(:RPAREN)
          p
      end
    end

    def arg_list
      [assignment_expression, *kleene_star { assignment_expression if try_consume_token(:COMMA) }]
    end

    def konstant
      try_consume_token(:HEXADECIMAL, :OCTAL, :DECIMAL, :STRING, :FLOAT, :CHAR)
    end

    def source_text
      source_expression || try_consume_token(:COMMA) || try_consume_token(:LPAREN) || try_consume_token(:RPAREN)
    end

    def macro_expansion
      p = try_consume_token(:IDENTIFIER) || return
      p << delimeters(:LPAREN, :RPAREN) { p << mac_args }
    end

    def mac_args
      [marg, kleene_star { marg if try_consume_token(:COMMA) }]
    end

    def marg
      p = []
      case current_token.type
        when :IDENTIFIER
          p << consume_token
          require_token(:LPAREN)
          p << macro_expansion
        when :SIZEOF then p << consume_token
        when :LPAREN
          p << mac_args
        when :SEMICOLON then p
        when :STRINGFICATION
          p << consume_token
          p << require_token(:IDENTIFIER)
        else primary_source
      end
    end

    def source_expression
      p = []
      case current_token.type
        when :IDENTIFIER
          p << consume_token
          p << require_token(:LPAREN)
          p << macro_expansion
        when :STRINGIFICATION
          p << consume_token
          p << require_token(:IDENTIFIER)
        when :SIZEOF, :SEMICOLON then consume_token
        else
          p = primary_source
          q = try_consume_token(:SHARPSHARP)
          p = [p, concatenate] if q
          p
      end
    end

    def concatenate
      p = [primary_source]
      require_token(:SHARPSHARP)
      p << primary_source
      p
    end

    def primary_source
      p = []
      case current_token.type
        when :SHARPSHARP
          p << consume_token
          p << require_token(:IDENTIFIER)
        when :IDENTIFIER
          p << consume_token
        else konstant || ckeyword || coperator || nil
      end
    end

    def coperator
      try_consume_token(:COLON, :QMARK, :PTR_OP, :LBRACE, :RBRACE, :LBRACKET, :RBRACKET, :*, :EQ_OP, :NE_OP, :LE_OP, :GE_OP, :<, :>, :/,
                        :INC_OP, :DEC_OP, :%, :LEFT_OP, :RIGHT_OP, :AND_OP, :OR_OP, :|, :^, :&, :+, :-, :~, :ASSIGN,
                        :MUL_ASSIGN, :DIV_ASSIGN, :MOD_ASSIGN, :ADD_ASSIGN, :SUB_ASSIGN, :LEFT_ASSIGN, :RIGHT_ASSIGN,
                        :AND_ASSIGN, :XOR_ASSIGN, :OR_ASSIGN, :!, :ELLIPSIS)
    end

    def ckeyword
      try_consume_token(:AUTO, :BREAK, :CASE, :CHAR, :CONST, :CONTINUE, :DEFINED, :DOUBLE, :DO, :ELSE, :ENUM, :EXTERN,
                        :FLOAT, :FOR, :IF, :INT, :LONG, :REGISTER, :RETURN, :SHORT, :SIGNED, :SIZEOF, :STATIC, :STRUCT,
                        :SWITCH, :TYPEDEF, :UNION, :UNSIGNED, :VOID, :VOLATILE, :WHILE)
    end
  end
end

def ask(text)
  print text
  gets.chomp
end

# source = File.read('E:\program files (x86)\Windows Kits\10\Include\10.0.14388.0\um\WinUser.h');
source=<<~FILE
  #include <stdlib> // this is a Helloooo comment%
  #include "stdlib" // this is a Helloooo comment%
  #define HELLOOOOO 42
  #pragma once
  #if !defined(WINUSERAPI)
  #endif
FILE
# source = "#include <stdlib>"
ast = C::Parser.new(source).parse
p ast

# loop do
#   line = ask('C > ')
#
#   break if line == 'quit' or line == 'exit'
#
#   begin
#     # source =
#     ast = C::Parser.parse(source)
#     puts ast
#
#   rescue RLTK::NotInLanguage
#     puts 'Line was not in language.'
#   end
# end