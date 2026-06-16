# frozen_string_literal: true

module Thaum
  # Recursive walk over a Layout subtree. Yields every direct or transitive
  # child of `node`, in declaration order. Callers filter by class.
  module Tree
    module_function

    def walk(node, &block)
      (node.subtree_children || []).each do |child|
        block.call(child)
        walk(child, &block) if child.respond_to?(:subtree_children)
      end
    end
  end
end
