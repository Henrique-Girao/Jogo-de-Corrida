# Asfalto de Troca

**Versão 0.1.0 · Android · 3D · single-player offline**

[Baixar o APK para Android](https://github.com/Henrique-Girao/Jogo-de-Corrida/releases/download/v0.1.0/Asfalto-de-Troca.apk)

Baía do Sal é uma cidade portuária fictícia. Você começa na Oficina Ribeira com um **Brasa 1.6** e **Cr 2.500**. Corra no calendário oficial, prepare o carro, negocie com os entusiastas do porto ou desafie um rival pelas chaves dele. Cada atividade oferece um caminho para ampliar a garagem.

## Como jogar

- **Garagem** — selecione um veículo, arraste sobre a vitrine para girar a câmera, instale peças ou altere a cor.
- **Competições** — corra no Autódromo Candeia, no Cais Ferrugem e na Serra da Lua. O calendário inclui circuito, sprint, contrarrelógio, arrancada, regras de categoria e a Copa da Orla em três etapas.
- **Encontro** — conheça os pilotos no Porto da Vigília. Antes de confirmar um duelo, confira a quantia ou o veículo em jogo. No Pink Slip, a vitória transfere o carro do rival para sua garagem. Derrota ou abandono transfere o seu. Se sua garagem ficar vazia, a revenda fornece um carro emprestado para as provas oficiais.
- **Comércio** — compare preços de concessionária e particulares, faça contrapropostas, venda ou ofereça um carro como parte do pagamento. A oferta muda conforme a reputação, os resultados e as preferências de cada NPC.
- **Desafios** — acompanhe metas opcionais da coleção, das provas e do comércio.

São **10 carros fictícios**, **12 NPCs**, **11 eventos** e **10 tipos de peça** com dois níveis cada. Tração dianteira, traseira e integral, aderência, peso e potência alteram a condução. O jogo salva automaticamente as transações, os resultados e as configurações. Uma corrida interrompida reinicia na largada com a inscrição e a aposta preservadas. Todos os créditos e veículos são fictícios.

| Ação | Android | Desktop |
| --- | --- | --- |
| Direção | Setas na esquerda | A/D ou ←/→ |
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

O último comando exibe os botões de toque no desktop para testes. O save fica em `user://asfalto_de_troca.json`, com backup local. No Linux, o diretório padrão é `~/.local/share/godot/app_userdata/Asfalto de Troca/`.

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
| `src/race/` | Eventos, física simcade a 60 Hz, IA, checkpoints, câmera e resultados |
| `src/tracks/` | Traçados amostrados, altura, curvatura, minimapa e cenário 3D por perfil gráfico |
| `src/art/` | Carros procedurais com dois níveis de detalhe, pintura, animação de rodas e ambientes de exposição |
| `src/ui/` | Menus e HUD, controles multitoque e configurações |
| `src/audio/` | Mixagem, motor dinâmico e gerador dos recursos sonoros originais |
| `assets/` | Ícone e recursos de áudio prontos para exportação |
| `tests/` | Verificações reproduzíveis de domínio, corrida e fluxo integrado |

Os cenários e veículos são gerados por código. As malhas de carros são reutilizadas e os objetos estáticos das pistas são agrupados por área para descarte à distância. A qualidade reduz densidade, sombras e detalhe do terreno. A opção de 30 ou 60 FPS configura o limite de renderização. A simulação mantém 60 Hz. Os recursos audiovisuais foram criados para o projeto. A fonte DejaVu acompanha sua licença em `src/ui/fonts/LICENSE-DejaVu.txt`.

## Verificação e continuidade

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/domain_smoke.gd
godot --headless --path . --script res://tests/race_simulation.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . \
  --script res://tests/game_smoke.gd --fixed-fps 60 -- --touch-controls
```

Os testes cobrem negociações e trocas, tuning, recuperação de garagem e save, inscrições, apostas, física de corrida, troca de marchas, pausa, abandono e pagamento após uma corrida aberta pelo menu. Garagem, calendário, corrida e pausa foram conferidos no desktop com renderização OpenGL.

A distribuição inclui um APK com assinatura de teste. A assinatura v2/v3, o alinhamento e a leitura do conteúdo exportado passaram nas verificações de pacote. O Android 11 emulado (API 30, x86-64) confirmou a instalação e iniciou a atividade do jogo. A interface do sistema do emulador parou de responder antes da inspeção da garagem.

Esta versão é a primeira entrega jogável. A próxima etapa é medir estabilidade, tempos de carregamento e FPS em aparelhos Android físicos de entrada e intermediários, depois ajustar qualidade e balanceamento com playtests prolongados.
