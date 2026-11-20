# Asfalto de Troca

**Versão 0.5.0 · Android · 3D · single-player offline**

[Baixar o APK para Android na release v0.5.0](https://github.com/Henrique-Girao/Jogo-de-Corrida/releases/tag/v0.5.0)

Baía do Sal é uma cidade portuária fictícia. Você começa na Oficina Ribeira com um **Brasa 1.6** e **Cr 2.500**. Explore os quatro setores a pé e vá até os carros, pilotos, bancadas ou guichês para interagir. Procure o terminal de **Saída** em cada setor para viajar.

## Modelagem low-poly da versão 0.5.0

- Os dez carros jogáveis e o furgão do cais têm perfis próprios de carroceria, com loops de quads que contornam a cabine, os vincos e os recortes das rodas. Os faróis e lanternas têm perfis encaixados. A pintura continua configurável e as rodas têm pneus, aros e raios modelados.
- O jogador e os doze pilotos usam malhas com pesos de deformação nos ombros, no quadril e nos joelhos. Cada personagem tem um atlas UV com rosto, roupa e calçado. A animação usa os vértices das solas como referência para o contato com o piso.
- Dezenove modelos de cenário incluem a bancada com nicho e gavetas, o painel com chaves de boca, os terminais, a porta de enrolar, os contêineres, os galpões e o cargueiro. O conjunto inclui variações de árvores e rochas e peças reaproveitadas entre setores.

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

Godot e Unity atendem ao Android. O Godot foi escolhido porque o editor nativo já estava disponível no ambiente e GDScript permite manter o código, os recursos e a lógica de importação em um único projeto, com exportação offline pelo template Android. O renderizador Compatibility reduz os requisitos gráficos para OpenGL ES 3.0.

| Caminho | Responsabilidade |
| --- | --- |
| `src/main.gd` | Transição entre setores e corrida, entrada e liquidação, áudio e pausa de aplicativo |
| `src/domain/` | Catálogo orientado a dados, negociação, coleção, tuning, classificação, reserva de apostas e persistência |
| `src/world/` | Mapas exploráveis, personagem a pé, câmera, colisões e interações por proximidade |
| `src/race/` | Eventos, treino livre, física simcade a 60 Hz, IA, checkpoints, câmera e resultados |
| `src/tracks/` | Traçados amostrados, altura, curvatura, minimapa e cenário 3D por perfil gráfico |
| `src/art/` | Biblioteca de malhas importadas, pintura de veículos, texturas de superfície e shaders de pintura, céu e água |
| `src/ui/` | Diálogos contextuais, HUDs, controles multitoque e configurações |
| `src/audio/` | Mixagem, motor dinâmico e gerador dos recursos sonoros originais |
| `assets/` | Ícone, modelos GLB com materiais e áudio prontos para exportação |
| `art/` | Cenas editáveis do Blender, atlas UV originais e scripts de autoria |
| `tests/` | Verificações reproduzíveis de domínio, corrida e fluxo integrado |

Os traçados, o terreno e a composição dos cenários são montados pelo Godot. Carrocerias, rodas, personagens e objetos específicos carregam malhas GLB com atlas e materiais. Apenas o setor em uso fica carregado. As malhas e as texturas são reutilizadas. Rodas estacionadas e peças repetidas são agrupadas em instâncias, com descarte por distância. Céu e água usam materiais próprios em OpenGL ES 3.0. A qualidade gráfica ajusta a distância de exibição dos carros nos setores, além da densidade, das sombras e do detalhe do terreno nas pistas. O perfil Alto ativa MSAA 2×, assim como o Automático no desktop. A opção de 30 ou 60 FPS configura o limite de renderização. A simulação mantém 60 Hz. Os recursos audiovisuais foram criados para o projeto. A fonte DejaVu acompanha sua licença em `src/ui/fonts/LICENSE-DejaVu.txt`.

## Editar os modelos

Abra `art/carrocerias.blend`, `art/elenco.blend` ou `art/distritos.blend` no Blender 4.3. As coleções são nomeadas por modelo. As malhas guardam os loops em quads onde interessa editar o contorno. A triangulação ocorre na exportação. As imagens são empacotadas nos arquivos do Blender e estão disponíveis separadamente em `art/textures/` e `assets/models/cars/atlas/`. Os GLB em `assets/models/` incluem suas texturas. Durante a importação no Godot, os carros passam a compartilhar um atlas de acabamento e os modelos recebem níveis de detalhe.

Os arquivos em `art/tools/` registram os perfis de cada malha e a composição dos atlas. Para reproduzir o acervo a partir desses perfis, use a raiz do projeto, Blender 4.3, Python 3 com Pillow e NumPy. A reconstrução sobrescreve os arquivos editáveis e os GLB.

```sh
python art/tools/textures.py
python art/tools/cast_textures.py
python art/tools/prop_textures.py
for kit in cars people props; do
  blender -b -t 3 --python-exit-code 1 --python-expr \
    "import sys; sys.path.insert(0, 'art/tools'); import ${kit}; ${kit}.main()"
done
godot --headless --editor --path . --import --quit
```

`Carroceria_<id>` e `Roda_<id>` compartilham a origem local. A dianteira aponta para −Z no Godot. Preserve os nomes dos materiais `Pintura`, `Vidro`, `Farois` e `Lanternas` ao reexportar. Eles conectam a malha à personalização e à luz de freio. Nos personagens, mantenha o nome e a hierarquia do esqueleto. As peças do cenário compartilham um GLB que agrupa as malhas por nome.

Para reexportar uma edição manual, use **File → Export → glTF 2.0**, formato **glTF Binary** e a opção **Selected Objects**. Para um carro, selecione a carroceria e a roda cujo nome começa com `Roda_`. Ponha os dois objetos na origem antes de exportar para `assets/models/cars/<id>.glb`. Os PNG do carro usados pelo jogo ficam em `assets/models/cars/atlas/`. Para um personagem, selecione o esqueleto e a malha, redefina a posição do esqueleto com **Alt+G** e mantenha as transformações locais da malha filha. Exporte para `assets/models/people/<id>.glb`. Para o cenário, selecione os modelos de `distritos.blend` e exporte para `assets/models/props/distritos.glb`.

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
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . \
  --script res://tests/art_smoke.gd
```

Os testes cobrem a garagem com 99 carros, colisão ao caminhar, prévia e aplicação de pintura, NPCs e seus carros, negociação no pátio, treino livre e o fluxo de uma corrida. O teste de ponta a ponta anda até a saída, viaja ao paddock, chega ao guichê por toque, completa a arrancada e volta ao mesmo ponto com o prêmio salvo. O teste de cenários verifica o asfalto em três faixas de cada traçado, a emenda dos circuitos, as marcas de largada, a cronometragem na faixa e a área útil dos letreiros. O teste de arte verifica os atlas importados, a folga dos pneus, a pintura variável, a luz de freio e o contato das solas. Os quatro setores e as três pistas foram conferidos no desktop com renderização OpenGL.

A distribuição inclui um APK com assinatura de teste. A validação da versão 0.5.0 em aparelhos Android físicos e as medições de desempenho continuam pendentes.
