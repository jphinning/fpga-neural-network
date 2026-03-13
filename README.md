# FPGA Neural Network — CNN em VHDL para Amplificador de Potência

Implementação completa de uma **Rede Neural Convolucional (CNN) em VHDL** para predição do comportamento de amplificadores de potência (PA) em hardware digital (FPGA). Os pesos são extraídos diretamente de um modelo treinado em PyTorch e embarcados como constantes na lógica programável.

## 🎯 Objetivo

Implementar em hardware reconfigurável (FPGA) um modelo de deep learning treinado em PyTorch, permitindo inferência em tempo real com baixa latência para aplicações de RF e telecomunicações.

## 🏗️ Arquitetura Hardware

```
                    ┌──────────────────────────────────────┐
                    │           top_neural_net.vhd          │
                    │                                       │
  IQ Input ────────►│  input_processing                    │
                    │       │                               │
                    │       ▼                               │
                    │  conv1d_block (Conv Layer Serial)     │
                    │       │                               │
                    │       ▼                               │
                    │  pooling_ReLU_block                   │
                    │       │                               │
                    │       ▼                               │
                    │  mlp_chain_serial (Dense Layers)      │
                    │       │                               │
                    │       ▼                               │
                    │  BackEnd_Wrapper                      │────► PA Output
                    └──────────────────────────────────────┘
```

## 📦 Componentes VHDL

| Arquivo | Descrição |
|---|---|
| `top_neural_net.vhd` | Top-level da rede neural completa |
| `input_processing.vhd` | Pré-processamento e normalização da entrada |
| `conv1d_block.vhd` | Bloco de convolução 1D |
| `conv_layer_serial.vhd` | Camada convolucional com processamento serial |
| `pooling_ReLU_block.vhd` | Pooling + ativação ReLU |
| `dense_layer.vhd` | Camada fully-connected (dense) |
| `mlp_chain_serial.vhd` | Cadeia de camadas MLP em série |
| `MAC_unit.vhd` | Unidade de Multiply-Accumulate |
| `LUT_tanh.vhd` | Look-Up Table para função de ativação tanh |
| `LUT_trig.vhd` | Look-Up Table para funções trigonométricas |
| `shift_register.vhd` | Registrador de deslocamento |
| `complex_mult_output.vhd` | Multiplicação de números complexos |
| `PA.vhd` | Módulo do amplificador de potência |
| `BackEnd_Wrapper.vhd` | Wrapper do backend de inferência |
| `pkg_model_constants.vhd` | Pacote com pesos do modelo (extraídos do PyTorch) |
| `pkg_neural_types.vhd` | Pacote com tipos customizados para a rede neural |

> Todos os módulos possuem testbench correspondente (`*_tb.vhd`)

## 🔬 Fluxo de Desenvolvimento

```
PyTorch (Python)              VHDL (FPGA)
      │                           │
      │  Treinar modelo           │
      │  Extrair pesos    ──────► │  pkg_model_constants.vhd
      │  Gerar vetores    ──────► │  validation_vectors_*.txt
      │                           │
      │                  ◄──────  │  Simulação (ModelSim/GHDL)
      │  Comparar saídas          │
      └───────────────────────────┘
         Co-simulação / Validação
```

## 🛠️ Simulação

```bash
# Usando GHDL (exemplo para o top-level)
ghdl -a pkg_neural_types.vhd pkg_model_constants.vhd MAC_unit.vhd ...
ghdl -a top_neural_net.vhd top_neural_net_tb.vhd
ghdl -e top_neural_net_tb
ghdl -r top_neural_net_tb --vcd=output.vcd
```

## 📊 Validação

Os arquivos `validation_vectors_*.txt` contêm vetores de teste gerados pelo modelo PyTorch. A saída do hardware (`output_results.txt` / `vhdl_output_dump.txt`) é comparada diretamente com a referência em software para verificar a fidelidade numérica da implementação.

## 🔗 Repositório relacionado

- [pa-neural-network](https://github.com/jphinning/pa-neural-network) — treinamento do modelo em PyTorch e geração dos pesos/vetores
