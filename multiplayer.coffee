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



