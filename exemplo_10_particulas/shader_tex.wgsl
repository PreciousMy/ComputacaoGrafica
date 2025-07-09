struct GlobalUniforms {
    view: mat4x4<f32>,
    proj: mat4x4<f32>
};
@group(0) @binding(0) var<uniform> globalUniforms: GlobalUniforms;

struct InstanceUniforms {
    model: mat4x4<f32>,
    color: vec4<f32>,
    color_params: vec4<i32>
};
@group(2) @binding(0) var<uniform> instanceUniforms: InstanceUniforms;



struct VertexIn {
    @location(0) pos: vec3<f32>,
    @location(1) color: vec4<f32>,
    @location(2) uv: vec2<f32>
}

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>
}

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
    var output: VertexOut;

    let p = vec4<f32>( input.pos, 1 );
    let v = globalUniforms.proj * globalUniforms.view * instanceUniforms.model * p;

    output.pos = v;
    output.color = input.color;
    output.uv = input.uv;
    return output;
}





struct FragmentIn {
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>
}

struct FragmentOut {
    @location(0) color: vec4<f32>
};

@group(1) @binding(0) var tex: texture_2d<f32>;
@group(1) @binding(1) var tex_sampler: sampler;

@fragment
fn fs_main(input: FragmentIn) -> FragmentOut {
    var out: FragmentOut;

    let tex_color = textureSample(tex, tex_sampler, input.uv);

    let modo_cor = instanceUniforms.color_params.x;
    let modo_alpha = instanceUniforms.color_params.y;

    var cor: vec3<f32>;
    var alpha: f32;

    switch (modo_cor) {
        case 0: {
            cor = input.color.rgb;
        }
        case 1: {
            cor = tex_color.rgb;
        }
        case 2: {
            cor = instanceUniforms.color.rgb;
        }
        case 3: {
            cor = input.color.rgb * instanceUniforms.color.rgb;
        }
        case 4: {
            cor = tex_color.rgb * instanceUniforms.color.rgb;
        }
        case 5: {
            cor = tex_color.rgb * input.color.rgb;
        }
        case 6: {
            cor = input.color.rgb + instanceUniforms.color.rgb;
        }
        case 7: {
            cor = tex_color.rgb + instanceUniforms.color.rgb;
        }
        case 8: {
            cor = tex_color.rgb + input.color.rgb;
        }
        default: {
            cor = vec3<f32>(1.0, 1.0, 1.0);
        }
    }

    switch (modo_alpha) {
        case 0: {
            alpha = input.color.a;
        }
        case 1: {
            alpha = tex_color.a;
        }
        case 2: {
            alpha = instanceUniforms.color.a;
        }
        case 3: {
            alpha = input.color.a * instanceUniforms.color.a;
        }
        case 4: {
            alpha = tex_color.a * instanceUniforms.color.a;
        }
        case 5: {
            alpha = tex_color.a * input.color.a;
        }
        case 6: {
            alpha = input.color.a + instanceUniforms.color.a;
        }
        case 7: {
            alpha = tex_color.a + instanceUniforms.color.a;
        }
        case 8: {
            alpha = tex_color.a + input.color.a;
        }
        case 9: {
            alpha = tex_color.r;
        }
        case 10: {
            alpha = (tex_color.r + tex_color.g + tex_color.b ) / 3.0;
        }
        default: {
            alpha = 1.0;
        }
    }

    out.color = vec4<f32>( cor, alpha );

    return out;
}