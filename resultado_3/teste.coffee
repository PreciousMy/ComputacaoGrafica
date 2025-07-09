c = job = pipe = mat = ls = res = null

MODELO_ARQ = 'data/pacman.txt2'

phong_luzes = [
  {
    params: vec(1,0,0)
    pos: vec(4,1,2)
    Lamb: vec(0,0,0)
    Lspec: vec(1,1,1)
    Ldif: hsl_to_rgb(345,100,54)
  },
  {
    params: vec(1,0,0)
    pos: vec(-2, 4, 1)
    Lamb: rgb(0,0,0)
    Lspec: rgb(1,1,1)
    Ldif: hsl_to_rgb( 300, 99, 73 )
  },
  {
    params: vec(1,0,0)
    pos: vec(0,-2,0)
    Lamb: rgb(0,0,0)
    Lspec: rgb(1,1,1)
    Ldif: hsl_to_rgb( 271,97,47 )
  }
]

phong_material =
  Kamb: vec(0.4,0.4,0.4)
  Kdif: vec(0.7,0.7,0.7)
  Kspec: vec(1,1,1)
  shininess: 90

angulo = 0
gr = { dados_globais: null, dados_material: null, dados_instancias: null }


inicia_gui = () ->
  luz1 = phong_luzes[0]
  # posição
  document.getElementById("l1_px").value = luz1.pos.x
  document.getElementById("l1_py").value = luz1.pos.y
  document.getElementById("l1_pz").value = luz1.pos.z
  # ambiente
  document.getElementById("l1_ar").value = luz1.Lamb.x
  document.getElementById("l1_ag").value = luz1.Lamb.y
  document.getElementById("l1_ab").value = luz1.Lamb.z
  # difusa
  document.getElementById("l1_dr").value = luz1.Ldif.x
  document.getElementById("l1_dg").value = luz1.Ldif.y
  document.getElementById("l1_db").value = luz1.Ldif.z
  # especular
  document.getElementById("l1_sr").value = luz1.Lspec.x
  document.getElementById("l1_sg").value = luz1.Lspec.y
  document.getElementById("l1_sb").value = luz1.Lspec.z

main = () =>
  c = await wgpu_context_new canvas:'tela', debug:true
  c.frame_buffer_format 'color', 'depth'
  c.vertex_format 'xyz', 'rgba', 'normal', 'uv'
  mat = c.use_mat4x4_format()

  res = c.resources_from_files(
    'shader_phong.wgsl',
    MODELO_ARQ
  )
  await res.load_all()

  prepara_pipelines()
  prepara_shader_groups()
  prepara_instancias()
  
  inicia_gui() 

  job = c.job()
  renderiza()

prepara_pipelines = () ->
  pipe = c.pipeline()
  pipe.begin( 'triangles' )
  pipe.shader_from_src( res.text('shader_phong.wgsl') )
  pipe.depth_test( true )
  pipe.expect_group(0).binding(0).uniform()
  pipe.expect_group(1).binding(0).uniform()
  pipe.expect_group(2).binding(0).uniform_list()
  pipe.end()

prepara_shader_groups = () ->

  # grupo dos dados globais
  #
  gr.dados_globais = c.shader_data_group_with_uniform()
  u = gr.dados_globais.binding(0).get_uniform()
  u.begin()
  u.mat4x4('view')
  u.mat4x4('proj')
  u.vec2('screen_size')
  u.vec3('camera_pos')
  u.array_vec3('light_params', 3)
  u.array_vec3('light_pos', 3)
  u.array_vec3('Lamb', 3)
  u.array_vec3('Ldif', 3)
  u.array_vec3('Lspec', 3)
  u.end()

  u.proj = mat.perspective(50, c.canvas.width/c.canvas.height, 0.1, 100)
  u.view = mat.identity()

  u.screen_size = vec(c.canvas.width, c.canvas.height)
  u.camera_pos = vec(0,0,5)

  # grupo de dados do material
  #
  gr.dados_material = c.shader_data_group_with_uniform()
  u = gr.dados_material.binding(0).get_uniform()
  u.begin()
  u.vec3('Kamb')
  u.vec3('Kdif')
  u.vec3('Kspec')
  u.float('shininess')
  u.end()

  u.Kamb      = phong_material.Kamb
  u.Kdif      = phong_material.Kdif
  u.Kspec     = phong_material.Kspec
  u.shininess = phong_material.shininess

  u.gpu_send()
  
  # grupo de dados para as matrizes/posicoes de cada
  # instancia. no caso, aqui a gente aloca logo
  # um uniform list suficiente pra varias instancias.
  #
  # mas nessa implementação aqui só usaremos 1 instancia :)
  #
  gr.dados_instancias = c.shader_data_group_with_uniform_list(100)

  u = gr.dados_instancias.binding(0).get_uniform_list()
  u.begin()
  u.mat4x4('model')
  u.end()

prepara_instancias = () ->
  ls = c.instance_list()

  # para renderizar as instancias, usaremos
  # o grupo global no slot 0 da gpu,
  # o grupo de material no slot 1
  # e o grupo das matrizes de cada instancia
  # no slot 2.
  #
  ls.use_groups(
    global_index:   0, global_group: gr.dados_globais,
    material_index: 1,
    instance_index: 2, instance_group: gr.dados_instancias
  )

  # dos objetos que carregamos, pega o primeiro.
  # só carregamos um mesmo
  obj = res.obj_by_index(0)

  # cria uma instancia pra esse objeto, usando
  # tal pipeline e tal material.
  # e define um campo de posicao pra essa instancia.
  #
  inst = ls.instance( obj, pipeline:pipe, material:gr.dados_material )
  inst.pos = vec(0,0,0)

renderiza = () ->
  u_global = gr.dados_globais.binding(0).get_uniform()

  # luz 1
  u_global.light_params[0] = vec(1,0,0)
  px = parseFloat(document.getElementById("l1_px").value)
  py = parseFloat(document.getElementById("l1_py").value)
  pz = parseFloat(document.getElementById("l1_pz").value)
  u_global.light_pos[0] = vec(px,py,pz)
  u_global.Lamb[0] = vec(parseFloat(document.getElementById("l1_ar").value), parseFloat(document.getElementById("l1_ag").value), parseFloat(document.getElementById("l1_ab").value))
  u_global.Ldif[0] = vec(parseFloat(document.getElementById("l1_dr").value), parseFloat(document.getElementById("l1_dg").value), parseFloat(document.getElementById("l1_db").value))
  u_global.Lspec[0] = vec(parseFloat(document.getElementById("l1_sr").value), parseFloat(document.getElementById("l1_sg").value), parseFloat(document.getElementById("l1_sb").value))

  # luz 2 e 3
  for i in [1..2]
    luz = phong_luzes[i]
    u_global.light_params[i] = vec(1,0,0)
    u_global.light_pos[i] = luz.pos
    u_global.Lamb[i] = luz.Lamb
    u_global.Ldif[i] = luz.Ldif
    u_global.Lspec[i] = luz.Lspec

  # atualiza matriz 
  for inst in ls.instances()
    R = mat.rotate(angulo, 0,1,0)
    T1 = mat.translate( inst.pos.x, inst.pos.y, inst.pos.z )
    T2 = mat.translate( 0,0,-4 )
    u_inst = inst.get_uniform_data()
    u_inst.model = mat.mul T2, T1, R
  angulo += 1

  gr.dados_globais.gpu_send()
  gr.dados_instancias.gpu_send()

  job.render_begin()
  job.render_instance_list(ls)
  job.render_end()
  job.gpu_send()

  c.animation_repeat renderiza, 20

main()
