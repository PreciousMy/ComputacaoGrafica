struct GlobalUniforms {
    view: mat4x4<f32>,
    proj: mat4x4<f32>,

    screen_size: vec2<f32>,
    camera_pos: vec3<f32>,
    

    light_params: array< vec3<f32>, 3 >,
    light_pos:    array< vec3<f32>, 3 >,

    Lamb:         array< vec3<f32>, 3 >,
    Ldif:         array< vec3<f32>, 3 >,
    Lspec:        array< vec3<f32>, 3 >,
};
@group(0) @binding(0) var<uniform> globalUniforms: GlobalUniforms;


struct MaterialUniforms {
    Kamb:       vec3<f32>,
    Kdif:       vec3<f32>,
    Kspec:      vec3<f32>,
    shininess:  f32,
}
@group(1) @binding(0) var<uniform> materialUniforms: MaterialUniforms;


struct InstanceUniforms {
    model: mat4x4<f32>,
};
@group(2) @binding(0) var<uniform> instanceUniforms: InstanceUniforms;



struct VertexIn {
    @location(0) pos: vec3<f32>,
    @location(1) color: vec4<f32>,
    @location(2) normal: vec3<f32>,
}

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) @interpolate(flat) normal: vec3<f32>,
    @location(2) @interpolate(flat) world_pos: vec3<f32>,
}


@vertex
fn vs_main(input: VertexIn) -> VertexOut {
    var output: VertexOut;

    let p = vec4<f32>( input.pos, 1 );
    let v = globalUniforms.proj * globalUniforms.view * instanceUniforms.model * p;

    output.pos = v;
    output.color = input.color;

    output.normal = normalize( (instanceUniforms.model * vec4<f32>(input.normal, 0.0)).xyz );
    output.world_pos = (instanceUniforms.model * p).xyz;
    return output;
}


struct FragmentIn {
    @location(0) color: vec4<f32>,
    @location(1) @interpolate(flat) normal: vec3<f32>,
    @location(2) @interpolate(flat) world_pos: vec3<f32>,
}

struct FragmentOut {
    @location(0) color: vec4<f32>
};

@fragment
fn fs_main(input: FragmentIn) -> FragmentOut {
    var out: FragmentOut;

    let global   = globalUniforms;
    let material = materialUniforms;

    var total = vec3<f32>(0,0,0);

    for (var i = 0; i < 3; i++) {

        // a gente permite um parâmetro para "desligar"
        // a luz (i), ou seja, simplesmente pularia ela.
        if ( global.light_params[i].x == 0.0 ) {
            continue;
        }

        let light_pos = global.light_pos[i].xyz;
        let camera_pos = global.camera_pos.xyz;
        let shininess = material.shininess;

        let N = normalize(input.normal);
        let L = normalize(light_pos - input.world_pos);
        let R = reflect(-L, N);
        let V = normalize(camera_pos - input.world_pos);

        let fator_dif  = max(0,dot(N, L));
        let fator_spec = pow(max(0,dot(R,V)), shininess);

        let amb  =              global.Lamb[i]  * material.Kamb;
        let dif  = fator_dif  * global.Ldif[i]  * material.Kdif;
        let spec = fator_spec * global.Lspec[i] * material.Kspec;

        total += amb + dif + spec;
    }

    out.color = vec4<f32>(total.rgb, 1.0);
    return out;
}
