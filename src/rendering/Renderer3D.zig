const std = @import("std");
const gles = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_renderer2D);

const glesh = @import("gles-helper.zig");

const ResourceManager = @import("ResourceManager.zig");
const ResourcePool = @import("resource_pool.zig").ResourcePool;

const zigimg = @import("zigimg");

const Self = @This();

const Mesh = ResourceManager.Mesh;
const Geometry = ResourceManager.Geometry;
const Texture = ResourceManager.Texture;
const Vertex = ResourceManager.Vertex;
const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;
const Point = types.Point;
const Mat4 = [4][4]f32;

pub const DrawError = error{OutOfMemory};
pub const InitError = ResourceManager.CreateResourceDataError || error{ OutOfMemory, GraphicsApiFailure };

const attributes = Geometry.attributes;

static_geometry_shader: *ResourceManager.Shader,

/// list of CCW triangles that will be rendered 
draw_calls: std.ArrayList(DrawCall),

allocator: std.mem.Allocator,

resources: *ResourceManager,

white_texture: *ResourceManager.Texture,

pub fn init(resources: *ResourceManager, allocator: std.mem.Allocator) InitError!Self {
    const static_vertex_source =
        \\attribute vec3 vPosition;
        \\attribute vec3 vNormal;
        \\attribute vec2 vUV;
        \\uniform mat4 uWorldMatrix;
        \\uniform mat4 uViewProjMatrix;
        \\varying vec2 aUV;
        \\varying vec3 aNormal;
        \\void main()
        \\{
        \\   gl_Position = uViewProjMatrix * uWorldMatrix * vec4(vPosition, 1.0);
        \\   aNormal = mat3(uWorldMatrix) * normalize(vNormal);
        \\   aUV = vUV;
        \\}
    ;
    const static_alphatest_fragment_source =
        \\precision mediump float;
        \\varying vec2 aUV;
        \\varying vec3 aNormal;
        \\uniform sampler2D uTexture;
        \\void main()
        \\{
        \\   vec3 light_color_a = vec3(0.86, 0.77, 0.38); // 0xdcc663
        \\   vec3 light_color_b = vec3(0.25, 0.44, 0.43); // 0x40716f
        \\   vec3 light_dir_a = normalize(vec3(-0.3, -0.4, -0.1));
        \\   vec3 light_dir_b = normalize(vec3(0.1, 1.0, 0.2));
        \\   float light_val_a = clamp(-dot(aNormal, light_dir_a), 0.0, 1.0);
        \\   float light_val_b = clamp(-dot(aNormal, light_dir_b), 0.0, 1.0);
        \\   vec3 lighting = light_color_a * light_val_a + light_color_b * light_val_b;
        \\   gl_FragColor = texture2D(uTexture, aUV);
        \\   if(gl_FragColor.a < 0.5)
        \\     discard;
        \\   gl_FragColor.rgb *= lighting;
        \\}
    ;

    // const static_geometry_shader = try

    var static_geometry_shader = try resources.createShader(ResourceManager.BasicShader{
        .vertex_shader = static_vertex_source,
        .fragment_shader = static_alphatest_fragment_source,
        .attributes = glesh.attributes(attributes),
    });
    errdefer resources.destroyShader(static_geometry_shader);

    var self = Self{
        .allocator = allocator,
        .resources = resources,

        .static_geometry_shader = static_geometry_shader,

        .draw_calls = std.ArrayList(DrawCall).init(allocator),
        .white_texture = undefined,
    };

    self.white_texture = try self.resources.createTexture(.@"3d", ResourceManager.FlatTexture{
        .width = 2,
        .height = 2,
        .color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
    });

    return self;
}

pub fn deinit(self: *Self) void {
    self.reset();
    self.resources.destroyShader(self.static_geometry_shader);
    self.draw_calls.deinit();
    self.* = undefined;
}

const Uniforms = struct {
    // vertex shader
    uWorldMatrix: gles.GLint,
    uViewProjMatrix: gles.GLint,

    // fragment shader
    uTexture: gles.GLint,
};

/// Resets the state of the renderer and prepares a fresh new frame.
pub fn reset(self: *Self) void {
    // release all geometries.
    for (self.draw_calls.items) |draw_call| {
        self.resources.destroyGeometry(draw_call.geometry);
    }
    self.draw_calls.shrinkRetainingCapacity(0);
}

/// Draws the given `geometry` with the given world `transform`.
pub fn drawGeometry(self: *Self, geometry: *Geometry, transform: Mat4) !void {
    const dc = try self.draw_calls.addOne();
    errdefer _ = self.draw_calls.pop(); // remove the draw call in case of error

    dc.* = DrawCall{
        .geometry = geometry,
        .transform = transform,
    };

    // we need to keep the geometry alive until someone calls `reset` on the renderer.
    // otherwise, we will have the problem that a temporary geometry will be freed before
    // we render it.
    self.resources.retainGeometry(geometry);
}

/// Renders the currently contained data to the screen.
pub fn render(self: Self, viewProjectionMatrix: [4][4]f32) void {
    glesh.enableAttributes(attributes);
    defer glesh.disableAttributes(attributes);

    gles.enable(gles.DEPTH_TEST);
    gles.disable(gles.BLEND);

    gles.depthFunc(gles.LEQUAL);

    var uniforms = glesh.fetchUniforms(self.static_geometry_shader.instance.?, Uniforms);

    gles.useProgram(self.static_geometry_shader.instance.?);
    gles.uniform1i(uniforms.uTexture, 0);
    gles.uniformMatrix4fv(uniforms.uViewProjMatrix, 1, gles.FALSE, @ptrCast([*]const f32, &viewProjectionMatrix));

    gles.activeTexture(gles.TEXTURE0);

    for (self.draw_calls.items) |draw_call| {
        draw_call.geometry.bind();

        gles.uniformMatrix4fv(uniforms.uWorldMatrix, 1, gles.FALSE, @ptrCast([*]const f32, &draw_call.transform));

        for (draw_call.geometry.meshes) |mesh| {
            const tex_handle = mesh.texture orelse self.white_texture;

            gles.bindTexture(gles.TEXTURE_2D, tex_handle.instance.?);
            gles.drawElements(
                gles.TRIANGLES,
                @intCast(gles.GLsizei, mesh.count),
                gles.UNSIGNED_SHORT,
                @intToPtr(?*const anyopaque, @sizeOf(u16) * mesh.offset),
            );
        }
    }
}

const DrawCall = struct {
    transform: Mat4,
    geometry: *Geometry,
};
