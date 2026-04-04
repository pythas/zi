const Color = @import("primitives.zig").Color;
const Rectangle = @import("primitives.zig").Rectangle;
const rl = @import("rl.zig").raylib;
const Vec2i = @import("primitives.zig").Vec2i;

pub const UiState = struct {
    is_hovered: bool = false,
    is_clicked: bool = false,
    is_down: bool = false,
    is_right_clicked: bool = false,
    is_right_down: bool = false,
};

pub const UiStyle = struct {
    text_color: Color = Color.init(255, 255, 255, 255),
    text_color_disabled: Color = Color.init(128, 128, 128, 255),

    button_bg_color: Color = Color.init(46, 46, 46, 255),
    button_bg_color_hovered: Color = Color.init(64, 64, 64, 255),
    button_bg_color_pressed: Color = Color.init(30, 30, 30, 255),
    button_bg_color_disabled: Color = Color.init(36, 36, 36, 255),

    button_bg_color_active: Color = Color.init(179, 102, 26, 255),
    button_bg_color_active_hovered: Color = Color.init(199, 122, 46, 255),
    button_bg_color_active_pressed: Color = Color.init(159, 82, 6, 255),

    button_text_color: Color = Color.init(240, 240, 240, 255),
    button_text_color_disabled: Color = Color.init(100, 100, 100, 255),
    button_text_color_active: Color = Color.init(255, 255, 255, 255),
};

pub const Ui = struct {
    style: UiStyle,

    const Self = @This();

    pub fn init() Self {
        return .{
            .style = UiStyle{},
        };
    }

    pub fn rectangle(_: *Self, rect: Rectangle, color: Color) void {
        rl.DrawRectangleRec(@bitCast(rect), @bitCast(color));
    }

    pub fn label(_: *Self, position: Vec2i, text: [:0]const u8, size: u8, color: Color) void {
        rl.DrawText(text, position[0], position[1], size, @bitCast(color));
    }

    pub fn panel(self: *Self, rect: Rectangle, color: Color) void {
        self.rectangle(rect, color);
    }

    pub fn button(
        self: *Self,
        rect: Rectangle,
        is_active: bool,
        text: [:0]const u8,
    ) UiState {
        var state = UiState{};
        const mouse_pos = rl.GetMousePosition();

        if (rl.CheckCollisionPointRec(mouse_pos, @bitCast(rect))) {
            state.is_hovered = true;
            state.is_down = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT);
            state.is_clicked = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);
            state.is_right_down = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT);
            state.is_right_clicked = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_RIGHT);
        }

        var bg_color: Color = undefined;
        var text_color: Color = undefined;

        if (is_active) {
            if (state.is_down) {
                bg_color = self.style.button_bg_color_active_pressed;
            } else if (state.is_hovered) {
                bg_color = self.style.button_bg_color_active_hovered;
            } else {
                bg_color = self.style.button_bg_color_active;
            }
            text_color = self.style.button_text_color_active;
        } else {
            if (state.is_down) {
                bg_color = self.style.button_bg_color_pressed;
            } else if (state.is_hovered) {
                bg_color = self.style.button_bg_color_hovered;
            } else {
                bg_color = self.style.button_bg_color;
            }
            text_color = self.style.button_text_color;
        }

        self.rectangle(rect, bg_color);

        const font_size = 10;
        const text_width = rl.MeasureText(text, font_size);

        const text_x = @as(i32, @intFromFloat(rect.x + (rect.width / 2.0))) - @divTrunc(text_width, 2);
        const text_y = @as(i32, @intFromFloat(rect.y + (rect.height / 2.0))) - @divTrunc(font_size, 2);

        self.label(.{ text_x, text_y }, text, font_size, text_color);

        return state;
    }
};
