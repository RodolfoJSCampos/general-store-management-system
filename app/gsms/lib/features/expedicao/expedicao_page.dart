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
  String? _navigateToDeliveryId;

  // Search/filter state
  String _notasSearchQuery = '';
  String _notasStatusFilter = 'Sem entrega';
  DateTime? _notasFilterDate;
  String _emEntregaSearchQuery = '';
  String _entregasStatusFilter = 'Todos';
  DateTime? _entregasFilterDate;
  String _finalizadasSearchQuery = '';
  DateTime? _finalizadasFilterDate = DateTime.now();

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Search bar compacto - expandido
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar nota ou responsável...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _notasSearchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter - dropdown customizado tipo Gmail
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                ),
                child: PopupMenuButton<String>(
                  initialValue: _notasStatusFilter,
                  onSelected: (v) => setState(() => _notasStatusFilter = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'Sem entrega',
                      child: Text('Sem entrega'),
                    ),
                    const PopupMenuItem(
                      value: 'Aguardando Envio',
                      child: Text('Aguardando Envio'),
                    ),
                    const PopupMenuItem(
                      value: 'Em Entrega',
                      child: Text('Em Entrega'),
                    ),
                    const PopupMenuItem(
                      value: 'Finalizado',
                      child: Text('Finalizado'),
                    ),
                    const PopupMenuItem(
                      value: 'Cancelado',
                      child: Text('Cancelado'),
                    ),
                    const PopupMenuItem(value: 'Todas', child: Text('Todas')),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _notasStatusFilter == 'Aguardando Envio'
                              ? 'Aguardando'
                              : _notasStatusFilter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date filter chip
              FilterChip(
                label: Text(
                  _notasFilterDate == null
                      ? 'Data'
                      : DateFormat('dd/MM').format(_notasFilterDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _notasFilterDate != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                selected: _notasFilterDate != null,
                onSelected: (selected) async {
                  if (!selected) {
                    setState(() => _notasFilterDate = null);
                  } else {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _notasFilterDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _notasFilterDate = picked);
                    }
                  }
                },
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                avatar: _notasFilterDate != null
                    ? Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                showCheckmark: false,
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
              // Filter: search query + status filter + date filter
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

                // Apply date filter
                bool matchesDateFilter = true;
                if (_notasFilterDate != null) {
                  final orderDate = DateTime.tryParse(o.createdAt);
                  if (orderDate == null) {
                    matchesDateFilter = false;
                  } else {
                    final fd = _notasFilterDate!;
                    matchesDateFilter =
                        orderDate.year == fd.year &&
                        orderDate.month == fd.month &&
                        orderDate.day == fd.day;
                  }
                }

                return matchesSearch &&
                    matchesStatusFilter &&
                    matchesDateFilter;
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order.responsible,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status chip movido para o trailing junto aos botões
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, left: 34),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 11, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _formatDate(order.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        trailing: Builder(
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

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    chipLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: associatedDelivery != null
                      ? 'Rastrear Entrega'
                      : 'Enviar nota',
                  icon: Icon(
                    associatedDelivery != null
                        ? Icons.my_location
                        : Icons.local_shipping_outlined,
                    size: 22,
                    color: associatedDelivery != null
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    if (associatedDelivery == null) {
                      // Muda para aba de entregas
                      _tabController.animateTo(1); // Aba Em Entrega
                      // Usa addPostFrameCallback para abrir o modal após a animação
                      // sem async gap - assim o context continua válido
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialog(
                          context: context,
                          builder: (dctx) => AddDeliveryModal(
                            ordersBox: _ordersBox,
                            deliveriesBox: _deliveriesBox,
                            driversBox: _driversBox,
                            preSelectedOrderId: order.id,
                          ),
                        );
                      });
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
                                } else {
                                  _tabController.index = 1; // Aba Em Entrega
                                }
                              });
                            },
                            child: const Text('Ver entrega'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'detalhes',
                      child: Text('Ver detalhes'),
                    ),
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir nota'),
                    ),
                  ],
                  onSelected: (value) {
                    // ...existing code...
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== EM ENTREGA TAB =====
  Widget _buildEmEntregaTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Search bar compacto - expandido
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _emEntregaSearchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ID, motorista ou nota...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _emEntregaSearchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter - dropdown customizado tipo Gmail
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                ),
                child: PopupMenuButton<String>(
                  initialValue: _entregasStatusFilter,
                  onSelected: (v) => setState(() => _entregasStatusFilter = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Todos', child: Text('Todos')),
                    const PopupMenuItem(
                      value: 'Aguardando envio',
                      child: Text('Aguardando envio'),
                    ),
                    const PopupMenuItem(
                      value: 'Em Entrega',
                      child: Text('Em Entrega'),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _entregasStatusFilter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date filter chip
              FilterChip(
                label: Text(
                  _entregasFilterDate == null
                      ? 'Data criação'
                      : DateFormat('dd/MM').format(_entregasFilterDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _entregasFilterDate != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                selected: _entregasFilterDate != null,
                onSelected: (selected) async {
                  if (!selected) {
                    setState(() => _entregasFilterDate = null);
                  } else {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _entregasFilterDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _entregasFilterDate = picked);
                    }
                  }
                },
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                avatar: _entregasFilterDate != null
                    ? Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                showCheckmark: false,
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

              // Apply status filter from dropdown: 'Todos' / 'Aguardando envio' / 'Em Entrega'
              if (_entregasStatusFilter == 'Aguardando envio') {
                deliveries = deliveries
                    .where((d) => d.status == 'assigned')
                    .toList();
              } else if (_entregasStatusFilter == 'Em Entrega') {
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

                // Apply date filter (based on createdAt)
                bool matchesDateFilter = true;
                if (_entregasFilterDate != null) {
                  final deliveryDate = DateTime.tryParse(d.createdAt);
                  if (deliveryDate == null) {
                    matchesDateFilter = false;
                  } else {
                    final fd = _entregasFilterDate!;
                    matchesDateFilter =
                        deliveryDate.year == fd.year &&
                        deliveryDate.month == fd.month &&
                        deliveryDate.day == fd.day;
                  }
                }

                return (matchesId || matchesDriver || matchesOrder) &&
                    matchesDateFilter;
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
              // scroll to it and open the modal after this frame
              if (_navigateToDeliveryId != null) {
                final idx = filtered.indexWhere(
                  (e) => e.id == _navigateToDeliveryId,
                );
                if (idx != -1) {
                  final targetDelivery = filtered[idx];
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToAndShowDelivery(targetDelivery);
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
                          child: _buildDeliveryCard(context, d),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Search bar compacto - expandido
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _finalizadasSearchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ID, motorista ou nota...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _finalizadasSearchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              // Date filter chip
              FilterChip(
                label: Text(
                  _finalizadasFilterDate == null
                      ? 'Data finalização'
                      : DateFormat('dd/MM').format(_finalizadasFilterDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _finalizadasFilterDate != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                selected: _finalizadasFilterDate != null,
                onSelected: (selected) async {
                  if (!selected) {
                    setState(() => _finalizadasFilterDate = null);
                  } else {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _finalizadasFilterDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _finalizadasFilterDate = picked);
                    }
                  }
                },
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                avatar: _finalizadasFilterDate != null
                    ? Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                showCheckmark: false,
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

  Widget _buildDeliveryCard(BuildContext context, DeliveryModel d) {
    final statusColor = _getStatusColor(d.status);
    final driver = d.driverId != null ? _driversBox.get(d.driverId) : null;

    // Calcular tempo de entrega: de dispatchedAt até finishedAt
    String elapsedTime = '—';
    Color timeColor = Colors.grey;
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
            timeColor = Colors.red;
          } else if (dur.inHours > 0) {
            elapsedTime = '${dur.inHours}h ${dur.inMinutes % 60}m';
            timeColor = dur.inHours > 2 ? Colors.orange : Colors.blue;
          } else {
            elapsedTime = '${dur.inMinutes}m';
            timeColor = Colors.green;
          }
        }
      }
    } catch (_) {
      elapsedTime = '—';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => _showDeliveryDetailsModal(
          context,
          d,
          driver,
          elapsedTime,
          timeColor,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            d.status == 'delivered' ? Icons.check_circle : Icons.local_shipping,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrega #${d.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (driver != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          driver.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.dispatchedAt != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: timeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: timeColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 12,
                              color: timeColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              elapsedTime,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: timeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _translateStatus(d.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 11, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Criado: ${_formatDate(d.createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }

  void _showDeliveryDetailsModal(
    BuildContext context,
    DeliveryModel d,
    DriverModel? driver,
    String elapsedTime,
    Color timeColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(d.status).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(d.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        d.status == 'delivered'
                            ? Icons.check_circle
                            : Icons.local_shipping,
                        color: _getStatusColor(d.status),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entrega #${d.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(d.status),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _translateStatus(d.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimelineSection(d, elapsedTime),
                      const Divider(height: 24),
                      _buildDeliveryOrders(d),
                      const Divider(height: 24),
                      _buildDriverInfo(d, driver),
                    ],
                  ),
                ),
              ),
              // Action Buttons - Always visible
              _buildActionButtons(context, d),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryOrders(DeliveryModel d) {
    if (d.orderIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            const Text(
              'Sem notas associadas',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, size: 18, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text(
              'Notas:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${d.orderIds.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...d.orderIds.map((orderId) {
          final order = _ordersBox.get(orderId);
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.tag, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nota #${order?.orderNumber ?? orderId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      if (order?.responsible != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          order!.responsible,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  Future<void> _scrollToAndShowDelivery(DeliveryModel targetDelivery) async {
    final key = _deliveryKeys[targetDelivery.id];
    if (key?.currentContext == null) {
      if (mounted) setState(() => _navigateToDeliveryId = null);
      return;
    }

    await Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      alignment: 0.1,
    );

    if (!mounted) return;

    final driver = targetDelivery.driverId != null
        ? _driversBox.get(targetDelivery.driverId)
        : null;
    String elapsedTime = '—';
    Color timeColor = Colors.grey;
    if (targetDelivery.dispatchedAt != null) {
      final startDt = DateTime.tryParse(targetDelivery.dispatchedAt!);
      if (startDt != null) {
        final endDt = targetDelivery.finishedAt != null
            ? DateTime.tryParse(targetDelivery.finishedAt!) ?? DateTime.now()
            : DateTime.now();
        final dur = endDt.difference(startDt);
        if (dur.inDays > 0) {
          elapsedTime = '${dur.inDays}d ${dur.inHours % 24}h';
          timeColor = Colors.red;
        } else if (dur.inHours > 0) {
          elapsedTime = '${dur.inHours}h ${dur.inMinutes % 60}m';
          timeColor = dur.inHours > 2 ? Colors.orange : Colors.blue;
        } else {
          elapsedTime = '${dur.inMinutes}m';
          timeColor = Colors.green;
        }
      }
    }

    _showDeliveryDetailsModal(
      context,
      targetDelivery,
      driver,
      elapsedTime,
      timeColor,
    );

    if (mounted) {
      setState(() => _navigateToDeliveryId = null);
    }
  }

  Widget _buildDriverInfo(DeliveryModel d, DriverModel? driver) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text(
              'Motorista:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: driver != null
                  ? [Colors.green[700]!, Colors.green[600]!]
                  : [Colors.grey[600]!, Colors.grey[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (driver != null ? Colors.green : Colors.grey)
                    .withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  driver != null ? Icons.person : Icons.person_off_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver?.name ?? 'Não atribuído',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: driver != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: Colors.white,
                    fontStyle: driver == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DeliveryModel d) {
    final theme = Theme.of(context);

    // Lista de ações disponíveis
    final List<Widget> actions = [];

    // Ação secundária de cancelamento (primeiro para ficar à esquerda)
    if (d.status != 'delivered' && d.status != 'cancelled') {
      actions.add(
        TextButton.icon(
          onPressed: () => _cancelDelivery(d),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancelar Entrega'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    // Ação principal baseada no status (segundo para ficar à direita)
    if (d.status == 'pending') {
      actions.add(
        FilledButton.icon(
          onPressed: () => _showAssignDriverDialog(d),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Atribuir Motorista'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    } else if (d.status == 'assigned' && d.driverId != null) {
      actions.add(
        FilledButton.icon(
          onPressed: () => _dispatchDelivery(d),
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text('Despachar'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    } else if (d.status == 'dispatched') {
      actions.add(
        FilledButton.icon(
          onPressed: () => _finishDelivery(d),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Finalizar Entrega'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: actions.length == 1
            ? SizedBox(width: double.infinity, child: actions.first)
            : Row(
                children: [
                  Expanded(child: actions.first),
                  if (actions.length > 1) ...[
                    const SizedBox(width: 12),
                    Expanded(child: actions[1]),
                  ],
                ],
              ),
      ),
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
  final String? preSelectedOrderId;
  const AddDeliveryModal({
    super.key,
    required this.ordersBox,
    required this.deliveriesBox,
    required this.driversBox,
    this.preSelectedOrderId,
  });

  @override
  State<AddDeliveryModal> createState() => _AddDeliveryModalState();
}

class _AddDeliveryModalState extends State<AddDeliveryModal> {
  final List<String> _selectedOrderIds = [];
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedOrderId != null) {
      _selectedOrderIds.add(widget.preSelectedOrderId!);
    }
  }

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
