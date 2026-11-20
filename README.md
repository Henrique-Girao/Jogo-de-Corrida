# Asfalto de Troca

**Versão 0.4.0 · Android · 3D · single-player offline**

[Baixar o APK para Android na release v0.4.0](https://github.com/Henrique-Girao/Jogo-de-Corrida/releases/tag/v0.4.0)

Baía do Sal é uma cidade portuária fictícia. Você começa na Oficina Ribeira com um **Brasa 1.6** e **Cr 2.500**. Explore os quatro setores a pé e vá até os carros, pilotos, bancadas ou guichês para interagir. Procure o terminal de **Saída** em cada setor para viajar.

## Arte da versão 0.3.0

- Cada carro tem perfil de carroceria, acabamento, vidros e rodas próprios. A pintura usa reflexos estilizados que acompanham os ângulos da carroceria.
- Os doze pilotos têm proporções, roupas e cortes de cabelo definidos individualmente. O personagem do jogador usa a mesma estrutura de animação, com articulação nos joelhos para o passo.
- Os quatro setores receberam sinalização, materiais e peças específicas. A oficina tem iluminação quente sobre a bancada, o porto tem água e guindastes treliçados, o paddock tem uma arquibancada com setores e a revenda tem vitrines e bases de exposição.
- O Autódromo Candeia tem luz diurna e boxes revistos. O Cais Ferrugem usa tons frios de fim de tarde e luzes quentes junto à pista. Na Serra da Lua, a vegetação e os taludes acompanham as curvas.
- Os painéis de exploração e corrida usam a mesma paleta. Os botões deixam o centro da tela livre.

## Pistas e cenários da versão 0.4.0

- A posição dos carros e a pintura do grid usam as mesmas vagas de largada. A faixa sob o pórtico do circuito marca a passagem de volta e a chegada.
- O asfalto e a sinalização compartilham as seções do traçado. Os circuitos fecham com a mesma seção nas duas pontas. O treino livre identifica circuito e percurso aberto.
- A colocação de estruturas, contêineres e vegetação nas pistas considera a distância ao asfalto e a altura do terreno. Arquibancadas, postes e placas ganharam apoios conectados ao chão.
- Nos setores, os letreiros têm margens calculadas, as placas de preço ficam no piso e as inscrições da Copa da Orla têm espaço próprio no paddock.

## Como jogar

- **Oficina Ribeira** — percorra as vagas da sua coleção, inspecione um carro e escolha qual usar. A mecânica instala peças e a pintura mostra a prévia na carroceria estacionada. O anexo abre conforme a coleção cresce, até 99 carros. O quadro da garagem acompanha as metas opcionais.
- **Porto da Vigília** — encontre os 12 pilotos ao lado dos carros deles. Fale com cada um para ver os duelos disponíveis. No Pink Slip, a vitória transfere o carro do rival para a sua garagem. Derrota ou abandono transfere o seu. Se a garagem ficar vazia, a revenda empresta um carro para as provas oficiais.
- **Paddock Candeia** — aproxime-se do guichê de uma prova para conferir regras e se inscrever. Há guichês próprios para a Copa da Orla. O posto de treino livre dá acesso às três pistas para dirigir sem classificação ou prêmio.
- **Revenda do Cais** — examine os veículos anunciados no pátio. Negocie junto ao carro e, com particulares, ofereça um veículo próprio como parte do pagamento. Procure o balcão de avaliação para vender. Os anúncios acompanham a reputação e a rotação do mercado.

São **10 modelos de carro**, **12 pilotos**, **11 eventos** e **10 tipos de peça** com dois níveis cada. Tração, aderência, peso e potência alteram a condução. O jogo salva automaticamente o setor atual, transações, resultados e configurações. Ao terminar uma prova ou sair do treino, você volta ao ponto de partida no setor. Uma corrida interrompida reinicia na largada com a inscrição e a aposta preservadas. Todos os créditos e veículos são fictícios.

| Ação | Android | Desktop |
| --- | --- | --- |
| Andar | Direcional esquerdo | WASD ou setas |
| Olhar a pé | Arrastar o lado direito | Arrastar com o botão direito |
| Interagir | Botão que aparece ao se aproximar | E ou clique |
| Configurações | Engrenagem ou Voltar | Engrenagem ou Esc |
| Direção na pista | Setas na esquerda | A/D ou ←/→ |
| Aceleração | Gás | W ou ↑ |
| Freio e ré | Freio | S ou ↓ |
| Freio de mão | Mão | Espaço |
| Subir marcha na arrancada | Botão de marcha | Espaço |
| Pausa | Botão Ⅱ ou Voltar | Esc |
| Reposicionar | Menu de pausa | R |
| Trocar câmera | Menu de pausa | C |

## Executar o projeto

Use **Godot 4.6.3 Standard**. Abra `project.godot`, aguarde a importação e pressione **F5**.

```sh
godot --headless --editor --path . --import
godot --path .
godot --path . -- --touch-controls
```

O último comando exibe os controles de toque no desktop para testes. O save fica em `user://asfalto_de_troca.json`, com backup local. No Linux, o diretório padrão é `~/.local/share/godot/app_userdata/Asfalto de Troca/`. Saves da versão 0.1.0 mantêm o progresso e iniciam a exploração na Oficina Ribeira.

## Exportar o APK

O preset Android usa o template oficial do Godot com OpenGL ES 3.0. O APK tem como mínimo Android 7.0 (API 24) e inclui `arm64-v8a`, `armeabi-v7a` e `x86_64`.

1. Instale os templates do Godot **4.6.3** em **Editor → Manage Export Templates**.
2. Instale OpenJDK 17 ou 21, Android SDK Platform 36, Build Tools 36.0.0 e Platform Tools. Em **Editor → Editor Settings → Export → Android**, informe os diretórios do JDK e do SDK.
3. Para assinatura de teste, configure o **Debug Keystore** no editor. Se precisar gerar uma chave local, use o comando abaixo. Guarde a chave fora do repositório.
4. Em **Project → Export → Android**, selecione **Export Project** com a opção **Export With Debug**. A linha de comando equivalente aparece abaixo.

```sh
keytool -genkeypair -keystore debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'

mkdir -p builds
godot --headless --path . --export-debug Android builds/Asfalto-de-Troca.apk
adb install -r builds/Asfalto-de-Troca.apk
```

A assinatura de distribuição pode ser configurada no preset Android com uma chave própria. Para gerar a versão Linux x86-64 com o PCK embutido, instale os mesmos templates e rode `godot --headless --path . --export-release Linux builds/Asfalto-de-Troca.x86_64`.

## Arquitetura

Godot e Unity atendem ao Android. O Godot foi escolhido porque o editor nativo já estava disponível no ambiente e GDScript permite manter o código e os recursos procedurais em um único projeto, com exportação offline pelo template Android. O renderizador Compatibility reduz os requisitos gráficos para OpenGL ES 3.0.

| Caminho | Responsabilidade |
| --- | --- |
| `src/main.gd` | Transição entre setores e corrida, entrada e liquidação, áudio e pausa de aplicativo |
| `src/domain/` | Catálogo orientado a dados, negociação, coleção, tuning, classificação, reserva de apostas e persistência |
| `src/world/` | Mapas exploráveis, personagem a pé, câmera, colisões e interações por proximidade |
| `src/race/` | Eventos, treino livre, física simcade a 60 Hz, IA, checkpoints, câmera e resultados |
| `src/tracks/` | Traçados amostrados, altura, curvatura, minimapa e cenário 3D por perfil gráfico |
| `src/art/` | Carrocerias procedurais, formas reaproveitáveis, texturas de superfície e shaders de pintura, céu e água |
| `src/ui/` | Diálogos contextuais, HUDs, controles multitoque e configurações |
| `src/audio/` | Mixagem, motor dinâmico e gerador dos recursos sonoros originais |
| `assets/` | Ícone e recursos de áudio prontos para exportação |
| `tests/` | Verificações reproduzíveis de domínio, corrida e fluxo integrado |

Os cenários e veículos são gerados por código. Apenas o setor em uso fica carregado. As malhas de carros e as texturas são reutilizadas. Rodas estacionadas e peças repetidas são agrupadas em instâncias, com descarte por distância. Céu e água usam materiais próprios em OpenGL ES 3.0. A qualidade gráfica ajusta a distância de exibição dos carros nos setores, além da densidade, das sombras e do detalhe do terreno nas pistas. O perfil Alto ativa MSAA 2×, assim como o Automático no desktop. A opção de 30 ou 60 FPS configura o limite de renderização. A simulação mantém 60 Hz. Os recursos audiovisuais foram criados para o projeto. A fonte DejaVu acompanha sua licença em `src/ui/fonts/LICENSE-DejaVu.txt`.

## Verificação e continuidade

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/domain_smoke.gd
godot --headless --path . --script res://tests/race_simulation.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . \
  --script res://tests/game_smoke.gd --fixed-fps 60 -- --touch-controls
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . \
  --script res://tests/exploration_smoke.gd --fixed-fps 60 -- --touch-controls
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . \
  --script res://tests/scenery_smoke.gd
```

Os testes cobrem a garagem com 99 carros, colisão ao caminhar, prévia e aplicação de pintura, NPCs e seus carros, negociação no pátio, treino livre e o fluxo de uma corrida. O teste de ponta a ponta anda até a saída, viaja ao paddock, chega ao guichê por toque, completa a arrancada e volta ao mesmo ponto com o prêmio salvo. O teste de cenários verifica o asfalto em três faixas de cada traçado, a emenda dos circuitos, as marcas de largada, a cronometragem na faixa e a área útil dos letreiros. Os quatro setores e as três pistas foram conferidos no desktop com renderização OpenGL.

A distribuição inclui um APK com assinatura de teste. A validação da versão 0.4.0 em aparelhos Android físicos e as medições de desempenho continuam pendentes.
