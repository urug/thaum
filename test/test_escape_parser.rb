# frozen_string_literal: true

require "test_helper"

class TestEscapeParser < Minitest::Test
  def parse(bytes)
    Thaum::EscapeParser.parse(bytes)
  end

  def key(k:, ctrl: false, alt: false, shift: false)
    Thaum::KeyEvent.new(key: k, ctrl: ctrl, alt: alt, shift: shift)
  end

  # --- Printable characters ---

  def test_printable_char
    assert_equal [key(k: "a")], parse("a")
  end

  def test_printable_uppercase
    assert_equal [key(k: "A")], parse("A")
  end

  def test_multiple_printable_chars
    assert_equal [key(k: "h"), key(k: "i")], parse("hi")
  end

  # --- Special ground-state keys ---

  def test_enter_cr
    assert_equal [key(k: :enter)], parse("\r")
  end

  def test_enter_lf
    assert_equal [key(k: :enter)], parse("\n")
  end

  def test_tab
    assert_equal [key(k: :tab)], parse("\t")
  end

  def test_backspace_del
    assert_equal [key(k: :backspace)], parse("\x7f")
  end

  def test_backspace_bs
    assert_equal [key(k: :backspace)], parse("\x08")
  end

  # --- Ctrl + letter ---

  def test_ctrl_a
    assert_equal [key(k: "a", ctrl: true)], parse("\x01")
  end

  def test_ctrl_c
    assert_equal [key(k: "c", ctrl: true)], parse("\x03")
  end

  def test_ctrl_z
    assert_equal [key(k: "z", ctrl: true)], parse("\x1a")
  end

  # --- Escape alone ---

  def test_escape_key
    assert_equal [key(k: :escape)], parse("\e")
  end

  # --- Arrow keys (CSI) ---

  def test_arrow_up
    assert_equal [key(k: :up)], parse("\e[A")
  end

  def test_arrow_down
    assert_equal [key(k: :down)], parse("\e[B")
  end

  def test_arrow_right
    assert_equal [key(k: :right)], parse("\e[C")
  end

  def test_arrow_left
    assert_equal [key(k: :left)], parse("\e[D")
  end

  # --- Navigation keys (CSI letter) ---

  def test_home_csi_h
    assert_equal [key(k: :home)], parse("\e[H")
  end

  def test_end_csi_f
    assert_equal [key(k: :end)], parse("\e[F")
  end

  def test_shift_tab
    assert_equal [key(k: :tab, shift: true)], parse("\e[Z")
  end

  # --- Tilde sequences ---

  def test_insert
    assert_equal [key(k: :insert)], parse("\e[2~")
  end

  def test_delete
    assert_equal [key(k: :delete)], parse("\e[3~")
  end

  def test_page_up
    assert_equal [key(k: :page_up)], parse("\e[5~")
  end

  def test_page_down
    assert_equal [key(k: :page_down)], parse("\e[6~")
  end

  # --- Function keys via SS3 ---

  def test_f1_ss3
    assert_equal [key(k: :f1)], parse("\eOP")
  end

  def test_f2_ss3
    assert_equal [key(k: :f2)], parse("\eOQ")
  end

  def test_f3_ss3
    assert_equal [key(k: :f3)], parse("\eOR")
  end

  def test_f4_ss3
    assert_equal [key(k: :f4)], parse("\eOS")
  end

  # --- Function keys via CSI tilde ---

  def test_f5
    assert_equal [key(k: :f5)], parse("\e[15~")
  end

  def test_f6
    assert_equal [key(k: :f6)], parse("\e[17~")
  end

  def test_f11
    assert_equal [key(k: :f11)], parse("\e[23~")
  end

  def test_f12
    assert_equal [key(k: :f12)], parse("\e[24~")
  end

  # --- Alt + char ---

  def test_alt_char
    assert_equal [key(k: "a", alt: true)], parse("\ea")
  end

  def test_alt_uppercase
    assert_equal [key(k: "A", alt: true)], parse("\eA")
  end

  # --- Modified arrow keys ---

  def test_shift_up
    assert_equal [key(k: :up, shift: true)], parse("\e[1;2A")
  end

  def test_ctrl_up
    assert_equal [key(k: :up, ctrl: true)], parse("\e[1;5A")
  end

  # --- Multiple events in one string ---

  def test_sequence_of_chars_and_enter
    assert_equal [key(k: "h"), key(k: "i"), key(k: :enter)], parse("hi\r")
  end

  def test_arrow_followed_by_char
    assert_equal [key(k: :up), key(k: "x")], parse("\e[Ax")
  end

  def test_two_escape_sequences
    assert_equal [key(k: :up), key(k: :down)], parse("\e[A\e[B")
  end

  # --- Bracketed paste ---

  def paste(text) = Thaum::PasteEvent.new(text: text)

  def test_bracketed_paste_emits_single_paste_event
    assert_equal [paste("hello world")], parse("\e[200~hello world\e[201~")
  end

  def test_bracketed_paste_preserves_newlines_and_tabs
    body = "first line\nsecond\ttab\rCR"
    assert_equal [paste(body)], parse("\e[200~#{body}\e[201~")
  end

  def test_bracketed_paste_does_not_interpret_control_chars
    # 0x03 (^C) and 0x7f (backspace) inside a paste must NOT become KeyEvents.
    body = "x\x03y\x7fz"
    assert_equal [paste(body)], parse("\e[200~#{body}\e[201~")
  end

  def test_keys_around_a_paste_are_preserved
    events = parse("a\e[200~hi\e[201~b")
    assert_equal [key(k: "a"), paste("hi"), key(k: "b")], events
  end

  def test_two_consecutive_pastes
    events = parse("\e[200~one\e[201~\e[200~two\e[201~")
    assert_equal [paste("one"), paste("two")], events
  end

  def test_paste_spanning_two_parse_calls
    parser = Thaum::EscapeParser.new
    first  = parser.parse("\e[200~hel")
    second = parser.parse("lo\e[201~done")
    assert_equal [], first, "no events while paste body is incomplete"
    assert_equal [paste("hello"), key(k: "d"), key(k: "o"), key(k: "n"), key(k: "e")], second
  end

  def test_paste_with_embedded_escape_byte_inside_body
    # A raw ESC inside the paste body must be preserved verbatim — not
    # treated as the start of an escape sequence.
    body = "before\eafter"
    assert_equal [paste(body)], parse("\e[200~#{body}\e[201~")
  end

  def test_empty_paste
    assert_equal [paste("")], parse("\e[200~\e[201~")
  end
end
