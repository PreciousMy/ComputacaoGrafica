c = pipeline = triangulo = job = gr = mat = null

gui =
  vertice: document.getElementById('vertice')
  angulo: document.getElementById('angulo')


inicializa = () =>
  c = await wgpu_context_new canvas:'tela', transparent:true
  c.vertex_format 'xy', 'rgba'
  mat = c.use_mat3x3_format()

  gr = c.shader_data_group()
  u = gr.binding(0).uniform()
  u.begin()
  u.mat3x3('matriz')
  u.end()
  u.matriz = mat.identity()

  triangulo = c.obj()
  triangulo.begin()
  triangulo.vert(0.0,0.0, 1,0,0,1)
  triangulo.vert(0.5,0.0, 0,1,0,1)
  triangulo.vert(0.5,0.5, 0,0,1,1)
  triangulo.end()
  
  pipeline = c.pipeline()
  pipeline.begin( 'triangles' )
  await pipeline.shader_from_file 'simples_mat.wgsl'
  pipeline.expect_group(0).binding(0).uniform()
  pipeline.end()

  job = c.job()
  renderiza()

  gui.vertice.addEventListener( 'change', atualiza )
  gui.angulo.addEventListener( 'change', atualiza )



renderiza = () =>

  vi = parseInt( gui.vertice.value )
  angulo = parseFloat( gui.angulo.value )

  switch vi
    when 0
      v = vec(0.0,0.0)
    when 1
      v = vec(0.5,0.0)
    when 2
      v = vec(0.5,0.5)

  T1 = mat.translate(-v.x, -v.y)
  R = mat.rotate(angulo)
  T2 = mat.translate(v.x, v.y)

  u = gr.binding(0).get_uniform()
  u.matriz = mat.mul T2,R,T1
  u.gpu_send()

  job.render_begin()
  job.render_use_group(0, gr)
  job.render_objs( pipeline, [triangulo] )
  job.render_end()
  job.gpu_send()


atualiza = () ->
  renderiza()

inicializa()