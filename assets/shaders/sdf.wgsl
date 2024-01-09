// The time since startup data is in the globals binding which is part of the mesh_view_bindings import
#import bevy_pbr::{
    mesh_view_bindings::globals,
    forward_io::VertexOutput,
}

const BOX_SIZE: f32 = 10.0;
const CAMERA_POSITION: f32 = 10.0;
const RAY_ORIGIN: vec3f = vec3(0.0, 0.0, CAMERA_POSITION);
const STEP_COUNT: i32 = 100;
const FRONT_NORMAL: vec3f = vec3(0.0, 0.0, -1.0);
const LIGHT_COLOR: vec3f = vec3(1.0, 0.7, 0.5);
const EPSILON: f32 = 0.001;
const ROTATION_RADIUS = 2.5;
const FIGURES_COUNT = 6.0;
const FIGURE_SIZE = 1.0;
const THICKNESS = 0.1;
const PI = 3.14159265359;

const RED: vec3f = vec3(1.0, 0.0, 0.0);
const ORANGE: vec3f = vec3(1.0, 0.25, 0.0);
const YELLOW: vec3f = vec3(1.0, 1.0, 0.0);
const GREEN: vec3f = vec3(0.0, 1.0, 0.0);
const BLUE: vec3f = vec3(0.0, 0.0, 1.0);
const VIOLET: vec3f = vec3(1.0, 0.0, 1.0);

struct ColoredFigure {
    distance: f32,
    color: vec3f,
};

fn sdfSphere(point: vec3f, radius: f32) -> f32 {
    return length(point) - radius;
}

fn sdfBox(point: vec3f, bound: vec3f) -> f32 {
    let distance = abs(point) - bound;
    return length(max(distance, vec3f(0.))) + min(max(distance.x, max(distance.y, distance.z)), 0.0);
}

fn sdfBoxFrame(point: vec3f, bound: vec3f, thickness: f32) -> f32 {
    let distance = abs(point)-bound;
    let frame = abs(distance+vec3(thickness))-vec3(thickness);
    return min(min(
        length(max(vec3f(distance.x, frame.y, frame.z), vec3f(0.0)))+min(max(distance.x, max(frame.y, frame.z)), 0.0),
        length(max(vec3f(frame.x, distance.y, frame.z), vec3f(0.0)))+min(max(frame.x, max(distance.y, frame.z)), 0.0)),
        length(max(vec3f(frame.x, frame.y, distance.z), vec3f(0.0)))+min(max(frame.x, max(frame.y, distance.z)), 0.0));
}

fn sdfTorus(point: vec3f, radius: f32, thickness: f32) -> f32 {
    let circle = vec2f(length(point.xz) - radius, point.y);
    return length(circle) - thickness;
}

fn sdfVerticalCylinder(point: vec3f, height: f32, radius: f32) -> f32 {
    let circle = abs(vec2f(length(point.xz), point.y)) - vec2f(radius, height);
    return min(max(circle.x, circle.y), 0.0) + length(max(circle, vec2f(0.0)));
}

fn sdfOctahedron(point: vec3f, height: f32) -> f32 {
  let side = abs(point);
  return (side.x + side.y + side.z - height);
}

// negative(inside) if point inside any figre
fn sdfUnion(figure1: ColoredFigure, figure2: ColoredFigure) -> ColoredFigure {
    if figure1.distance < figure2.distance {
        return figure1;
    } else {
        return figure2;
    }
}

// negative(inside) if point inside both figures
fn sdfIntersection(figure1: ColoredFigure, figure2: ColoredFigure) -> ColoredFigure {
    if figure1.distance > figure2.distance {
        return figure1;
    } else {
        return figure2;
    }
}

fn sdfReverse(figure: ColoredFigure) -> ColoredFigure {
    return ColoredFigure(-figure.distance, figure.color);
}

// negative(inside) if point belongs only first figure
fn sdfSubstraction(figure1: ColoredFigure, figure2: ColoredFigure) -> ColoredFigure {
    return sdfIntersection(figure1, sdfReverse(figure2));
}

// negative(inside) if point belongs only one of figures
fn sdfXor(figure1: ColoredFigure, figure2: ColoredFigure) -> ColoredFigure {
    return sdfSubstraction(sdfUnion(figure1, figure2), sdfIntersection(figure1, figure2));
}

fn sdfSmoothUnion(figure1: ColoredFigure, figure2: ColoredFigure, smoothness: f32) -> ColoredFigure {
    let factor = clamp(0.5 + 0.5 * (figure2.distance - figure1.distance) / smoothness, 0.0, 1.0);
    return ColoredFigure(mix(figure2.distance, figure1.distance, factor) - smoothness * factor * (1.0 - factor), mix(figure2.color, figure1.color, factor));
}

fn sdfSmoothSubstraction(figure1: ColoredFigure, figure2: ColoredFigure, smoothness: f32) -> ColoredFigure {
    let factor = clamp(0.5 - 0.5 * (figure2.distance - figure1.distance) / smoothness, 0.0, 1.0);
    return ColoredFigure(mix(figure2.distance, -figure1.distance, factor) + smoothness * factor * (1.0 - factor), figure1.color);
}

fn sdfSmoothIntersection(figure1: ColoredFigure, figure2: ColoredFigure, smoothness: f32) -> ColoredFigure {
    let factor = clamp(0.5 - 0.5 * (figure2.distance - figure1.distance) / smoothness, 0.0, 1.0);
    return ColoredFigure(mix(figure2.distance, figure1.distance, factor) + smoothness * factor * (1.0 - factor), mix(figure2.color, figure1.color, factor));
}

fn sdfMove(point: vec3f, difference: vec3f) -> vec3f {
    return point - difference;
}

fn figurePosition(index: i32) -> vec3f {
    var angle = sin(globals.time);
    if index % 2 == 1 {
        angle *= -1.0;
    }
    angle = PI * (angle + 1.0) / FIGURES_COUNT + 2.0 * PI * f32(index) / f32(FIGURES_COUNT);
    return vec3(ROTATION_RADIUS * sin(angle), ROTATION_RADIUS * cos(angle), 0.0);
}

fn sdfCombination(point: vec3f) -> ColoredFigure {
    return
        sdfSmoothUnion(ColoredFigure( sdfSphere(sdfMove(point, figurePosition(0)), FIGURE_SIZE), RED ),
        sdfSmoothUnion(ColoredFigure( sdfBox(sdfMove(point, figurePosition(1)), vec3(FIGURE_SIZE)), ORANGE ),
        sdfSmoothUnion(ColoredFigure( sdfTorus(sdfMove(point, figurePosition(2)), FIGURE_SIZE, THICKNESS), YELLOW ),
        sdfSmoothUnion(ColoredFigure( sdfOctahedron(sdfMove(point, figurePosition(3)), FIGURE_SIZE), GREEN ),
        sdfSmoothUnion(ColoredFigure( sdfVerticalCylinder(sdfMove(point, figurePosition(4)), FIGURE_SIZE, FIGURE_SIZE), BLUE ),
                       ColoredFigure( sdfBoxFrame(sdfMove(point, figurePosition(5)), vec3(FIGURE_SIZE), THICKNESS), VIOLET ),
        0.25), 0.25), 0.25), 0.25), 0.25);
}

fn sdfNormal(point: vec3f) -> vec3f {
    let epsilon = vec2(0.0001, 0.0);
    return normalize(vec3(sdfCombination(point + epsilon.xyy).distance - sdfCombination(point - epsilon.xyy).distance,
        sdfCombination(point + epsilon.yxy).distance - sdfCombination(point - epsilon.yxy).distance,
        sdfCombination(point + epsilon.yyx).distance - sdfCombination(point - epsilon.yyx).distance));
}

// Common algorithm for raymathcing of figure
fn processedFigure(point_on_viewport: vec3f, point_ptr: ptr<function, vec3f>, color_ptr: ptr<function, vec3f>, normal_ptr: ptr<function, vec3f>) -> bool {
    var was_on_edge = false;
    var point = point_on_viewport;
    let ray_direction = normalize(point_on_viewport - RAY_ORIGIN);
    for (var i: i32 = 0; i < STEP_COUNT && !was_on_edge && point.z > -BOX_SIZE; i += 1) {
        let figure = sdfCombination(point);
        was_on_edge |= abs(figure.distance) < EPSILON;
        point += figure.distance * ray_direction;
    }
    if was_on_edge && point.z > (*point_ptr).z {
        *point_ptr = point;
        *color_ptr = sdfCombination(point).color;
        *normal_ptr = sdfNormal(point);
        return true;
    }
    return false;
}

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = vec3(0.0); // background

    let viewport_bottom_left = vec3(-BOX_SIZE/2.0, -BOX_SIZE/2.0, BOX_SIZE/2.0);
    let viewport_top_right = vec3(BOX_SIZE/2.0, BOX_SIZE/2.0, BOX_SIZE/2.0);
    let point_on_viewport = vec3(mix(viewport_bottom_left.xy, viewport_top_right.xy, in.uv), 5.0);
    let sun_direction = normalize(viewport_top_right);

    // brute force aproach
    let ray_direction = normalize(point_on_viewport - RAY_ORIGIN);
    let step_length = BOX_SIZE / f32(STEP_COUNT) / (-ray_direction.z);
    let step = ray_direction * step_length;
    var point = point_on_viewport + step * f32(STEP_COUNT);    // Default value is back wall of box, then the most closer to raRAY_ORIGIN will override
    var figure_color = color;
    var normal = FRONT_NORMAL;
    let plane_z = sin(globals.time / 2.0);
    let collided = processedFigure(point_on_viewport, &point, &figure_color, &normal);
    if collided && point.z > plane_z {
        color = LIGHT_COLOR * saturate(dot(normal, sun_direction)) * figure_color;
    } else {
        let distance_z = point_on_viewport.z - plane_z;
        let plane_collizion_point = point_on_viewport - ray_direction * distance_z / ray_direction.z;
        let distance_to_figure = sdfCombination(plane_collizion_point);
        color = vec3f(fract(distance_to_figure.distance * 5.0));
    }

    return vec4<f32>(color, 1.0);
}
