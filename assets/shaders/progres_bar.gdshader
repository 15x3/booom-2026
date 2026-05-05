shader_type canvas_item;

// 进度条控制
uniform float progress : hint_range(0.0, 1.0) = 0.5;

// 颜色设置
uniform vec4 color_good : source_color = vec4(0.0, 1.0, 0.0, 1.0); // 绿色阶段
uniform vec4 color_warning : source_color = vec4(1.0, 0.65, 0.0, 1.0); // 橙色阶段
uniform vec4 color_danger : source_color = vec4(1.0, 0.0, 0.0, 1.0); // 红色阶段
uniform vec4 color_empty : source_color = vec4(0.1, 0.1, 0.1, 1.0); // 未填充部分的颜色

// 阈值设置
uniform float warning_threshold = 0.6; // 进度低于此值变橙
uniform float danger_threshold = 0.3;  // 进度低于此值变红

void fragment() {
    // 获取遮罩贴图（即你那张分段的白色图片）
    vec4 mask = texture(TEXTURE, UV);
    
    // 基础颜色逻辑
    vec4 final_color;
    
    // 根据进度值决定当前格子的颜色状态
    if (UV.x <= progress) {
        // 进度内：根据剩余量决定颜色
        if (progress <= danger_threshold) {
            final_color = color_danger;
        } else if (progress <= warning_threshold) {
            final_color = color_warning;
        } else {
            final_color = color_good;
        }
    } else {
        // 进度外：显示背景深色
        final_color = color_empty;
    }

    // 将计算出的颜色应用到贴图的可见区域（保留原图的透明度）
    COLOR = vec4(final_color.rgb, mask.a);
}