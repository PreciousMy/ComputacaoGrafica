multiplayer_info =
  ativado: true
  porta: ':3000'
  socket: null
  meu_id: ''
  jogadores: {}
  inst_dos_jogadores: {}


multiplayer_connect_to_server = (servidor) ->
  if not multiplayer_info.ativado then return

  url = 'ws://' + servidor + multiplayer_info.porta  
  multiplayer_info.socket = new WebSocket(url)
  
  multiplayer_info.socket.onopen = () ->
    console.log '--- Conectado ao servidor'

  multiplayer_info.socket.onclose = ->
    console.log '--- Desconectado do servidor'

  multiplayer_info.socket.onmessage = (event) ->
    #console.log "-- Recebeu msg: '#{event.data}'"

    msg_recebida = JSON.parse(event.data)

    switch msg_recebida.assunto

      when 'seu novo id'
        meu_novo_id = msg_recebida.conteudo.id
        console.log "--- ID atribuído pelo servidor: #{meu_novo_id}"

        multiplayer_info.meu_id = meu_novo_id
        document.title = "Jogador: " + meu_novo_id


      when 'jogador entrou'
        jogador_id = msg_recebida.conteudo.id

        console.log "--- Jogador entrou - id: #{jogador_id}"

        # recebemos o aviso que entrou um jogador.
        # vamos criar uma instância pra ele e
        # aguardar a atualização do estado para
        # determinar a posição da instância, etc.
        #
        inst = ls.instance( res.obj(arqs.nave), pipeline:pipe_cor )
        multiplayer_info.inst_dos_jogadores[ jogador_id ] = inst

        inst.set_class( 'multiplayer-nave' )
        inst.pos = vec(0,0,0)
        inst.ang = 0


      when 'jogador saiu'
        jogador_id = msg_recebida.conteudo.id
        console.log "--- Jogador saiu - id: #{jogador_id}"

        # um jogador saiu. vamos remover a instância dele.
        multiplayer_info.inst_dos_jogadores[ jogador_id ].remove()
        delete multiplayer_info.inst_dos_jogadores[jogador_id]


      when 'estado atual de todos'
        multiplayer_info.jogadores = msg_recebida.conteudo.jogadores

        # recebemos o estado geral da partida,
        # contendo os dados de todos os jogadores.
        #
        for jogador in multiplayer_info.jogadores

          # recebemos até o nosso próprio dado,
          # mas vamos ignorar ele.
          if jogador.id == multiplayer_info.meu_id
            continue

          conteudo = jogador.conteudo
          inst = multiplayer_info.inst_dos_jogadores[ jogador.id ]
          inst.pos = vec_from_array( conteudo.pos )
          inst.ang = conteudo.ang


multiplayer_send_to_server = () ->
  if not multiplayer_info.ativado then return
     
  if multiplayer_info.socket?.readyState == WebSocket.OPEN
    
    # envia meus dados para o servidor. o que eu enviar
    # é o que eu recebo dos outros tb.
    #
    msg = JSON.stringify(
      assunto: 'enviando meu estado'
      conteudo:
        pos: vec_to_array( nave.pos )
        ang: nave.ang
    )
    multiplayer_info.socket.send msg


c = pipe_cor = pipe_tex = job = mat = res = ls = null

gr =
  dados_globais: null
  dados_materiais: []
  dados_instancias: null

arqs =
  nave: 'data/nave_metal.ply'
  asteroide: 'data/asteroide_gelo.ply'


#sons
som_tiro = null
som_explosao = null
som_explosao_nave = null
musica_fundo = null

musica_iniciada = false 

# --- Controle de Spawn de Asteroides ---
contador_spawn_asteroide = 0
intervalo_spawn_asteroide = 60 # Spawn a cada 120 frames (aprox. 2 segundos a 60fps)
max_asteroides = 15             # Número máximo de asteroides na tela
# ------------------------------------

#posicao inicial
pos_inicial_nave = null

nave = null
obj_quad = null
teclas = {}

#posicao

main = () =>
  c = await wgpu_context_new canvas:'tela', debug:true, transparent:true
  c.frame_buffer_format 'color', 'depth'
  c.vertex_format 'xyz', 'rgba', 'uv'
  mat = c.use_mat4x4_format()

  await carrega_dados()
  prepara_shader_data_groups()
  prepara_pipelines()
  prepara_instancias()
  prepara_teclado_eventos()
  #multiplayer
  multiplayer_connect_to_server( '10.80.60.124' )
  job = c.job()
  renderiza()


carrega_dados = () ->  
  musica_fundo = new Audio('data/sons/musica_fundo_doom.mp3')
  som_tiro = new Audio('data/sons/tiro.mp3')
  som_explosao = new Audio('data/sons/explosao_asteroide5.mp3')  
  som_explosao_nave = new Audio('data/sons/nave_explodindo.mp3')
  res = c.resources_from_files(
    arqs.nave, arqs.asteroide,
    'data/tiro_doom.png',
    'data/sprites/sp[1-4].png',
    'data/explosao1/explosao[0-6].png',
    'data/explosao2/explosao[0-7].png',
    'data/explosao3/explosao[0-5].png',
    'shader_cor.wgsl', 'shader_tex.wgsl'
  )
  await res.load_all()


prepara_shader_data_groups = () ->
  gr.dados_globais = c.shader_data_group_with_uniform()
  u = gr.dados_globais.binding(0).get_uniform()
  u.begin()
  u.mat4x4('view')
  u.mat4x4('proj')
  u.end()

  u.proj = mat.perspective(50, c.canvas.width/c.canvas.height, 0.1, 10)
  u.view = mat.look_at( vec(0,0,8), vec(0,0,0), vec(0,1,0) )
  u.gpu_send()

  gr.dados_materiais = res.materials_from_tex_list()

  gr.dados_instancias = c.shader_data_group_with_uniform_list(300)
  u = gr.dados_instancias.binding(0).get_uniform_list()
  u.begin()
  u.mat4x4('model')
  u.end()

prepara_pipelines = () ->
  pipe_cor = c.pipeline()
  pipe_cor.begin( 'triangles' )
  pipe_cor.shader_from_src( res.text('shader_cor.wgsl') )
  pipe_cor.depth_test( true )
  pipe_cor.expect_group(0).binding(0).uniform()
  pipe_cor.expect_group(2).binding(0).uniform_list()
  pipe_cor.end()

  pipe_tex = c.pipeline()
  pipe_tex.begin( 'triangles' )
  pipe_tex.shader_from_src( res.text('shader_tex.wgsl') )
  pipe_tex.depth_test( true )
  pipe_tex.depth_write(false)
  pipe_tex.expect_group(0).binding(0).uniform()
  pipe_tex.expect_group(1).binding(0).tex()
  pipe_tex.expect_group(1).binding(1).tex_sampler()
  pipe_tex.expect_group(2).binding(0).uniform_list()
  pipe_tex.end()

prepara_instancias = () ->
  vdata = [
    -0.5,-0.5,0.0, 1.0,0.0,0.0,1.0, 0.0,1.0,
    +0.5,-0.5,0.0, 0.0,1.0,0.0,1.0, 1.0,1.0,
    +0.5,+0.5,0.0, 0.0,0.0,1.0,1.0, 1.0,0.0,
    -0.5,+0.5,0.0, 1.0,1.0,0.0,1.0, 0.0,0.0 ]
  indices = [0,1,2, 2,3,0]
  obj_quad = c.obj_from_data( vdata, indices )


  ls = c.instance_list()
  ls.use_groups(
    global_index:   0, global_group: gr.dados_globais,
    material_index: 1,
    instance_index: 2, instance_group: gr.dados_instancias
  )
  pos_inicial_nave = vec(3,-2,0)
  nave = cria_nave( vec( 3,-2,0 ) )
  cria_asteroide( vec( -4,2,0 ) )

# Função para limpar a fase e recriar a nave
reset_game = () ->
  # Pega uma cópia da lista de todos os asteroides atuais
  instancias_a_remover = ls.get_instances_by_class('asteroide').slice()
  # Remove um por um
  for ast in instancias_a_remover
    ast.remove()

  # Cria a nave novamente na sua posição original
  nave = cria_nave( pos_inicial_nave )

cria_nave = (pos) ->
  inst = ls.instance( res.obj(arqs.nave), pipeline:pipe_cor )
  inst.set_class( 'nave' )
  inst.pos = pos
  inst.vel = vec( 0,0,0 )
  inst.ang = 0
  inst.frente = vec( 0,1,0 )
  return inst

cria_asteroide = (pos) ->
  min_pos = vec( -3,-3, 0 )
  max_pos = vec( +3,+3, 0 )
  v_min=vec(-1, -1, 0)
  v_max=vec(+1, +1,0)
  if not pos?
    pos = vec_random( min_pos, max_pos )
  ast = ls.instance( res.obj(arqs.asteroide), pipeline:pipe_cor )
  ast.set_class( 'asteroide' )
  ast.pos = pos
  ast.vel =vec_random(v_min,v_max).mul_by_scalar(0.1)
  ast.ang = random(90)
  ast.size = 0.5
  return ast

cria_tiro = (nave) ->

  if som_tiro?
    som_tiro.currentTime = 0
    som_tiro.volume = 0.1 # volume do som
    som_tiro.play()          # Toca o som

  inst = ls.instance( obj_quad, pipeline:pipe_tex, material:gr.dados_materiais[0] )
  inst.set_class( 'tiro' )
  inst.pos = nave.pos
  inst.vel = nave.frente
  inst.ang = 0
  
  
cria_explosao = (pos) ->

  if som_explosao?
    som_explosao.currentTime = 0
    som_explosao.volume = 0.2 # volume do som
    som_explosao.play() 

  inst = ls.instance( obj_quad, pipeline:pipe_tex )
  inst.set_class( 'explosao' )
  inst.pos = pos
  inst.size = 2.0
  inst.start_animation_from_materials(
    'data/explosao3/explosao[0-5].png',
    gr.dados_materiais,
    on_animation_end: (inst) ->
      inst.remove()
  )

cria_explosao_nave = (pos) ->

  if som_explosao_nave?
    som_explosao_nave.currentTime = 0
    som_explosao_nave.volume = 0.5 # volume do som
    som_explosao_nave.play()

  inst = ls.instance( obj_quad, pipeline:pipe_tex )
  inst.set_class( 'explosao' )
  inst.pos = pos
  inst.size = 2.0
  inst.start_animation_from_materials(
    'data/explosao3/explosao[0-5].png',
    gr.dados_materiais,
    on_animation_end: (inst) ->
      inst.remove()
  )
  
cria_coisa = (pos) ->
  min_pos = vec( -3,-3, 0 )
  max_pos = vec( +3,+3, 0 )
  v_min=vec(-1, -1, 0)
  v_max=vec(+1, +1,0)
  if not pos?
    pos = vec_random( min_pos, max_pos )
  url = res.get_url_group_random_item('data/sprites/sp[1-4].png')
  mt = gr.dados_materiais.get_by_url(url) 
  coisa = ls.instance( obj_quad, pipeline:pipe_tex, material:mt )
  coisa.set_class( 'coisa' )
  coisa.pos = pos
  coisa.vel =vec_random(v_min,v_max).mul_by_scalar(0.1)
  coisa.size = 1.0
  return coisa

prepara_teclado_eventos = () ->
  document.addEventListener 'keydown', on_keydown
  document.addEventListener 'keyup', on_keyup

on_keydown = (event) ->
  if not musica_iniciada and musica_fundo?
    musica_fundo.loop = true    # Para que a música repita
    musica_fundo.volume = 0.3   
    musica_fundo.play()
    musica_iniciada = true

  if event.key == ' ' then event.preventDefault()
  if not teclas[ event.key ]?
    teclas[ event.key ] = 1
  else
    teclas[ event.key ]++

on_keyup = (event) ->
  teclas[ event.key ] = 0

apertando_tecla = (key) ->
  return teclas[ key ] >= 1

apertou_tecla = (key) ->
  apertou = teclas[ key ] == 1
  if apertou
    teclas[ key ] = 2

renderiza = () ->
  processa_movimento()
  atualiza_uniforms()
  job.render_begin()
  job.render_instance_list( ls )
  job.render_end()
  job.gpu_send()
  c.animation_repeat renderiza, 10

ajusta_posicao_wrap = (objeto, limite_x, limite_y) ->
  if objeto.pos.x > limite_x then objeto.pos.x = -limite_x
  else if objeto.pos.x < -limite_x then objeto.pos.x = limite_x
  if objeto.pos.y > limite_y then objeto.pos.y = -limite_y
  else if objeto.pos.y < -limite_y then objeto.pos.y = limite_y

processa_movimento = () ->
  limite_x = 6.5
  limite_y = 4.0
  fator = 0.1

  asteroides = ls.get_instances_by_class( 'asteroide' )
  for ast in asteroides
    ast.pos = ast.pos.add( ast.vel.mul_by_scalar(fator) )
    ajusta_posicao_wrap(ast, limite_x, limite_y)
    
  tiros = ls.get_instances_by_class( 'tiro' )
  for tiro in tiros
    tiro.pos = tiro.pos.add(tiro.vel.mul_by_scalar(0.1))
    # verifica se o tiro saiu da tela
    # se sim, remove o tiro
    if tiro.pos.x > limite_x or tiro.pos.x < -limite_x or tiro.pos.y > limite_y or tiro.pos.y < -limite_y
      tiro.remove()
  
  

  coisas = ls.get_instances_by_class( 'coisa' )
  for coisa in coisas
    coisa.pos = coisa.pos.add( coisa.vel.mul_by_scalar(fator) )

  if nave?
    ang_inc = 3
    y_inc = 0
    if teclas['ArrowUp'] >= 1
      y_inc = 1
    else if teclas['ArrowDown'] >= 1
      y_inc = -1
    if apertando_tecla( 'ArrowLeft' ) 
      nave.ang += ang_inc
    else if apertando_tecla( 'ArrowRight' )
      nave.ang -= ang_inc
    if apertou_tecla( ' ' ) 
      cria_tiro( nave )
    if apertou_tecla( 'a' )
      cria_asteroide()
    if apertou_tecla( 'c' )
      cria_coisa()
    if apertou_tecla( 'e' )
      cria_explosao(vec_random())
          
    v = vec(0,1,0)
    R = mat.rotate nave.ang
    nave.frente = mat_mul R, v
    if y_inc != 0
      nave.vel = nave.vel.add( nave.frente.mul_by_scalar(fator*y_inc) )
    nave.pos = nave.pos.add( nave.vel.mul_by_scalar(fator) )
    nave.vel = nave.vel.mul_by_scalar( 0.95 )
    ajusta_posicao_wrap(nave, limite_x, limite_y)

  # --- LÓGICA DE COLISÃO ---
  tiros = ls.get_instances_by_class('tiro')
  asteroides = ls.get_instances_by_class('asteroide')
  for tiro in tiros
    for ast in asteroides
      raio_tiro = 0.5
      raio_ast = ast.size
      
      # --- CÁLCULO MANUAL DA DISTÂNCIA AO QUADRADO ---
      dx = tiro.pos.x - ast.pos.x
      dy = tiro.pos.y - ast.pos.y
      dist_sqr = (dx * dx) + (dy * dy)
      
      soma_raios_sqr = (raio_tiro + raio_ast) ** 2
      
      if dist_sqr < soma_raios_sqr
        cria_explosao(ast.pos)
        tiro.remove()
        ast.remove()
        break
  
  # --- LÓGICA DE COLISÃO ENTRE NAVE E ASTEROIDES ---
  if nave? # Só executa se a nave existir
    # Pega a lista de asteroides novamente, pois ela pode ter sido modificada pelos tiros
    asteroides = ls.get_instances_by_class('asteroide')
    for ast in asteroides
      raio_nave = 0.3 # Raio aproximado da nave
      
      # Calcula a distância entre a nave e o asteroide
      dx = nave.pos.x - ast.pos.x
      dy = nave.pos.y - ast.pos.y
      
      # Se a distância for menor que a soma dos raios, houve colisão
      if (dx*dx + dy*dy) < (raio_nave + ast.size)**2
        cria_explosao_nave(nave.pos) # Cria uma explosão na posição da nave
        nave.remove()           # Remove a nave antiga
        nave = null             # Define a nave como nula para evitar erros
        ast.remove()            # Remove o asteroide
        
        # Chama a função para resetar e dar respawn após 1.5 segundos
        setTimeout( reset_game, 1500 ) 
        
        break # Para o loop, pois a nave já foi destruída

  # --- LÓGICA DE SPAWN DE ASTEROIDES ---
  asteroides_atuais = ls.get_instances_by_class( 'asteroide' )
  if asteroides_atuais.length < max_asteroides
    contador_spawn_asteroide++
    if contador_spawn_asteroide >= intervalo_spawn_asteroide
      cria_asteroide()
      
      contador_spawn_asteroide = 0 # Reseta o contador
  # -----------------------------------

TRS = (pos, ang,rx,ry,rz, scale_factor) ->
  S = mat.scale scale_factor
  R = mat.rotate(ang, rx,ry,rz) 
  T = mat.translate pos
  return mat.mul T, R, S

atualiza_uniforms = () ->
  multiplayer_send_to_server()

  for inst in ls.instances()
    u = inst.get_uniform_data()
    cl = inst.get_class()
    switch cl
      when 'nave'        
        u.model = TRS nave.pos, nave.ang,0,0,1, 0.3
      when 'asteroide'
        u.model = TRS inst.pos, inst.ang,1,1,1, inst.size
        inst.ang+=5
      when 'tiro'
        u.model = TRS inst.pos, inst.ang,0,0,1, 0.5
        inst.ang+=10
      when 'coisa', 'explosao'
        u.model = TRS inst.pos, 0,0,0,0, inst.size
      when 'multiplayer-nave'
        u.model = TRS inst.pos, inst.ang,0,0,1, 0.3
  gr.dados_instancias.gpu_send()

main()