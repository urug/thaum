# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "thaum/minitest"

class TestBufferSnapshots < Minitest::Test
  def buffer(width: 10, height: 3)
    Thaum::Rendering::Buffer.new(width: width, height: height)
  end

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def test_text_snapshot_is_plain_text_one_line_per_row
    buf = buffer
    canvas(buf).text(content: "hello", x: 0, y: 0)
    canvas(buf).text(content: "world", x: 0, y: 2)

    expected = [
      "hello     ",
      "          ",
      "world     "
    ].join("\n")
    assert_equal expected, buf.to_text_snapshot
  end

  def test_text_snapshot_strips_no_ansi
    buf = buffer
    canvas(buf).text(content: "x", x: 0, y: 0, fg: "#ff0000", bg: "#00ff00")
    refute_includes buf.to_text_snapshot, "\e["
  end

  def test_ansi_snapshot_emits_color_escapes
    buf = buffer
    canvas(buf).text(content: "x", x: 0, y: 0, fg: "#ff0000")
    snap = buf.to_ansi_snapshot
    assert_includes snap, "\e[38;2;255;0;0m"
    assert_includes snap, "x"
  end

  def test_ansi_snapshot_resets_when_last_cell_is_styled
    buf = buffer(width: 3, height: 1)
    (0..2).each { |x| buf.set(x: x, y: 0, char: "x", style: Thaum::Rendering::Style.new(fg: "#ff0000")) }
    snap = buf.to_ansi_snapshot
    assert snap.end_with?(Thaum::Seq::RESET), "expected styled row to end with RESET, got: #{snap.inspect}"
  end

  def test_ansi_snapshot_returns_to_unstyled_via_inline_reset
    buf = buffer
    canvas(buf).text(content: "x", x: 0, y: 0, fg: "#ff0000")
    snap = buf.to_ansi_snapshot
    # The styled char appears before the inline reset; trailing cells are plain.
    assert_includes snap, "\e[38;2;255;0;0mx\e[0m"
  end

  def test_ansi_snapshot_unstyled_row_has_no_reset
    buf = buffer
    snap = buf.to_ansi_snapshot
    refute_includes snap, "\e["
  end

  def test_ansi_snapshot_emits_bold_when_styled
    buf = buffer
    buf.set(x: 0, y: 0, char: "B", style: Thaum::Rendering::Style.new(bold: true))
    snap = buf.to_ansi_snapshot
    assert_includes snap, Thaum::Seq::BOLD
  end

  def test_ansi_snapshot_row_count_matches_buffer_height
    buf = buffer(width: 5, height: 4)
    assert_equal 4, buf.to_ansi_snapshot.split("\n", -1).length
  end
end

class TestAssertSnapshot < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("thaum_snap")
    @orig = Dir.pwd
    Dir.chdir(@dir)
    FileUtils.mkdir_p("test/snapshots")
    ENV.delete("UPDATE_SNAPSHOTS")
  end

  def teardown
    Dir.chdir(@orig)
    FileUtils.remove_entry(@dir)
    ENV.delete("UPDATE_SNAPSHOTS")
  end

  def test_writes_fixture_on_first_run_and_passes
    _out, err = capture_io { assert_snapshot(actual: "hello\n", name: "demo/first") }
    assert_path_exists "test/snapshots/demo/first.txt"
    assert_equal "hello\n", File.read("test/snapshots/demo/first.txt")
    assert_match(/wrote new snapshot/, err)
  end

  def test_matches_existing_fixture
    File.write("test/snapshots/match.txt", "expected\n")
    assert_snapshot(actual: "expected\n", name: "match")
  end

  def test_mismatch_fails_with_path_hint
    File.write("test/snapshots/mismatch.txt", "expected\n")
    err = assert_raises(Minitest::Assertion) do
      assert_snapshot(actual: "different\n", name: "mismatch")
    end
    assert_match(/Snapshot "mismatch" mismatch/, err.message)
    assert_match(/UPDATE_SNAPSHOTS=1/, err.message)
  end

  def test_update_mode_rewrites_existing_fixture
    File.write("test/snapshots/upd.txt", "old\n")
    ENV["UPDATE_SNAPSHOTS"] = "1"
    capture_io { assert_snapshot(actual: "new\n", name: "upd") }
    assert_equal "new\n", File.read("test/snapshots/upd.txt")
  end

  def test_ansi_content_uses_ans_extension
    capture_io { assert_snapshot(actual: "hi\e[31mthere\e[0m", name: "colored") }
    assert_path_exists "test/snapshots/colored.ans"
    refute_path_exists "test/snapshots/colored.txt"
  end

  def test_text_content_uses_txt_extension
    capture_io { assert_snapshot(actual: "plain", name: "plain") }
    assert_path_exists "test/snapshots/plain.txt"
  end
end
