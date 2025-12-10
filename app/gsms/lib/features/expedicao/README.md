# Expedição (Delivery Management)

## Overview

A página de **Expedição** gerencia o fluxo completo de despacho e entrega de pedidos, com separação clara entre Pedidos, Entregas e Motoristas. O sistema utiliza uma interface com abas para organizar as diferentes operações.

## Arquitetura

### Modelos de Dados

#### 1. **OrderModel** (Pedido)
Representa um pedido individual que pode ser incluído em entregas.
- `id`: Identificador único (baseado em timestamp)
- `orderNumber`: Número/referência do pedido (string)
- `responsible`: Pessoa responsável pelo pedido
- `createdAt`: Timestamp ISO8601 de criação
- Hive TypeId: 13

#### 2. **DeliveryModel** (Entrega)
Representa uma entrega que agrupa múltiplos pedidos junto com informações do motorista e linha do tempo.
- `id`: Identificador único
- `orderIds`: Lista de IDs de pedidos inclusos nesta entrega
- `driverId`: ID do motorista atribuído (opcional)
- `status`: Status atual da entrega (pending, assigned, dispatched, delivered, cancelled)
- `createdAt`: Timestamp ISO8601 de criação
- `dispatchedAt`: Timestamp ISO8601 quando entrega saiu (opcional)
- `finishedAt`: Timestamp ISO8601 quando entrega foi concluída (opcional)
- Métodos auxiliares:
  - `timeSinceDispatch()`: Retorna Duration desde despacho
  - `timeSinceDispatchFormatted`: Retorna string formatada legível
- Hive TypeId: 10

#### 3. **DriverModel** (Motorista)
Modelo simplificado de motorista com apenas informações essenciais.
- `id`: Identificador único
- `name`: Nome completo do motorista
- Hive TypeId: 12

## Interface de Usuário

A página Expedição usa **TabBar** com 3 abas:

### Aba 1: Pedidos (Orders)
- **Lista**: Mostra todos os pedidos criados com número, responsável e data de criação
- **Adicionar Pedido**: FAB abre modal para criar novo pedido
  - Entradas: Número do Pedido, Responsável
- **Editar Pedido**: Opção de menu para modificar detalhes
- **Deletar Pedido**: Opção de menu para remover pedido (com confirmação)

### Aba 2: Entregas (Deliveries)
- **Lista**: Mostra todas as entregas com cards expansíveis exibindo:
  - Badge de status (com cores)
  - ID da entrega
  - Timestamp de criação
- **Expandir Card**: Revela:
  - Pedidos inclusos (com números e responsáveis)
  - Seção de linha do tempo (criação, despacho, finalização)
  - Tempo desde despacho (atualizado a cada minuto)
  - Nome do motorista atribuído ou "Não atribuído"
  - Botões de ação baseados no status atual
- **Adicionar Entrega**: FAB abre modal para criar entrega
  - Multi-selecionar pedidos da lista
  - Cria entrega com status "pending"
- **Atribuir Motorista**: Muda status para "assigned" e registra motorista
- **Despachar**: Marca como "dispatched" e registra timestamp
- **Finalizar**: Marca como "delivered" e registra timestamp
- **Cancelar**: Muda status para "cancelled"

### Aba 3: Motoristas (Drivers)
- **Lista**: Mostra todos os motoristas registrados com seus nomes
- **Adicionar Motorista**: FAB abre modal para adicionar motorista
  - Entrada: Nome do Motorista
- **Deletar Motorista**: Opção de menu para remover motorista (com confirmação)

## Ciclo de Vida de uma Entrega

```
pending → assigned → dispatched → delivered
   ↓
cancelled (pode cancelar de qualquer estado anterior)
```

**Cores de Status:**
- pending: Cinza
- assigned: Azul
- dispatched: Laranja
- delivered: Verde
- cancelled: Vermelho

## Integração Hive

**Caixas:**
- `orders`: Armazena instâncias de OrderModel
- `deliveries`: Armazena instâncias de DeliveryModel
- `drivers`: Armazena instâncias de DriverModel

**Adapters:**
Todos os modelos têm HiveAdapter gerados via `build_runner`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Recursos Principais

1. **Atualizações Reativas**: Usa `ValueListenableBuilder` para atualizações UI em tempo real
2. **Rastreamento de Linha do Tempo**: Exibe timestamps de criação, despacho e finalização
3. **Tempo Desde Despacho**: Auto-atualiza a cada minuto usando Timer
4. **Entregas com Múltiplos Pedidos**: Uma entrega pode conter vários pedidos
5. **Gerenciamento de Status**: Fluxo completo de "pending" para "delivered"
6. **Cards Expansíveis**: Detalhes de entrega expandem ao tocar para informações completas
7. **Modais para Entrada**: Diálogos modais limpos para adicionar/editar dados

## Exemplo de Uso

```dart
// Criar um pedido
final order = OrderModel.create(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  orderNumber: 'PED-001',
  responsible: 'João',
);
ordersBox.put(order.id, order);

// Criar um motorista
final driver = DriverModel.create(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  name: 'Carlos',
);
driversBox.put(driver.id, driver);

// Criar uma entrega com pedidos
final delivery = DeliveryModel.create(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  orderIds: [order.id],
);
deliveriesBox.put(delivery.id, delivery);

// Atribuir motorista
delivery.driverId = driver.id;
delivery.status = 'assigned';
delivery.save();

// Despachar
delivery.dispatchedAt = DateTime.now().toIso8601String();
delivery.status = 'dispatched';
delivery.save();

// Finalizar
delivery.finishedAt = DateTime.now().toIso8601String();
delivery.status = 'delivered';
delivery.save();
```

## Estrutura de Arquivos

```
lib/features/expedicao/
├── domain/
│   └── models/
│       ├── delivery_model.dart       # Modelo de entrega com anotações Hive
│       ├── driver_model.dart         # Modelo de motorista (apenas nome)
│       ├── order_model.dart          # Modelo de pedido
│       └── delivery_item.dart        # (Descontinuado - não mais usado)
└── expedicao_page.dart               # UI principal com TabBar, abas e modais
```

## Dependências

- `flutter`: Framework UI
- `hive_flutter`: Persistência local
- `intl`: Formatação de datas
- `provider`: State management (usado pelo app, opcional para este recurso)
- `build_runner`: Geração de código para adapters Hive

## Checklist de Testes

- [ ] Criar pedidos e verificar se aparecem na aba Pedidos
- [ ] Editar detalhes do pedido e confirmar alterações
- [ ] Deletar pedido e confirmar remoção
- [ ] Adicionar motorista e verificar na aba Motoristas
- [ ] Criar entrega selecionando múltiplos pedidos
- [ ] Atribuir motorista a uma entrega
- [ ] Despachar entrega e verificar timestamps
- [ ] Verificar se tempo-desde-despacho se atualiza automaticamente
- [ ] Finalizar entrega e confirmar estado final
- [ ] Cancelar entrega e verificar mudança de status
- [ ] Testar navegação entre as três abas

## Problemas Conhecidos

- Avisos de deprecação do RadioListTile (Flutter 3.32+) - funcionalidade funciona corretamente
- Exibição de tempo se atualiza a cada minuto (não em tempo real de segundos) - aceitável para rastreamento de entrega

## Melhorias Futuras

- [ ] Busca/filtro de pedidos e entregas
- [ ] Exportar relatórios de entrega
- [ ] Rastreamento GPS para entregas despachadas
- [ ] Notificações SMS para motorista
- [ ] Operações em lote (selecionar múltiplas entregas)
- [ ] Dashboard de estatísticas (entregas por dia, tempo médio, etc.)
