# frozen_string_literal: true

# Usage: bundle exec ruby examples/layout_demo.rb
#
# Two demos in one screen:
#
# 1. OUTER LAYOUT — the App.partition uses several region settings:
#      vertical with fixed heights (h: 3, h: 1) + a fill row
#      horizontal with mixed (w: 12, w: :fill, w: "20%", min: 18)
#      header row split with (w: "30%", w: :fill, w: 10)
#    Each region holds a flat-color HeaderItem so you can see what
#    Layout placed where.
#
# 2. INNER GRID — a single Grid sigil fills the center cell and draws
#    multiple bordered panels on overlapping rects. The cells where
#    panels meet are shared, and Buffer#set merges box-drawing glyphs,
#    so all the internal junctions resolve to ┬ ├ ┤ ┴ ┼ automatically.
#
# Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class HeaderItem
  include Thaum::Sigil

  def initialize(label:, color:)
    @label = label
    @color = color
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: @color)
    y = [canvas.height / 2, 0].max
    canvas.text(content: @label, align: :center, y: y, fg: theme.bg, bg: @color)
  end
end

class Grid
  include Thaum::Sigil

  def focusable? = false

  # All panels are described relative to the grid's own (0,0). Adjacent
  # rects share their edge column or row by one cell so Buffer#set's
  # merge produces a junction instead of two parallel lines.
  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    panels = panel_panels(w: canvas.width, h: canvas.height)
    panels.each { |pair| border(canvas: canvas, rect: pair.first, theme: theme) }
    panels.each { |pair| label(canvas: canvas, rect: pair.first, label: pair.last, theme: theme) } # rubocop:disable Style/CombinableLoops
  end

  private

  def panel_panels(w:, h:)
    th, mh, my, by, bh = band_offsets(h)
    half = (w / 2.0).ceil + 1 # +1 so the two middle cells share a column
    [
      [panel(x: 0,        y: 0,  ww: w,             hh: th), "title"],
      [panel(x: 0,        y: my, ww: half,          hh: mh), "list"],
      [panel(x: half - 1, y: my, ww: w - half + 1,  hh: mh), "preview"],
      [panel(x: 0,        y: by, ww: w,             hh: bh), "status"]
    ]
  end

  def band_offsets(h)
    top_h = [(h * 0.30).round, 3].max
    mid_h = [(h * 0.40).round, 3].max
    mid_y = top_h - 1
    bot_y = mid_y + mid_h - 1
    [top_h, mid_h, mid_y, bot_y, h - bot_y]
  end

  def panel(x:, y:, ww:, hh:) = Thaum::Rect.new(x: x, y: y, width: ww, height: hh)

  def border(canvas:, rect:, theme:)
    canvas.sub(rect: rect).border(fg: theme.border)
  end

  def label(canvas:, rect:, label:, theme:)
    inner = canvas.sub(
      rect: Thaum::Rect.new(x: rect.x + 1, y: rect.y + 1, width: rect.width - 2, height: rect.height - 2)
    )
    inner.text(content: label, fg: theme.dim)
  end
end

class LayoutDemoApp
  include Thaum::App

  def initialize
    t = Thaum::Themes::SOLARIZED_LIGHT
    @title    = HeaderItem.new(label: "Layout DSL — region settings demo", color: t.accent)
    @status   = HeaderItem.new(label: "h:3/h:fill/h:1 outer · w:12/w::fill/w:'20%' min:18 middle", color: t.selection)
    @clock    = HeaderItem.new(label: "12:34", color: t.border)
    @nav      = HeaderItem.new(label: "w: 12", color: t.pressed)
    @aside    = HeaderItem.new(label: "w: '20%'\nmin: 18", color: t.bar_bg)
    @grid     = Grid.new
    @hint     = HeaderItem.new(label: " esc to quit — borders inside the grid merge into junctions", color: t.dim)
  end

  def theme = Thaum::Themes::SOLARIZED_LIGHT

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical do
      region(height: 3)     { header }
      region(height: :fill) { middle }
      region(height: 1)     { @hint }
    end
  end

  private

  def header
    horizontal do
      region(width: "30%") { @title }
      region(width: :fill) { @status }
      region(width: 10)    { @clock }
    end
  end

  def middle
    horizontal do
      region(width: 12)             { @nav }
      region(width: :fill)          { @grid }
      region(width: "20%", min: 18) { @aside }
    end
  end
end

Thaum.run(LayoutDemoApp.new)
