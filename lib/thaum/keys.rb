# frozen_string_literal: true

module Thaum
  module Keys
    # Control Sequence Introducer (CSI) sequences: \e[ + final byte
    # e.g. up arrow → \e[A
    CSI = {
      Seq::CSI_UP[-1] => :up,
      Seq::CSI_DOWN[-1] => :down,
      Seq::CSI_RIGHT[-1] => :right,
      Seq::CSI_LEFT[-1] => :left,
      Seq::CSI_HOME[-1] => :home,
      Seq::CSI_END[-1] => :end
    }.freeze

    # Control Sequence Introducer (CSI) tilde sequences: \e[ + number + ~
    # e.g. delete → \e[3~  (the number identifies the key, ~ is always the final byte)
    TILDE = {
      Seq::TILDE_HOME[2..-2].to_i => :home,
      Seq::TILDE_INSERT[2..-2].to_i => :insert,
      Seq::TILDE_DELETE[2..-2].to_i => :delete,
      Seq::TILDE_END[2..-2].to_i => :end,
      Seq::TILDE_PAGE_UP[2..-2].to_i => :page_up,
      Seq::TILDE_PAGE_DOWN[2..-2].to_i => :page_down,
      Seq::TILDE_F1[2..-2].to_i => :f1,
      Seq::TILDE_F2[2..-2].to_i => :f2,
      Seq::TILDE_F3[2..-2].to_i => :f3,
      Seq::TILDE_F4[2..-2].to_i => :f4,
      Seq::TILDE_F5[2..-2].to_i => :f5,
      Seq::TILDE_F6[2..-2].to_i => :f6,
      Seq::TILDE_F7[2..-2].to_i => :f7,
      Seq::TILDE_F8[2..-2].to_i => :f8,
      Seq::TILDE_F9[2..-2].to_i => :f9,
      Seq::TILDE_F10[2..-2].to_i => :f10,
      Seq::TILDE_F11[2..-2].to_i => :f11,
      Seq::TILDE_F12[2..-2].to_i => :f12
    }.freeze

    # Single Shift 3 (SS3) sequences: \eO + final byte
    # Older VT100 encoding for function and arrow keys; many terminals still emit
    # these for F1-F4 and arrows in application cursor mode.
    SS3 = {
      Seq::SS3_F1[-1] => :f1,
      Seq::SS3_F2[-1] => :f2,
      Seq::SS3_F3[-1] => :f3,
      Seq::SS3_F4[-1] => :f4,
      Seq::SS3_HOME[-1] => :home,
      Seq::SS3_END[-1] => :end,
      Seq::SS3_UP[-1] => :up,
      Seq::SS3_DOWN[-1] => :down,
      Seq::SS3_RIGHT[-1] => :right,
      Seq::SS3_LEFT[-1] => :left
    }.freeze
  end
end
