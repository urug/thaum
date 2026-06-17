# frozen_string_literal: true

module Thaum
  module Layout
    attr_reader :rect, :leaf_sigils, :subtree_leaves, :child_layouts, :subtree_children

    # Override on any Layout node (including App) to specify a Tab traversal
    # order for that subtree. Return an array of leaf Sigils. nil (default)
    # means "use left-to-right leaf order."
    def focus_order = nil

    # Called by the run loop (or repartition) to assign geometry and walk the partition tree.
    # Returns the flat list of leaf Sigils in render order.
    def run_partition(rect:, collector: nil)
      @rect = rect
      collector ||= []
      start = collector.size
      @leaf_sigils     = collector
      @child_layouts   = []
      @subtree_children = []
      # An Octagram may inset the rect its children partition into so its
      # render hook (border, padding) survives. Plain Layout passes through.
      @rect = inset_for_partition(rect)
      partition
      @rect = rect
      @subtree_leaves = collector[start..] || []
      collector
    end

    # Override on Octagram (or any Layout) to inset the rect that this
    # node's children partition into. Defaults to identity.
    def inset_for_partition(rect)
      return rect unless respond_to?(:partition_inset)

      inset = partition_inset || {}
      Rect.new(
        x:      rect.x + (inset[:left]   || 0),
        y:      rect.y + (inset[:top]    || 0),
        width:  [rect.width  - (inset[:left] || 0) - (inset[:right]  || 0), 0].max,
        height: [rect.height - (inset[:top]  || 0) - (inset[:bottom] || 0), 0].max
      )
    end

    # Re-run partition for this node's subtree using its current rect.
    def repartition
      return unless @rect

      old_leaves    = @leaf_sigils || []
      old_octagrams = collect_octagrams

      new_leaves = []
      run_partition(rect: @rect, collector: new_leaves)

      new_octagrams = collect_octagrams

      # Fire on_unmount for removed Sigils and Octagrams.
      (old_leaves - new_leaves).each(&:on_unmount)
      (old_octagrams - new_octagrams).each(&:on_unmount)

      # Rewire handler parents across the (possibly restructured) subtree so
      # newly-added Octagrams and Sigils see the right chain BEFORE on_mount.
      # Only rewires when we can identify this node's role in the dispatch
      # chain — App (root) or Octagram (its own handler scope).
      app = thaum_app_ref || (is_a?(Octagram) ? @thaum_app : nil)
      wire_handler_parents(handler_parent: self, app: app) if app

      # Fire on_mount for newly-added Sigils and Octagrams.
      (new_octagrams - old_octagrams).each do |o|
        o.thaum_app = app if app
        o.on_mount
      end
      (new_leaves - old_leaves).each do |s|
        s.thaum_app = app if app
        s.on_mount
      end

      @leaf_sigils = new_leaves

      # Re-validate focus_order in this subtree after structural change.
      validate_focus_order_tree
    end

    # Walk this subtree and collect every Octagram node (excluding self).
    def collect_octagrams
      result = []
      (@subtree_children || []).each do |child|
        if child.is_a?(Octagram)
          result << child
          result.concat(child.collect_octagrams)
        elsif child.respond_to?(:collect_octagrams)
          result.concat(child.collect_octagrams)
        end
      end
      result
    end

    # Walk this Layout node and every descendant Layout, raising
    # FocusOrderError if any defines a focus_order that does not exactly
    # cover the focusable leaves in its subtree.
    def validate_focus_order_tree
      validate_focus_order_node
      (@child_layouts || []).each(&:validate_focus_order_tree)
    end

    # Build the Tab traversal order for this subtree, recursively expanding
    # any nested Layout that itself has focus_order. When no focus_order is
    # defined at any level, this falls through to left-to-right leaf order.
    def effective_focus_order
      order = focus_order
      return order if order

      result = []
      layout_subtree_in_order.each do |node|
        if node.is_a?(Sigil)
          result << node if node.focusable?
        else
          result.concat(node.effective_focus_order)
        end
      end
      result
    end

    # The direct children of this Layout in declaration order — both Sigils
    # and nested Layouts. Built during partition (see place_child).
    def layout_subtree_in_order = @subtree_children || []

    # Scope units for Tab cycling within THIS focus scope. A "scope" is the
    # App or an Octagram. A unit is either a focusable Sigil (reached through
    # plain Layouts only) or a nested Octagram (which appears as one unit and
    # is itself a scope). Plain Layouts are transparent — their units are
    # flattened into the parent scope.
    def focus_scope_units
      result = []
      (@subtree_children || []).each do |child|
        case child
        when Sigil
          result << child if child.focusable?
        when Octagram
          result << child if child.focusable_descendant?
        else
          result.concat(child.focus_scope_units) if child.respond_to?(:focus_scope_units)
        end
      end
      result
    end

    # Recursively descend into this Octagram (or plain Layout) to find its
    # first focusable leaf — used when Tab enters an Octagram unit.
    def first_focusable_leaf
      (@subtree_children || []).each do |child|
        case child
        when Sigil
          return child if child.focusable?
        else
          leaf = child.first_focusable_leaf if child.respond_to?(:first_focusable_leaf)
          return leaf if leaf
        end
      end
      nil
    end

    # Mirror of first_focusable_leaf for Shift-Tab entry.
    def last_focusable_leaf
      (@subtree_children || []).reverse_each do |child|
        case child
        when Sigil
          return child if child.focusable?
        else
          leaf = child.last_focusable_leaf if child.respond_to?(:last_focusable_leaf)
          return leaf if leaf
        end
      end
      nil
    end

    def focusable_descendant?
      !first_focusable_leaf.nil?
    end

    # Walk the subtree top-down, wiring each leaf Sigil and each Octagram.
    # Leaves and Octagrams get _handler_parent set to the innermost
    # enclosing Octagram (or the App when there is none). Plain Layout
    # nodes are transparent — their children inherit the outer parent.
    def wire_handler_parents(handler_parent:, app:)
      (@subtree_children || []).each do |child|
        case child
        when Sigil
          child.handler_parent = handler_parent
          child.thaum_app      = app
        when Octagram
          child.handler_parent = handler_parent
          child.thaum_app      = app
          child.wire_handler_parents(handler_parent: child, app: app)
        else
          child.wire_handler_parents(handler_parent:, app:) if child.respond_to?(:wire_handler_parents)
        end
      end
    end

    # Override to specify the layout. Must call horizontal/vertical.
    def partition; end

    private

    def horizontal(&) = divide_axis(:cols, &)
    def vertical(&)   = divide_axis(:rows, &)

    def region(**opts, &child_block)
      @divide_frame << { opts: opts, block: child_block }
    end

    def divide_axis(axis, &block)
      parent_rect = @rect
      saved_frame = @divide_frame
      @divide_frame = []

      block.call

      specs = @divide_frame
      @divide_frame = saved_frame

      validate_axis_kwargs(axis: axis, specs: specs)

      calc_rects(parent_rect: parent_rect, axis: axis, specs: specs).each_with_index do |child_rect, i|
        @rect = child_rect
        place_child(child: specs[i][:block].call, rect: child_rect)
      end

      @rect = parent_rect
    end

    def validate_axis_kwargs(axis:, specs:)
      expected, forbidden = axis == :cols ? %i[width height] : %i[height width]
      specs.each do |spec|
        next unless spec[:opts].key?(forbidden)

        direction = axis == :cols ? "horizontal" : "vertical"
        raise LayoutError,
              "region(#{forbidden}:) is invalid inside #{direction} — use #{expected}: instead"
      end
    end

    def place_child(child:, rect:)
      @subtree_children ||= []
      if child.is_a?(Sigil)
        child.rect = rect
        @leaf_sigils << child
        @subtree_children << child
      elsif child.respond_to?(:run_partition)
        @child_layouts << child
        @subtree_children << child
        child.run_partition(rect: rect, collector: @leaf_sigils)
      end
    end

    def validate_focus_order_node
      order = focus_order
      return if order.nil?

      unless order.is_a?(Array)
        raise FocusOrderError,
              "#{self.class}#focus_order must return an Array, got #{order.class}"
      end

      focusable = (@subtree_leaves || []).select(&:focusable?)
      missing    = focusable - order
      extras     = order - focusable
      duplicates = order.tally.select { |_, c| c > 1 }.keys

      return if missing.empty? && extras.empty? && duplicates.empty?

      msg = "#{self.class}#focus_order is invalid:"
      msg += " missing #{missing.map(&:class).join(', ')};" unless missing.empty?
      msg += " unknown entries #{extras.map(&:class).join(', ')};" unless extras.empty?
      msg += " duplicates #{duplicates.map(&:class).join(', ')};" unless duplicates.empty?
      raise FocusOrderError, msg
    end

    def calc_rects(parent_rect:, axis:, specs:)
      if axis == :cols
        total       = parent_rect.width
        fixed_total = specs.sum { |s| integer_size(val: s[:opts][:width], total: total) || 0 }
        fill_count  = specs.count { |s| s[:opts][:width] == :fill }
        fill_size   = fill_count.positive? ? (total - fixed_total) / fill_count : 0
        leftover    = fill_count.positive? ? (total - fixed_total) % fill_count : 0

        x = parent_rect.x
        specs.each_with_index.map do |spec, i|
          fill_index = specs[0..i].count { |s| s[:opts][:width] == :fill } - 1
          last_fill  = fill_index >= 0 && fill_index == fill_count - 1

          w = resolved_size(val: spec[:opts][:width], total: total, fill_size: fill_size,
                            extra: last_fill ? leftover : 0)
          w = apply_min_max(size: w, min: spec[:opts][:min], max: spec[:opts][:max])
          r = Rect.new(x: x, y: parent_rect.y, width: w, height: parent_rect.height)
          x += w
          r
        end
      else
        total       = parent_rect.height
        fixed_total = specs.sum { |s| integer_size(val: s[:opts][:height], total: total) || 0 }
        fill_count  = specs.count { |s| s[:opts][:height] == :fill }
        fill_size   = fill_count.positive? ? (total - fixed_total) / fill_count : 0
        leftover    = fill_count.positive? ? (total - fixed_total) % fill_count : 0

        y = parent_rect.y
        specs.each_with_index.map do |spec, i|
          fill_index = specs[0..i].count { |s| s[:opts][:height] == :fill } - 1
          last_fill  = fill_index >= 0 && fill_index == fill_count - 1

          h = resolved_size(val: spec[:opts][:height], total: total, fill_size: fill_size,
                            extra: last_fill ? leftover : 0)
          h = apply_min_max(size: h, min: spec[:opts][:min], max: spec[:opts][:max])
          r = Rect.new(x: parent_rect.x, y: y, width: parent_rect.width, height: h)
          y += h
          r
        end
      end
    end

    def integer_size(val:, total:)
      return val             if val.is_a?(Integer)
      return nil             if val == :fill
      return val.to_i * total / 100 if val.is_a?(String) && val.end_with?("%")

      nil
    end

    def resolved_size(val:, total:, fill_size:, extra:)
      return val + 0                             if val.is_a?(Integer)
      return fill_size + extra                   if val == :fill
      return val.to_i * total / 100 if val.is_a?(String) && val.end_with?("%")

      fill_size + extra # default to fill if unspecified
    end

    def apply_min_max(size:, min:, max:)
      size = [size, min].max if min
      size = [size, max].min if max
      [size, 0].max
    end

    # Used by repartition to wire new sigils to the app.
    # overridden in App
    def thaum_app_ref = nil
  end
end
