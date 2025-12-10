import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'domain/models/delivery_model.dart';
import 'domain/models/driver_model.dart';
import 'domain/models/order_model.dart';

// Temporarily ignore deprecated RadioList APIs until migrating to RadioGroup
// ignore_for_file: deprecated_member_use

class ExpedicaoPage extends StatefulWidget {
  const ExpedicaoPage({super.key});

  @override
  State<ExpedicaoPage> createState() => _ExpedicaoPageState();
}

class _ExpedicaoPageState extends State<ExpedicaoPage>
    with TickerProviderStateMixin {
  late Box<OrderModel> _ordersBox;
  late Box<DeliveryModel> _deliveriesBox;
  late Box<DriverModel> _driversBox;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  late TabController _tabController;
  late Timer _timer;
  late ScrollController _entregasScrollController;
  late TextEditingController _emEntregaSearchController;
  late TextEditingController _finalizadasSearchController;
  final Map<String, GlobalKey> _deliveryKeys = {};
  final Set<String> _expandedDeliveryIds = {};
  String? _navigateToDeliveryId;

  // Search/filter state
  String _notasSearchQuery = '';
  String _notasStatusFilter = 'Sem entrega'; // New filter for notes tab
  String _emEntregaSearchQuery = '';
  String _finalizadasSearchQuery = '';
  DateTime? _finalizadasFilterDate = DateTime.now();
  String _entregasStatusFilter = 'Todos';

  String _formatDate(String? s) {
    if (s == null) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '—';
    return _dateFormat.format(dt);
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Aguardando Envio';
      case 'assigned':
        return 'Aguardando Envio';
      case 'dispatched':
        return 'Em Entrega';
      case 'delivered':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'assigned':
        return Colors.blue;
      case 'dispatched':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _ordersBox = Hive.box<OrderModel>('orders');
    _deliveriesBox = Hive.box<DeliveryModel>('deliveries');
    _driversBox = Hive.box<DriverModel>('drivers');
    _tabController = TabController(length: 3, vsync: this);
    _entregasScrollController = ScrollController();
    _emEntregaSearchController = TextEditingController();
    _finalizadasSearchController = TextEditingController();

    // Timer to refresh time display every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    _entregasScrollController.dispose();
    _emEntregaSearchController.dispose();
    _finalizadasSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expedição'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMotorizestsMenu(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notas', icon: Icon(Icons.receipt)),
            Tab(text: 'Entregas', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Finalizadas', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotasTab(),
          _buildEmEntregaTab(),
          _buildFinalizadasTab(),
        ],
      ),
    );
  }

  void _showMotorizestsMenu() {
    showDialog(
      context: context,
      builder: (ctx) => MotorizestsModal(box: _driversBox),
    );
  }

  // ===== NOTAS TAB =====
  Widget _buildNotasTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _notasSearchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _notasStatusFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Sem entrega',
                      child: Text('Sem entrega'),
                    ),
                    DropdownMenuItem(
                      value: 'Aguardando Envio',
                      child: Text('Aguardando Envio'),
                    ),
                    DropdownMenuItem(
                      value: 'Em Entrega',
                      child: Text('Em Entrega'),
                    ),
                    DropdownMenuItem(
                      value: 'Finalizado',
                      child: Text('Finalizado'),
                    ),
                    DropdownMenuItem(
                      value: 'Cancelado',
                      child: Text('Cancelado'),
                    ),
                    DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                  ],
                  onChanged: (v) =>
                      setState(() => _notasStatusFilter = v ?? 'Sem entrega'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Box<OrderModel>>(
            valueListenable: _ordersBox.listenable(),
            builder: (context, box, _) {
              final orders = box.values.toList().cast<OrderModel>();
              // Get all order IDs that are already assigned to deliveries
              final deliveries = _deliveriesBox.values
                  .toList()
                  .cast<DeliveryModel>();
              final usedOrderIds = <String>{};
              for (final d in deliveries) {
                usedOrderIds.addAll(d.orderIds);
              }
              // Filter: search query + status filter
              final filtered = orders.where((o) {
                final matchesSearch =
                    o.orderNumber.toLowerCase().contains(
                      _notasSearchQuery.toLowerCase(),
                    ) ||
                    o.responsible.toLowerCase().contains(
                      _notasSearchQuery.toLowerCase(),
                    );

                // Apply status filter
                bool matchesStatusFilter = false;
                if (_notasStatusFilter == 'Todas') {
                  matchesStatusFilter = true;
                } else if (_notasStatusFilter == 'Sem entrega') {
                  final isNotUsed = !usedOrderIds.contains(o.id);
                  matchesStatusFilter = isNotUsed;
                } else {
                  // Filter by specific delivery status
                  try {
                    final associatedDelivery = _deliveriesBox.values
                        .toList()
                        .cast<DeliveryModel>()
                        .firstWhere((d) => d.orderIds.contains(o.id));
                    final translatedStatus = _translateStatus(
                      associatedDelivery.status,
                    );
                    matchesStatusFilter =
                        translatedStatus == _notasStatusFilter;
                  } catch (_) {
                    // No associated delivery
                    matchesStatusFilter = false;
                  }
                }

                return matchesSearch && matchesStatusFilter;
              }).toList();

              // Sort by status priority and then by date
              filtered.sort((a, b) {
                // Get status priority for ordering
                final statusOrder = {
                  'Sem entrega': 0,
                  'Aguardando Envio': 1,
                  'Em Entrega': 2,
                  'Finalizado': 3,
                  'Cancelado': 4,
                };

                String getOrderStatus(OrderModel order) {
                  if (!usedOrderIds.contains(order.id)) {
                    return 'Sem entrega';
                  }
                  try {
                    final delivery = _deliveriesBox.values
                        .toList()
                        .cast<DeliveryModel>()
                        .firstWhere((d) => d.orderIds.contains(order.id));
                    return _translateStatus(delivery.status);
                  } catch (_) {
                    return 'Sem entrega';
                  }
                }

                final statusA = getOrderStatus(a);
                final statusB = getOrderStatus(b);
                final priorityA = statusOrder[statusA] ?? 0;
                final priorityB = statusOrder[statusB] ?? 0;

                // First, sort by status priority
                if (priorityA != priorityB) {
                  return priorityA.compareTo(priorityB);
                }

                // Then, sort by date (newest first)
                final dateA =
                    DateTime.tryParse(a.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final dateB =
                    DateTime.tryParse(b.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return dateB.compareTo(dateA);
              });

              return filtered.isEmpty
                  ? const Center(child: Text('Nenhuma nota encontrada.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return _buildOrderCard(context, order);
                      },
                    );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FloatingActionButton.extended(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AddOrderModal(box: _ordersBox),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Nota'),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
        title: Row(
          children: [
            Text(
              'Pedido #${order.orderNumber}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (ctx) {
                DeliveryModel? associatedDelivery;
                try {
                  associatedDelivery = _deliveriesBox.values
                      .toList()
                      .cast<DeliveryModel>()
                      .firstWhere((d) => d.orderIds.contains(order.id));
                } catch (_) {
                  associatedDelivery = null;
                }

                final chipLabel = associatedDelivery != null
                    ? _translateStatus(associatedDelivery.status)
                    : 'Sem entrega';
                final chipColor = associatedDelivery != null
                    ? _getStatusColor(associatedDelivery.status)
                    : Colors.grey;

                return Chip(
                  label: Text(
                    chipLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: chipColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(order.responsible, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (ctx) {
                DeliveryModel? associatedDelivery;
                try {
                  associatedDelivery = _deliveriesBox.values
                      .toList()
                      .cast<DeliveryModel>()
                      .firstWhere((d) => d.orderIds.contains(order.id));
                } catch (_) {
                  associatedDelivery = null;
                }

                return IconButton(
                  tooltip: 'Rastrear',
                  icon: const Icon(Icons.location_searching),
                  onPressed: () {
                    if (associatedDelivery == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nota sem entrega associada'),
                        ),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: Text(
                          'Entrega #${associatedDelivery!.id.substring(0, 8)}',
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Status: ${_translateStatus(associatedDelivery.status)}',
                              ),
                              const SizedBox(height: 6),
                              if (associatedDelivery.driverId != null)
                                Text(
                                  'Motorista: ${_driversBox.get(associatedDelivery.driverId)?.name ?? "—"}',
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'Criado: ${_formatDate(associatedDelivery.createdAt)}',
                              ),
                              if (associatedDelivery.dispatchedAt != null)
                                Text(
                                  'Saiu: ${_formatDate(associatedDelivery.dispatchedAt)}',
                                ),
                              if (associatedDelivery.finishedAt != null)
                                Text(
                                  'Finalizado: ${_formatDate(associatedDelivery.finishedAt)}',
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: Navigator.of(dctx).pop,
                            child: const Text('Fechar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dctx).pop();
                              setState(() {
                                _navigateToDeliveryId = associatedDelivery?.id;
                                // Redireciona para a aba correta baseado no status
                                if (associatedDelivery?.status == 'delivered' ||
                                    associatedDelivery?.status == 'cancelled') {
                                  _tabController.index = 2; // Aba Finalizadas
                                  _finalizadasSearchQuery = order.orderNumber;
                                  _finalizadasSearchController.text =
                                      order.orderNumber;
                                } else {
                                  _tabController.index = 1; // Aba Entregas
                                  _emEntregaSearchQuery = order.orderNumber;
                                  _emEntregaSearchController.text =
                                      order.orderNumber;
                                }
                              });
                            },
                            child: const Text('Ver entrega'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            PopupMenuButton<String>(
              onSelected: (v) => _handleOrderAction(v, order),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Deletar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleOrderAction(String action, OrderModel order) {
    switch (action) {
      case 'edit':
        showDialog(
          context: context,
          builder: (ctx) => EditOrderModal(order: order),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Deletar Pedido'),
            content: const Text('Tem certeza que deseja deletar este pedido?'),
            actions: [
              TextButton(
                onPressed: Navigator.of(ctx).pop,
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  order.delete();
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Deletar'),
              ),
            ],
          ),
        );
        break;
    }
  }

  // ===== EM ENTREGA TAB =====
  Widget _buildEmEntregaTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emEntregaSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por ID, motorista ou nota',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _emEntregaSearchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _entregasStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'Em Entrega',
                    child: Text('Em Entrega'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _entregasStatusFilter = v ?? 'Todos'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Box<DeliveryModel>>(
            valueListenable: _deliveriesBox.listenable(),
            builder: (context, box, _) {
              var deliveries = box.values
                  .toList()
                  .cast<DeliveryModel>()
                  .where(
                    (d) => d.status == 'dispatched' || d.status == 'assigned',
                  )
                  .toList();

              // Apply status filter from dropdown: 'Todos' / 'Em Entrega'
              if (_entregasStatusFilter == 'Em Entrega') {
                deliveries = deliveries
                    .where((d) => d.status == 'dispatched')
                    .toList();
              }

              final filtered = deliveries.where((d) {
                final q = _emEntregaSearchQuery.toLowerCase();
                final matchesId = d.id.toLowerCase().contains(q);

                final driver = d.driverId != null
                    ? _driversBox.get(d.driverId)
                    : null;
                final matchesDriver =
                    driver?.name.toLowerCase().contains(q) ?? false;

                // Check associated orders: match by order number or responsible
                bool matchesOrder = false;
                for (final oid in d.orderIds) {
                  final order = _ordersBox.get(oid);
                  if (order != null) {
                    if (order.orderNumber.toLowerCase().contains(q) ||
                        order.responsible.toLowerCase().contains(q)) {
                      matchesOrder = true;
                      break;
                    }
                  }
                }

                return matchesId || matchesDriver || matchesOrder;
              }).toList();

              // Sort by recent createdAt ones
              filtered.sort((a, b) {
                final da =
                    DateTime.tryParse(a.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final db =
                    DateTime.tryParse(b.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return db.compareTo(da);
              });

              // If someone requested navigation to a specific delivery, try to
              // scroll to and expand it after this frame (keys are attached
              // during itemBuilder).
              if (_navigateToDeliveryId != null) {
                final idx = filtered.indexWhere(
                  (e) => e.id == _navigateToDeliveryId,
                );
                if (idx != -1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final key = _deliveryKeys[_navigateToDeliveryId];
                    if (key?.currentContext != null) {
                      Scrollable.ensureVisible(
                        key!.currentContext!,
                        duration: const Duration(milliseconds: 400),
                        alignment: 0.1,
                      );
                      setState(() {
                        _expandedDeliveryIds.add(_navigateToDeliveryId!);
                        _navigateToDeliveryId = null;
                      });
                    } else {
                      setState(() => _navigateToDeliveryId = null);
                    }
                  });
                } else {
                  _navigateToDeliveryId = null;
                }
              }

              return filtered.isEmpty
                  ? const Center(child: Text('Nenhuma entrega em andamento.'))
                  : ListView.builder(
                      controller: _entregasScrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        // Ensure a key exists for this delivery so we can scroll to it
                        _deliveryKeys.putIfAbsent(d.id, () => GlobalKey());
                        return Container(
                          key: _deliveryKeys[d.id],
                          child: _buildDeliveryCard(
                            context,
                            d,
                            expanded: _expandedDeliveryIds.contains(d.id),
                          ),
                        );
                      },
                    );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FloatingActionButton.extended(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AddDeliveryModal(
                  ordersBox: _ordersBox,
                  deliveriesBox: _deliveriesBox,
                  driversBox: _driversBox,
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Entrega'),
          ),
        ),
      ],
    );
  }

  // ===== FINALIZADAS TAB =====
  Widget _buildFinalizadasTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _finalizadasSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por ID, motorista ou nota',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          setState(() => _finalizadasSearchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _finalizadasFilterDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _finalizadasFilterDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _finalizadasFilterDate == null
                          ? 'Todos'
                          : DateFormat(
                              'dd/MM/yyyy',
                            ).format(_finalizadasFilterDate!),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Limpar filtro de data',
                    onPressed: () =>
                        setState(() => _finalizadasFilterDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Box<DeliveryModel>>(
            valueListenable: _deliveriesBox.listenable(),
            builder: (context, box, _) {
              final deliveries = box.values
                  .toList()
                  .cast<DeliveryModel>()
                  .where(
                    (d) => d.status == 'delivered' || d.status == 'cancelled',
                  )
                  .toList();

              final q = _finalizadasSearchQuery.toLowerCase();
              final filtered = deliveries.where((d) {
                final matchesId = d.id.toLowerCase().contains(q);
                final driver = d.driverId != null
                    ? _driversBox.get(d.driverId)
                    : null;
                final matchesDriver =
                    driver?.name.toLowerCase().contains(q) ?? false;

                // match associated orders (order number or responsible)
                bool matchesOrder = false;
                for (final oid in d.orderIds) {
                  final order = _ordersBox.get(oid);
                  if (order != null) {
                    if (order.orderNumber.toLowerCase().contains(q) ||
                        order.responsible.toLowerCase().contains(q)) {
                      matchesOrder = true;
                      break;
                    }
                  }
                }

                // Filter by selected finishedAt date if set
                if (_finalizadasFilterDate != null) {
                  final f = DateTime.tryParse(d.finishedAt ?? '');
                  if (f == null) return false;
                  final fd = _finalizadasFilterDate!;
                  if (!(f.year == fd.year &&
                      f.month == fd.month &&
                      f.day == fd.day)) {
                    return false;
                  }
                }

                return matchesId || matchesDriver || matchesOrder;
              }).toList();

              return filtered.isEmpty
                  ? const Center(child: Text('Nenhuma entrega finalizada.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        return _buildDeliveryCard(context, d);
                      },
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(
    BuildContext context,
    DeliveryModel d, {
    bool expanded = false,
  }) {
    final statusColor = _getStatusColor(d.status);
    final driver = d.driverId != null ? _driversBox.get(d.driverId) : null;

    // Calcular tempo de entrega: de dispatchedAt até finishedAt
    String elapsedTime = '—';
    try {
      if (d.dispatchedAt != null) {
        final startDt = DateTime.tryParse(d.dispatchedAt!);
        if (startDt != null) {
          final endDt = d.finishedAt != null
              ? DateTime.tryParse(d.finishedAt!) ?? DateTime.now()
              : DateTime.now();
          final dur = endDt.difference(startDt);
          if (dur.inDays > 0) {
            elapsedTime = '${dur.inDays}d ${dur.inHours % 24}h';
          } else if (dur.inHours > 0) {
            elapsedTime = '${dur.inHours}h ${dur.inMinutes % 60}m';
          } else {
            elapsedTime = '${dur.inMinutes}m';
          }
        }
      }
    } catch (_) {
      elapsedTime = '—';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Entrega #${d.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(_translateStatus(d.status)),
              backgroundColor: statusColor,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        subtitle: Text(
          'Criado: ${_formatDate(d.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Orders in delivery
                _buildDeliveryOrders(d),
                const Divider(),
                // Timeline
                _buildTimelineSection(d, elapsedTime),
                const Divider(),
                // Driver
                _buildDriverInfo(d, driver),
                const Divider(),
                // Actions
                _buildActionButtons(context, d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOrders(DeliveryModel d) {
    if (d.orderIds.isEmpty) {
      return const Text(
        'Sem notas',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notas:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...d.orderIds.map((orderId) {
          final order = _ordersBox.get(orderId);
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '• Nota #${order?.orderNumber ?? orderId} - ${order?.responsible ?? "—"}',
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimelineSection(DeliveryModel d, String elapsedTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Timeline:', style: TextStyle(fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📋 Criado: ${_formatDate(d.createdAt)}'),
              if (d.dispatchedAt != null) ...[
                Text(
                  '🚚 Saiu: ${_formatDate(d.dispatchedAt)}',
                  style: const TextStyle(color: Colors.blue),
                ),
                Text(
                  '⏱ Tempo desde a saída: $elapsedTime',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
              if (d.finishedAt != null)
                Text(
                  '✅ Finalizado: ${_formatDate(d.finishedAt)}',
                  style: const TextStyle(color: Colors.green),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfo(DeliveryModel d, DriverModel? driver) {
    // Show driver details when the card is expanded (always inside children)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Motorista:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (driver != null)
          Text('👤 ${driver.name}')
        else
          const Text(
            'Não atribuído',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DeliveryModel d) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (d.status == 'pending')
          ElevatedButton.icon(
            onPressed: () => _showAssignDriverDialog(d),
            icon: const Icon(Icons.person_add),
            label: const Text('Atribuir Motorista'),
          ),
        if (d.status == 'assigned' && d.driverId != null)
          ElevatedButton.icon(
            onPressed: () => _dispatchDelivery(d),
            icon: const Icon(Icons.send),
            label: const Text('Despachar'),
          ),
        if (d.status == 'dispatched')
          ElevatedButton.icon(
            onPressed: () => _finishDelivery(d),
            icon: const Icon(Icons.check_circle),
            label: const Text('Finalizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        if (d.status != 'delivered' && d.status != 'cancelled')
          OutlinedButton.icon(
            onPressed: () => _cancelDelivery(d),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancelar'),
          ),
      ],
    );
  }

  void _showAssignDriverDialog(DeliveryModel delivery) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AssignDriverModal(delivery: delivery, driversBox: _driversBox),
    );
  }

  void _dispatchDelivery(DeliveryModel d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Despachar Entrega'),
        content: const Text('Confirmar saída para entrega?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              d.dispatchedAt = DateTime.now().toIso8601String();
              d.status = 'dispatched';
              d.save();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrega despachada com sucesso!'),
                ),
              );
              if (mounted) setState(() {});
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _finishDelivery(DeliveryModel d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Entrega'),
        content: const Text('Confirmar entrega como concluída?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              d.finishedAt = DateTime.now().toIso8601String();
              d.status = 'delivered';
              d.save();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrega finalizada com sucesso!'),
                ),
              );
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _cancelDelivery(DeliveryModel d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Entrega'),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              d.status = 'cancelled';
              d.save();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Entrega cancelada')),
              );
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar Entrega'),
          ),
        ],
      ),
    );
  }
}

// ===== MODALS AT TOP LEVEL =====

/// Modal para adicionar nova nota
class AddOrderModal extends StatefulWidget {
  final Box<OrderModel> box;
  const AddOrderModal({super.key, required this.box});

  @override
  State<AddOrderModal> createState() => _AddOrderModalState();
}

class _AddOrderModalState extends State<AddOrderModal> {
  final _formKey = GlobalKey<FormState>();
  String _orderNumber = '';
  String _responsible = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Pedido'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Número do Pedido'),
              onChanged: (v) => _orderNumber = v,
              validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Responsável'),
              onChanged: (v) => _responsible = v,
              validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Check for duplicate note number
    OrderModel? existing;
    try {
      existing = widget.box.values.cast<OrderModel>().firstWhere(
        (o) => o.orderNumber == _orderNumber,
      );
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nota Duplicada'),
          content: Text(
            'Já existe uma nota com o número $_orderNumber. Deseja continuar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _doSave();
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    } else {
      _doSave();
    }
  }

  void _doSave() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final order = OrderModel.create(
      id: id,
      orderNumber: _orderNumber,
      responsible: _responsible,
    );
    widget.box.put(id, order);
    Navigator.of(context).pop(id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Nota criada com sucesso!')));
  }
}

/// Modal para editar pedido
class EditOrderModal extends StatefulWidget {
  final OrderModel order;
  const EditOrderModal({super.key, required this.order});

  @override
  State<EditOrderModal> createState() => _EditOrderModalState();
}

class _EditOrderModalState extends State<EditOrderModal> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _responsibleCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(text: widget.order.orderNumber);
    _responsibleCtrl = TextEditingController(text: widget.order.responsible);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _responsibleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Nota'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _numberCtrl,
              decoration: const InputDecoration(labelText: 'Número da Nota'),
              validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responsibleCtrl,
              decoration: const InputDecoration(labelText: 'Responsável'),
              validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.order.orderNumber = _numberCtrl.text;
    widget.order.responsible = _responsibleCtrl.text;
    widget.order.save();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nota atualizada com sucesso!')),
    );
  }
}

/// Modal para gerenciar motoristas (não mais uma aba)
class MotorizestsModal extends StatefulWidget {
  final Box<DriverModel> box;
  const MotorizestsModal({super.key, required this.box});

  @override
  State<MotorizestsModal> createState() => _MotorizestModalState();
}

class _MotorizestModalState extends State<MotorizestsModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Motoristas'),
          automaticallyImplyLeading: true,
        ),
        body: ValueListenableBuilder<Box<DriverModel>>(
          valueListenable: widget.box.listenable(),
          builder: (context, box, _) {
            final drivers = box.values.toList().cast<DriverModel>();
            return drivers.isEmpty
                ? const Center(child: Text('Nenhum motorista cadastrado.'))
                : ListView.builder(
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text('👤 ${driver.name}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => _handleDriverAction(v, driver),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Deletar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDriverDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Adicionar'),
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddDriverModal(box: widget.box),
    );
  }

  void _handleDriverAction(String action, DriverModel driver) {
    if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deletar Motorista'),
          content: const Text('Tem certeza que deseja deletar este motorista?'),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                driver.delete();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deletar'),
            ),
          ],
        ),
      );
    }
  }
}

/// Modal para adicionar motorista
class AddDriverModal extends StatefulWidget {
  final Box<DriverModel> box;
  const AddDriverModal({super.key, required this.box});

  @override
  State<AddDriverModal> createState() => _AddDriverModalState();
}

class _AddDriverModalState extends State<AddDriverModal> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Motorista'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          decoration: const InputDecoration(labelText: 'Nome'),
          onChanged: (v) => _name = v,
          validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final driver = DriverModel.create(id: id, name: _name);
    widget.box.put(id, driver);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Motorista cadastrado com sucesso!')),
    );
  }
}

/// Modal para atribuir motorista
class AssignDriverModal extends StatefulWidget {
  final DeliveryModel delivery;
  final Box<DriverModel> driversBox;
  const AssignDriverModal({
    super.key,
    required this.delivery,
    required this.driversBox,
  });

  @override
  State<AssignDriverModal> createState() => _AssignDriverModalState();
}

class _AssignDriverModalState extends State<AssignDriverModal> {
  String? _selectedDriverId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atribuir Motorista'),
      content: ValueListenableBuilder<Box<DriverModel>>(
        valueListenable: widget.driversBox.listenable(),
        builder: (context, box, _) {
          final drivers = box.values.toList().cast<DriverModel>();
          if (drivers.isEmpty) {
            return const Text('Nenhum motorista cadastrado.');
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...drivers.map((driver) {
                  final selected = _selectedDriverId == driver.id;
                  return ListTile(
                    title: Text(driver.name),
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onTap: () => setState(() => _selectedDriverId = driver.id),
                  );
                }),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedDriverId == null ? null : _save,
          child: const Text('Atribuir'),
        ),
      ],
    );
  }

  void _save() {
    if (_selectedDriverId == null) return;
    widget.delivery.driverId = _selectedDriverId;
    widget.delivery.status = 'assigned';
    widget.delivery.save();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Motorista atribuído com sucesso!')),
    );
  }
}

/// Modal para adicionar entrega
class AddDeliveryModal extends StatefulWidget {
  final Box<OrderModel> ordersBox;
  final Box<DeliveryModel> deliveriesBox;
  final Box<DriverModel> driversBox;
  const AddDeliveryModal({
    super.key,
    required this.ordersBox,
    required this.deliveriesBox,
    required this.driversBox,
  });

  @override
  State<AddDeliveryModal> createState() => _AddDeliveryModalState();
}

class _AddDeliveryModalState extends State<AddDeliveryModal> {
  final List<String> _selectedOrderIds = [];
  String? _selectedDriverId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Entrega'),
      content: ValueListenableBuilder<Box<OrderModel>>(
        valueListenable: widget.ordersBox.listenable(),
        builder: (context, box, _) {
          final orders = box.values.toList().cast<OrderModel>();
          // Get all order IDs that are already assigned to deliveries
          final deliveries = widget.deliveriesBox.values
              .toList()
              .cast<DeliveryModel>();
          final usedOrderIds = <String>{};
          for (final d in deliveries) {
            usedOrderIds.addAll(d.orderIds);
          }
          // Filter: only show orders that are not already assigned
          final availableOrders = orders
              .where((o) => !usedOrderIds.contains(o.id))
              .toList();
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecione as notas:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (availableOrders.isEmpty) ...[
                  const Text(
                    'Nenhuma nota disponível. Você pode criar uma nova nota abaixo.',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final newId = await showDialog<String?>(
                        context: context,
                        builder: (ctx) => AddOrderModal(box: widget.ordersBox),
                      );
                      if (newId != null) {
                        setState(() {
                          _selectedOrderIds.add(newId);
                        });
                      }
                    },
                    child: const Text('Criar nova nota'),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  ...availableOrders.map(
                    (order) => CheckboxListTile(
                      title: Text('Nota #${order.orderNumber}'),
                      subtitle: Text(order.responsible),
                      value: _selectedOrderIds.contains(order.id),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selectedOrderIds.add(order.id);
                        } else {
                          _selectedOrderIds.remove(order.id);
                        }
                      }),
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final newId = await showDialog<String?>(
                          context: context,
                          builder: (ctx) =>
                              AddOrderModal(box: widget.ordersBox),
                        );
                        if (newId != null) {
                          setState(() {
                            _selectedOrderIds.add(newId);
                          });
                        }
                      },
                      child: const Text('Criar nova nota'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Motorista (obrigatório):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Box<DriverModel>>(
                  valueListenable: widget.driversBox.listenable(),
                  builder: (context, dbox, _) {
                    final drivers = dbox.values.toList().cast<DriverModel>();
                    if (drivers.isEmpty) {
                      return Row(
                        children: [
                          const Expanded(
                            child: Text('Nenhum motorista cadastrado.'),
                          ),
                          TextButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (ctx) =>
                                  MotorizestsModal(box: widget.driversBox),
                            ),
                            child: const Text('Cadastrar'),
                          ),
                        ],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...drivers.map((drv) {
                          final selected = _selectedDriverId == drv.id;
                          return RadioListTile<String?>(
                            value: drv.id,
                            groupValue: _selectedDriverId,
                            title: Text(drv.name),
                            onChanged: (v) =>
                                setState(() => _selectedDriverId = v),
                            selected: selected,
                          );
                        }),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (ctx) =>
                                  MotorizestsModal(box: widget.driversBox),
                            ),
                            child: const Text('Gerenciar motoristas'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_selectedOrderIds.isEmpty || _selectedDriverId == null)
              ? null
              : _save,
          child: const Text('Criar Entrega'),
        ),
      ],
    );
  }

  void _save() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final delivery = DeliveryModel.create(id: id, orderIds: _selectedOrderIds);
    // Driver is required now — set driver and mark as assigned
    delivery.driverId = _selectedDriverId;
    delivery.status = 'assigned';
    widget.deliveriesBox.put(id, delivery);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrega criada com sucesso!')),
    );
  }
}
