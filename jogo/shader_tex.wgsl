struct GlobalUniforms {
    view: mat4x4<f32>,
    proj: mat4x4<f32>
};
@group(0) @binding(0) var<uniform> globalUniforms: GlobalUniforms;

struct InstanceUniforms {
    model: mat4x4<f32>,
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

    out.color = textureSample(tex, tex_sampler, input.uv);
    //out.color *= input.color;

    return out;
}