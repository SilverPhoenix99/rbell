class Trie
  attr_reader :root

  def initialize
    @root = Node.new([])
  end

  def insert(string)
    node = string.reduce(@root) { |node, char| node.insert(char) }
    node.eos = true
    nil
  end

  def longest_common_prefixes
    @root.branches.values.map do |node|
      node = node.successor until node.divergent? || node.eos?
      node
    end
  end

  def group_by_prefixes
    longest_common_prefixes.map do |node|
      size = node.string.size
      [node.string, node.get_whole_string.map do |s|
        s.string[size..-1]
      end]
    end.to_h
  end
end

class Trie
  class Node
    attr_reader :string
    attr_writer :eos

    def initialize(string)
      @string = string
      @branches = {}
      @eos = false
    end

    # Returns the node where `char' was inserted
    def insert(char)
      @branches[char] ||= Node.new(@string.dup << char)
    end

    def branches
      @branches
    end

    def successor
      @branches.first.last unless divergent? || leaf?
    end

    def get_whole_string
      buffer = []
      buffer << self if eos?
      @branches.values.each { |node| buffer.push(*node.get_whole_string) }
      buffer
    end

    def eos?
      @eos
    end

    def divergent?
      @branches.size > 1
    end

    def leaf?
      @branches.empty?
    end
  end
end

__END__
t = Trie.new
t.insert([:a, :b, :c])
t.insert([:a, :b, :d])
t.insert([:a, :b, :b])
t.insert([:a, :c, :d])
t.insert([:a, :a, :a])
t.insert([:a, :a])
t.insert([:b, :c, :d])

t.insert([:c, :a])
# t.insert([:c, :a, :a])
t.insert([:c, :a, :a, :b])
t.insert([:c, :a, :a, :a])

require 'pp'
pp t.longest_common_prefixes
pp t.group_by_prefixes