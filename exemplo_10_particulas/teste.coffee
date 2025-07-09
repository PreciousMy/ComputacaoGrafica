c = job = pipe_tex = pipe_tex_additive = mat = ls = res = ps = null

gr =
  global: null
  material_list: []
  instancias: null
  

main = () =>
  c = await wgpu_context_new canvas:'tela', debug:false, transparent:true
  c.frame_buffer_format 'color', 'depth'
  c.vertex_format 'xyz', 'rgba', 'uv'
  mat = c.use_mat4x4_format()

  res = c.resources_from_files(
    'shader_tex.wgsl',
    'data/pp[01-46].png'
  )
  await res.load_all()

  prepara_pipelines()
  prepara_shader_groups()
  prepara_instancias()

  prepara_html()
  upd()

  job = c.job()
  renderiza()




prepara_pipelines = () ->
  pipe_tex = c.pipeline()
  pipe_tex.label('pipe_tex')
  pipe_tex.begin( 'triangles' )
  pipe_tex.shader_from_src( res.text('shader_tex.wgsl') )
  pipe_tex.depth_test( true )
  pipe_tex.depth_write( false )
  pipe_tex.blend_mode( 'default' )
  pipe_tex.expect_group(0).binding(0).uniform()
  pipe_tex.expect_group(1).binding(0).tex()
  pipe_tex.expect_group(1).binding(1).tex_sampler()
  pipe_tex.expect_group(2).binding(0).uniform_list()
  pipe_tex.end()

  pipe_tex_additive = c.pipeline()
  pipe_tex_additive.label('pipe_tex_additive')
  pipe_tex_additive.begin( 'triangles' )
  pipe_tex_additive.copy_from( pipe_tex )
  pipe_tex_additive.blend_mode( 'additive' )
  pipe_tex_additive.end()


prepara_shader_groups = () ->
  gr.global = c.shader_data_group()
  gr.global.binding(0).uniform()

  gr.instancias = c.shader_data_group()
  gr.instancias.binding(0).uniform_list(100)


  gr.material_list = []
  gr.material_list = res.materials_from_tex_list()
  
  u = gr.global.binding(0).get_uniform()
  u.begin()
  u.mat4x4('view')
  u.mat4x4('proj')
  u.end()

  u.proj = mat.perspective(50, c.canvas.width/c.canvas.height, 0.1, 100)
  u.view = mat.identity()
  u.gpu_send()


  u = gr.instancias.binding(0).get_uniform_list()
  u.begin()
  u.mat4x4('model')
  u.vec4('color')
  u.vec4i('color_params')
  u.end()



prepara_instancias = () ->
  ls = c.instance_list()
  ls.use_groups(
    global_index:   0, global_group: gr.global,
    material_index: 1,
    instance_index: 2, instance_group: gr.instancias
  )

  ps = c.particle_system( )
  define_pipeline_material_das_particulas()



prepara_html = () ->
  s = ''
  for m in gr.material_list
    s += '<option>' + m.url + '</option>' + '\n'
  document.getElementById('mt').innerHTML = s

  s = ''
  for cmap_nome in get_colormap_list()
    s += '<option>' + cmap_nome + '</option>'
  document.getElementById('cores').innerHTML = s



renderiza = () ->

  document.getElementById('n_agora').innerHTML = ps.particles.length

  color_params = vec(0,0,0,0)
  color_params.x = parseInt( document.getElementById('color_param_x').value )
  color_params.y = parseInt( document.getElementById('color_param_y').value )

  for inst in ls.instances()
    u = inst.get_uniform_data()
    u.model = mat.identity()

    if inst.get_class() == ps.particle_class
      u.model.apply_rotate( inst.ang, 0,0,1 )
      u.model.apply_scale( inst.size )
      #console.log('inst:')
      #console.log inst
      #console.log('inst.pos:')
      #console.log inst.pos 
      #console.log inst.pos.x
      u.model.apply_translate( inst.pos )
      u.color = inst.color
      #u.color_params = vec(1,0,0,1)
      u.color_params = color_params

    u.model.apply_translate(0,0,-4)

  gr.instancias.gpu_send()

  job.render_begin()
  job.render_instance_list ls
  job.render_end()
  job.gpu_send()

  c.animation_repeat renderiza, 20


emitir = () ->
  ps.dump()
  ps.emit()
  return


define_pipeline_material_das_particulas = () ->
  if document.getElementById('blend_mode').value == 'default'
    pip = pipe_tex
  else
    pip = pipe_tex_additive
  ps.set_all_pipeline( pip )

  url = document.getElementById('mt').value
  mt = gr.material_list.get_by_url(url)
  ps.set_all_material( mt )



upd = () ->
  define_pipeline_material_das_particulas()

  cfg = ps.get_config()
  cfg.is_emitting = document.getElementById('emitindo').checked

  cfg.pos_start = vec(
    parseFloat( document.getElementById('pos_x').value ),
    parseFloat( document.getElementById('pos_y').value ),
    parseFloat( document.getElementById('pos_z').value )
  )
  cfg.vel_start = vec(
    parseFloat( document.getElementById('vel_x').value ),
    parseFloat( document.getElementById('vel_y').value ),
    parseFloat( document.getElementById('vel_z').value )
  )

  cfg.max_particles = parseInt( document.getElementById('max_particles').value )
  cfg.speed = parseFloat( document.getElementById('speed').value )
  cfg.emission_rate = parseInt( document.getElementById('emission_rate').value )
  cfg.vel_variation = parseFloat( document.getElementById('vel_variation').value )
  cfg.turbulence_strength = parseFloat( document.getElementById('turbulence_strength').value )
  cfg.attraction_repulsion_strength = parseFloat( document.getElementById('attraction_repulsion_strength').value )

  cfg.default_per_particle.vel_factor = parseFloat( document.getElementById('vel_factor').value )            
  cfg.default_per_particle.size_start = parseFloat( document.getElementById('size_start').value )
  cfg.default_per_particle.size_end = parseFloat( document.getElementById('size_end').value )

  cfg.default_per_particle.age_min = parseFloat( document.getElementById('age_min').value )
  cfg.default_per_particle.age_max = parseFloat( document.getElementById('age_max').value )

  cfg.default_per_particle.ang_start_random = parseFloat( document.getElementById('ang_start_random').value )
  cfg.default_per_particle.ang_vel_random = parseFloat( document.getElementById('ang_vel_random').value )

  cmap_nome = document.getElementById('cores').value
  reverte = document.getElementById('cores_reverso').checked
  cmap = colormap(cmap_nome, reverse:reverte)  
  cfg.default_per_particle.color_list = cmap

  s = ''
  for rgb in cmap
    hex = rgb_to_hex( rgb )
    s += '<div style="background:'+hex+'"></div>'
  document.getElementById('cores_pal').innerHTML = s


tema = (k) ->
  if k == 0
    document.getElementById('tela').style.background = 'linear-gradient(rgb(255,255,255), rgb(255,255,255))'
  else if k == 1
    document.getElementById('tela').style.background = 'linear-gradient(rgb(0,0,0), rgb(0,0,0))'
  else
    document.getElementById('tela').style.background = 'linear-gradient(rgb(150, 133, 183), rgb(69, 58, 60))'


main()