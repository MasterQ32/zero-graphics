//!
//! A label is a simple control that shows a text on the user interface.
//! It doesn't have much interaction besides rendering.
//!

const ui = @import("ui");

font: ?ui.Font = null,
text: ?[]const u8 = null,

vertical_alignment: ?ui.VerticalAlignment = null,
horizontal_alignment: ?ui.HorizontalAlignment = null,

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return false;
}

pub fn isHitTestVisible(ctrl: *@This()) bool {
    _ = ctrl;
    return false;
}
