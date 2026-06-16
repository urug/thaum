# frozen_string_literal: true

require "test_helper"

class TestLayout < Minitest::Test
  class FakeSigil
    include Thaum::Sigil

    attr_reader :name

    def initialize(name) = (@name = name)
  end

  class HorizApp
    include Thaum::App

    def initialize
      @left  = FakeSigil.new(:left)
      @right = FakeSigil.new(:right)
    end

    attr_reader :left, :right

    def partition
      horizontal do
        region(width: 30)    { @left }
        region(width: :fill) { @right }
      end
    end
  end

  class VertApp
    include Thaum::App

    def initialize
      @top    = FakeSigil.new(:top)
      @middle = FakeSigil.new(:middle)
      @bottom = FakeSigil.new(:bottom)
    end

    attr_reader :top, :middle, :bottom

    def partition
      vertical do
        region(height: 1)     { @top }
        region(height: :fill) { @middle }
        region(height: 1)     { @bottom }
      end
    end
  end

  class NestedApp
    include Thaum::App

    def initialize
      @sidebar = FakeSigil.new(:sidebar)
      @main    = FakeSigil.new(:main)
      @status  = FakeSigil.new(:status)
    end

    attr_reader :sidebar, :main, :status

    def partition
      vertical do
        region(height: :fill) { workspace }
        region(height: 1)     { @status }
      end
    end

    private

    def workspace
      horizontal do
        region(width: 20)    { @sidebar }
        region(width: :fill) { @main }
      end
    end
  end

  def test_horizontal_assigns_widths
    app  = HorizApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 30, app.left.rect.width
    assert_equal 50, app.right.rect.width
  end

  def test_horizontal_assigns_x_positions
    app  = HorizApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 0,  app.left.rect.x
    assert_equal 30, app.right.rect.x
  end

  def test_horizontal_full_height_passed_through
    app  = HorizApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 24, app.left.rect.height
    assert_equal 24, app.right.rect.height
  end

  def test_vertical_assigns_heights
    app  = VertApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 1,  app.top.rect.height
    assert_equal 22, app.middle.rect.height
    assert_equal 1,  app.bottom.rect.height
  end

  def test_vertical_assigns_y_positions
    app  = VertApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 0,  app.top.rect.y
    assert_equal 1,  app.middle.rect.y
    assert_equal 23, app.bottom.rect.y
  end

  def test_leaf_sigils_collected_in_order
    app  = HorizApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal [app.left, app.right], app.leaf_sigils
  end

  def test_nested_layout_via_helper_method
    app  = NestedApp.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal [app.sidebar, app.main, app.status], app.leaf_sigils
    assert_equal 20, app.sidebar.rect.width
    assert_equal 60, app.main.rect.width
    assert_equal 1,  app.status.rect.height
  end

  def test_percentage_width
    klass = Class.new do
      include Thaum::App

      def initialize
        @a = FakeSigil.new(:a)
        @b = FakeSigil.new(:b)
      end

      attr_reader :a, :b

      def partition
        horizontal do
          region(width: "25%") { @a }
          region(width: :fill) { @b }
        end
      end
    end

    app  = klass.new
    rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    app.run_partition(rect: rect)

    assert_equal 20, app.a.rect.width
    assert_equal 60, app.b.rect.width
  end

  def test_height_inside_horizontal_raises_layout_error
    klass = Class.new do
      include Thaum::App

      def initialize = (@s = FakeSigil.new(:s))

      def partition
        horizontal do
          region(height: 5) { @s }
        end
      end
    end

    err = assert_raises(Thaum::LayoutError) do
      klass.new.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    end
    assert_match(/height:/, err.message)
    assert_match(/horizontal/, err.message)
  end

  def test_width_inside_vertical_raises_layout_error
    klass = Class.new do
      include Thaum::App

      def initialize = (@s = FakeSigil.new(:s))

      def partition
        vertical do
          region(width: 5) { @s }
        end
      end
    end

    err = assert_raises(Thaum::LayoutError) do
      klass.new.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    end
    assert_match(/width:/, err.message)
    assert_match(/vertical/, err.message)
  end
end
