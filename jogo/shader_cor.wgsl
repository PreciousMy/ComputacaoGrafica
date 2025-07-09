struct GlobalUniforms {
    view: mat4x4<f32>,
    proj: mat4x4<f32>
};
@group(0) @binding(0) var<uniform> globalUniforms: GlobalUniforms;

struct LocalUniforms {
    model: mat4x4<f32>,
};
@group(2) @binding(0) var<uniform> localUniforms: LocalUniforms;



struct VertexIn {
    @location(0) pos: vec3<f32>,
    @location(1) color: vec4<f32>
}

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>
}

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
    var output: VertexOut;

    let p = vec4<f32>( input.pos, 1 );
    let v = globalUniforms.proj * globalUniforms.view * localUniforms.model * p;

    output.pos = v;
    output.color = input.color;
    return output;
}





struct FragmentIn {
    @location(0) color: vec4<f32>
}

struct FragmentOut {
    @location(0) color: vec4<f32>
};

@fragment
fn fs_main(input: FragmentIn) -> FragmentOut {
    var out: FragmentOut;
    out.color = input.color;
    return out;
}