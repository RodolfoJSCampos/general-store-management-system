import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'domain/models/delivery_model.dart';
import 'domain/models/driver_model.dart';
import 'domain/models/order_model.dart';
import 'domain/models/seller_model.dart';

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
  late Box<SellerModel> _sellersBox;
  late Box _settingsBox;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  late TabController _tabController;
  late Timer _timer;
  late ScrollController _entregasScrollController;
  late TextEditingController _notasSearchController;
  late TextEditingController _emEntregaSearchController;
  late TextEditingController _finalizadasSearchController;
  final Map<String, GlobalKey> _deliveryKeys = {};
  String? _navigateToDeliveryId;
  bool _isShowingDeliveryModal = false;
  int _navigationCallbackVersion = 0; // Para rastrear callbacks obsoletos

  // Search/filter state
  String _notasSearchQuery = '';
  String _notasStatusFilter = 'Sem entrega';
  DateTime? _notasFilterDate;
  String _emEntregaSearchQuery = '';
  String _entregasStatusFilter = 'Todos';
  DateTime? _entregasFilterDate;
  String _finalizadasSearchQuery = '';
  DateTime? _finalizadasFilterDate = DateTime.now();
  bool _useGridView = false; // Novo: controlar visualização lista/grid

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

  /// Formata o tempo que está em entrega
  /// Retorna algo como "45 min em entrega" ou "2h 30m em entrega"
  String? _formatDeliveryElapsedTime(DeliveryModel delivery) {
    if (delivery.dispatchedAt == null || delivery.dispatchedAt!.isEmpty) {
      return null;
    }

    try {
      final dispatchedDt = DateTime.tryParse(delivery.dispatchedAt!);
      if (dispatchedDt == null) return null;

      final now = DateTime.now();
      final duration = now.difference(dispatchedDt);

      if (duration.inDays > 0) {
        return '${duration.inDays}d ${duration.inHours % 24}h em entrega';
      } else if (duration.inHours > 0) {
        return '${duration.inHours}h ${duration.inMinutes % 60}m em entrega';
      } else {
        return '${duration.inMinutes}m em entrega';
      }
    } catch (_) {
      return null;
    }
  }

  /// Formata a informação de previsão de entrega
  /// Retorna algo como "Hoje • Manhã" ou "Amanhã • Tarde" ou "25/12 • Tarde"
  /// Se não houver previsão, retorna null
  String? _formatDeliveryForecast(DeliveryModel delivery) {
    if (delivery.deliveryForecastDate == null ||
        delivery.deliveryForecastPeriod == null) {
      return null;
    }

    try {
      final forecastDate = DateTime.parse(delivery.deliveryForecastDate!);
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // Normalizar datas para comparação (sem horas)
      final forecastNormalized = DateTime(
        forecastDate.year,
        forecastDate.month,
        forecastDate.day,
      );
      final todayNormalized = DateTime(today.year, today.month, today.day);
      final tomorrowNormalized = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      String dateStr;
      if (forecastNormalized == todayNormalized) {
        dateStr = 'Hoje';
      } else if (forecastNormalized == tomorrowNormalized) {
        dateStr = 'Amanhã';
      } else {
        dateStr = DateFormat('dd/MM').format(forecastDate);
      }

      final periodStr = delivery.deliveryForecastPeriod == 'manha'
          ? 'Manhã'
          : 'Tarde';

      return '$dateStr • $periodStr';
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _ordersBox = Hive.box<OrderModel>('orders');
    _deliveriesBox = Hive.box<DeliveryModel>('deliveries');
    _driversBox = Hive.box<DriverModel>('drivers');
    _sellersBox = Hive.box<SellerModel>('sellers');
    final savedViewPref = _settingsBox.get('expedicao_useGridView');
    if (savedViewPref is bool) {
      _useGridView = savedViewPref;
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _entregasScrollController = ScrollController();
    _notasSearchController = TextEditingController();
    _emEntregaSearchController = TextEditingController();
    _finalizadasSearchController = TextEditingController();

    // Garantir que os motoristas fixos estejam cadastrados
    _ensureDefaultDrivers();
    // Garantir que os vendedores fixos estejam cadastrados
    _ensureDefaultSellers();

    // Timer to refresh time display every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _ensureDefaultDrivers() {
    final defaultDrivers = [
      'Zezinho',
      'Edmar',
      'Antônio Carlos',
      'José Cardoso',
      'Welington',
      'Jailton',
      'Josimar',
      'Ronaldo',
      'Márcio',
      'Fábio',
    ];

    final existingNames = _driversBox.values
        .whereType<DriverModel>()
        .map((d) => d.name)
        .toSet();

    for (final name in defaultDrivers) {
      if (!existingNames.contains(name)) {
        final id = 'driver_${name.replaceAll(' ', '_').toLowerCase()}';
        final driver = DriverModel.create(id: id, name: name);
        _driversBox.put(id, driver);
      }
    }
  }

  void _ensureDefaultSellers() {
    final defaultSellers = [
      'Sabrina',
      'Ygor',
      'Wagner',
      'Duth',
      'Sávio',
      'Cristiano',
      'Veronica',
      'Clenilson',
      'Bernardo',
      'Jenifer',
      'Vinícius',
    ];

    final existingNames = _sellersBox.values
        .whereType<SellerModel>()
        .map((s) => s.name)
        .toSet();

    for (final name in defaultSellers) {
      if (!existingNames.contains(name)) {
        final id = 'seller_${name.replaceAll(' ', '_').toLowerCase()}';
        final seller = SellerModel.create(id: id, name: name);
        _sellersBox.put(id, seller);
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    _entregasScrollController.dispose();
    _notasSearchController.dispose();
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
            icon: Icon(_useGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _useGridView
                ? 'Visualizar em lista'
                : 'Visualizar em grade',
            onPressed: () {
              final newValue = !_useGridView;
              setState(() {
                _useGridView = newValue;
              });
              _settingsBox.put('expedicao_useGridView', newValue);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'drivers') {
                _showDriversManagement();
              } else if (value == 'sellers') {
                _showSellersManagement();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'drivers',
                child: Row(
                  children: [
                    Icon(Icons.local_shipping),
                    SizedBox(width: 12),
                    Text('Gerenciar Motoristas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sellers',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Gerenciar Vendedores'),
                  ],
                ),
              ),
            ],
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
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      AddOrderModal(box: _ordersBox, sellersBox: _sellersBox),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Nota'),
            )
          : _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddDeliveryModal(
                    ordersBox: _ordersBox,
                    deliveriesBox: _deliveriesBox,
                    driversBox: _driversBox,
                    sellersBox: _sellersBox,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Entrega'),
            )
          : null,
    );
  }

  void _showDriversManagement() {
    showDialog(
      context: context,
      builder: (ctx) => MotorizestsModal(box: _driversBox),
    );
  }

  void _showSellersManagement() {
    showDialog(
      context: context,
      builder: (ctx) => SellersModal(box: _sellersBox),
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
                  controller: _notasSearchController,
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
                      : DateFormat(
                          'dd/MM',
                        ).format(_notasFilterDate ?? DateTime.now()),
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
              final orders = box.values.whereType<OrderModel>().toList();
              // Get all order IDs that are already assigned to deliveries
              final deliveries = _deliveriesBox.values
                  .whereType<DeliveryModel>()
                  .toList();
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
                        .whereType<DeliveryModel>()
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
                        .whereType<DeliveryModel>()
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
                  : _useGridView
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 150,
                          ),
                      padding: const EdgeInsets.all(10),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return _buildOrderCard(context, order);
                      },
                    )
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
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Builder(
      builder: (ctx) {
        DeliveryModel? associatedDelivery;
        try {
          associatedDelivery = _deliveriesBox.values
              .whereType<DeliveryModel>()
              .firstWhere((d) => d.orderIds.contains(order.id));
        } catch (_) {
          associatedDelivery = null;
        }

        final chipColor = associatedDelivery != null
            ? _getStatusColor(associatedDelivery.status)
            : Colors.grey;

        // Versão diferentes para grid e lista
        if (_useGridView) {
          return Card(
            margin: const EdgeInsets.all(0),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: InkWell(
              onTap: () {
                if (associatedDelivery == null) {
                  _tabController.animateTo(1);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog(
                      context: context,
                      builder: (dctx) => AddDeliveryModal(
                        ordersBox: _ordersBox,
                        deliveriesBox: _deliveriesBox,
                        driversBox: _driversBox,
                        sellersBox: _sellersBox,
                        preSelectedOrderId: order.id,
                      ),
                    );
                  });
                } else {
                  final deliveryId = associatedDelivery.id;
                  final deliveryStatus = associatedDelivery.status;

                  setState(() {
                    _navigateToDeliveryId = deliveryId;
                    if (deliveryStatus == 'delivered' ||
                        deliveryStatus == 'cancelled') {
                      _finalizadasFilterDate = null;
                      _finalizadasSearchQuery = '';
                      _finalizadasSearchController.clear();
                      _tabController.index = 2;
                    } else {
                      // Reset filtros da aba "Em Entrega"
                      _emEntregaSearchQuery = '';
                      _emEntregaSearchController.clear();
                      _entregasStatusFilter = 'Todos';
                      _tabController.index = 1;
                    }
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Nota
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 16, color: chipColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nota #${order.orderNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: chipColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: chipColor.withOpacity(0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              associatedDelivery != null
                                  ? _translateStatus(associatedDelivery.status)
                                  : 'Sem entrega',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: chipColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Responsável
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 11,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.responsible,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Previsão de entrega (se aguardando)
                          if (associatedDelivery != null &&
                              (associatedDelivery.status == 'pending' ||
                                  associatedDelivery.status == 'assigned') &&
                              _formatDeliveryForecast(associatedDelivery) !=
                                  null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 13,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _formatDeliveryForecast(
                                      associatedDelivery,
                                    )!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Tempo de entrega (se em entrega)
                          if (associatedDelivery != null &&
                              associatedDelivery.status == 'dispatched' &&
                              _formatDeliveryElapsedTime(associatedDelivery) !=
                                  null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 13,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _formatDeliveryElapsedTime(
                                      associatedDelivery,
                                    )!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Data de finalização (se finalizado/cancelado)
                          if (associatedDelivery != null &&
                              (associatedDelivery.status == 'delivered' ||
                                  associatedDelivery.status == 'cancelled') &&
                              associatedDelivery.finishedAt != null &&
                              associatedDelivery.finishedAt!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color:
                                      associatedDelivery.status == 'delivered'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _formatDate(associatedDelivery.finishedAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          associatedDelivery.status ==
                                              'delivered'
                                          ? Colors.green
                                          : Colors.red,
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Spacer(),

                          // Data
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDate(order.createdAt),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Versão em lista (compacta e sem redundância)
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_long, color: chipColor, size: 20),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.responsible,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  // Previsão de entrega
                  if (associatedDelivery != null &&
                      (associatedDelivery.status == 'pending' ||
                          associatedDelivery.status == 'assigned') &&
                      _formatDeliveryForecast(associatedDelivery) != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Entrega: ${_formatDeliveryForecast(associatedDelivery)!}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Tempo de entrega (se em entrega)
                  if (associatedDelivery != null &&
                      associatedDelivery.status == 'dispatched' &&
                      _formatDeliveryElapsedTime(associatedDelivery) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 11, color: Colors.orange[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDeliveryElapsedTime(associatedDelivery)!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: Row(
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
                    associatedDelivery != null
                        ? _translateStatus(associatedDelivery.status)
                        : 'Sem entrega',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mostrar botão apenas se não é entrega finalizada/cancelada
                if (associatedDelivery == null ||
                    (associatedDelivery.status != 'delivered' &&
                        associatedDelivery.status != 'cancelled'))
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
                      try {
                        if (associatedDelivery == null) {
                          _tabController.animateTo(1);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showDialog(
                              context: context,
                              builder: (dctx) => AddDeliveryModal(
                                ordersBox: _ordersBox,
                                deliveriesBox: _deliveriesBox,
                                driversBox: _driversBox,
                                sellersBox: _sellersBox,
                                preSelectedOrderId: order.id,
                              ),
                            );
                          });
                          return;
                        }

                        // Validação crítica: verifica se a entrega ainda é válida
                        if (!_canShowDeliveryModal(associatedDelivery)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Esta entrega não está mais disponível',
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        // Captura dados críticos imediatamente
                        final deliveryId = associatedDelivery.id;
                        final deliveryStatus = associatedDelivery.status;

                        // Incrementa versão para invalidar callbacks antigos
                        _navigationCallbackVersion++;

                        setState(() {
                          _navigateToDeliveryId = deliveryId;
                          if (deliveryStatus == 'delivered' ||
                              deliveryStatus == 'cancelled') {
                            _finalizadasFilterDate = null;
                            _finalizadasSearchQuery = '';
                            _finalizadasSearchController.clear();
                            _tabController.index = 2;
                          } else {
                            // Reset filtros da aba "Em Entrega"
                            _emEntregaSearchQuery = '';
                            _emEntregaSearchController.clear();
                            _entregasStatusFilter = 'Todos';
                            _tabController.index = 1;
                          }
                        });
                      } catch (e, stack) {
                        debugPrint('Erro ao rastrear entrega: $e');
                        debugPrintStack(stackTrace: stack);
                      }
                    },
                  ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir nota'),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'editar') {
                      await showDialog(
                        context: context,
                        builder: (_) => EditOrderModal(order: order),
                      );
                      if (mounted) setState(() {});
                    } else if (value == 'excluir') {
                      await _confirmDeleteOrder(order, associatedDelivery);
                    }
                  },
                ),
              ],
            ),
            onTap: () => _showOrderDetailsDialog(order, associatedDelivery),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteOrder(
    OrderModel order,
    DeliveryModel? associatedDelivery,
  ) async {
    if (associatedDelivery != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Não é possível excluir'),
          content: const Text(
            'Remova a entrega vinculada antes de excluir esta nota.',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir nota'),
        content: Text(
          'Deseja excluir a nota #${order.orderNumber}? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _ordersBox.delete(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota excluída com sucesso')),
        );
        setState(() {});
      }
    }
  }

  void _showOrderDetailsDialog(
    OrderModel order,
    DeliveryModel? associatedDelivery,
  ) {
    // Captura dados críticos imediatamente para evitar que sejam zerados depois
    final deliveryId = associatedDelivery?.id;
    final deliveryStatus = associatedDelivery?.status;
    final deliveryDriverId = associatedDelivery?.driverId;
    final deliveryDispatchedAt = associatedDelivery?.dispatchedAt;
    final deliveryFinishedAt = associatedDelivery?.finishedAt;
    final deliveryTeamDriverIds = associatedDelivery?.teamDriverIds ?? [];
    final deliveryForecastDate = associatedDelivery?.deliveryForecastDate;
    final deliveryForecastPeriod = associatedDelivery?.deliveryForecastPeriod;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final statusColor = deliveryStatus != null
            ? _getStatusColor(deliveryStatus)
            : Colors.grey;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header com gradiente e ícone
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nota',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${order.orderNumber}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body com informações
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informações básicas da nota
                        _buildInfoCard(
                          theme: theme,
                          isDark: isDark,
                          title: 'Informações da Nota',
                          icon: Icons.info_outline_rounded,
                          iconColor: theme.colorScheme.primary,
                          children: [
                            _buildInfoRow(
                              theme: theme,
                              icon: Icons.person_outline_rounded,
                              label: 'Vendedor',
                              value: order.responsible,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              theme: theme,
                              icon: Icons.calendar_today_rounded,
                              label: 'Data de Criação',
                              value: _formatDate(order.createdAt),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Status da entrega (se houver)
                        if (associatedDelivery != null &&
                            deliveryId != null &&
                            deliveryStatus != null) ...[
                          _buildInfoCard(
                            theme: theme,
                            isDark: isDark,
                            title: 'Status da Entrega',
                            icon: Icons.local_shipping_outlined,
                            iconColor: statusColor,
                            children: [
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _translateStatus(deliveryStatus),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ID da entrega
                              _buildInfoRow(
                                theme: theme,
                                icon: Icons.tag_rounded,
                                label: 'ID da Entrega',
                                value:
                                    '#${deliveryId.substring(0, 8).toUpperCase()}',
                              ),

                              // Motorista(s)
                              if (deliveryDriverId != null) ...[
                                const SizedBox(height: 12),
                                if (deliveryTeamDriverIds.length > 1)
                                  _buildInfoRow(
                                    theme: theme,
                                    icon: Icons.groups_rounded,
                                    label: 'Equipe',
                                    value: deliveryTeamDriverIds.join(', '),
                                  )
                                else
                                  _buildInfoRow(
                                    theme: theme,
                                    icon: Icons.person_pin_circle_rounded,
                                    label: 'Motorista',
                                    value:
                                        _driversBox
                                            .get(deliveryDriverId)
                                            ?.name ??
                                        '—',
                                  ),
                              ],

                              // Previsão de entrega (se aguardando)
                              if ((deliveryStatus == 'pending' ||
                                      deliveryStatus == 'assigned') &&
                                  deliveryForecastDate != null &&
                                  deliveryForecastPeriod != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'Previsão de Entrega',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.event_available_rounded,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDeliveryForecast(
                                                    associatedDelivery,
                                                  ) ??
                                                  '—',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.blue,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Data e período estimados',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: Colors.blue
                                                        .withOpacity(0.7),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Timeline de datas
                              if (deliveryDispatchedAt != null ||
                                  deliveryFinishedAt != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'Linha do Tempo',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (deliveryDispatchedAt != null)
                                  _buildTimelineItem(
                                    theme: theme,
                                    icon: Icons.play_circle_outline_rounded,
                                    label: 'Despacho',
                                    value: _formatDate(deliveryDispatchedAt),
                                    color: Colors.orange,
                                  ),
                                if (deliveryFinishedAt != null) ...[
                                  const SizedBox(height: 8),
                                  _buildTimelineItem(
                                    theme: theme,
                                    icon: Icons.check_circle_outline_rounded,
                                    label: 'Finalização',
                                    value: _formatDate(deliveryFinishedAt),
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ] else if (associatedDelivery != null)
                          _buildInfoCard(
                            theme: theme,
                            isDark: isDark,
                            title: 'Atenção',
                            icon: Icons.warning_rounded,
                            iconColor: Colors.orange,
                            children: [
                              Text(
                                'Erro ao carregar dados da entrega. Tente novamente.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          )
                        else
                          _buildInfoCard(
                            theme: theme,
                            isDark: isDark,
                            title: 'Status da Entrega',
                            icon: Icons.info_outline_rounded,
                            iconColor: Colors.grey,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Esta nota ainda não foi vinculada a uma entrega',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer com ações
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerLow
                        : theme.colorScheme.surfaceContainerHighest.withOpacity(
                            0.5,
                          ),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botão Fechar
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Fechar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botão Enviar Nota (se não tiver entrega)
                      if (associatedDelivery == null)
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await showDialog(
                                context: context,
                                builder: (dctx) => AddDeliveryModal(
                                  ordersBox: _ordersBox,
                                  deliveriesBox: _deliveriesBox,
                                  driversBox: _driversBox,
                                  sellersBox: _sellersBox,
                                  preSelectedOrderId: order.id,
                                ),
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Enviar Nota'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      // Botão Rastrear Entrega (se houver)
                      else if (deliveryId != null &&
                          deliveryStatus != null) ...[
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () {
                              // Validação extra antes de navegar
                              if (!_canShowDeliveryModal(associatedDelivery)) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '❌ Esta entrega não está mais disponível',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(ctx).pop();
                              setState(() {
                                _navigateToDeliveryId = deliveryId;
                                if (deliveryStatus == 'delivered' ||
                                    deliveryStatus == 'cancelled') {
                                  _finalizadasFilterDate = null;
                                  _finalizadasSearchQuery = '';
                                  _finalizadasSearchController.clear();
                                  _tabController.index = 2;
                                } else {
                                  // Reset filtros da aba "Em Entrega"
                                  _emEntregaSearchQuery = '';
                                  _emEntregaSearchController.clear();
                                  _entregasStatusFilter = 'Todos';
                                  _tabController.index = 1;
                                }
                              });
                            },
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text('Rastrear Entrega'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper widgets para o modal de detalhes

  Widget _buildInfoCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
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
                      : DateFormat(
                          'dd/MM',
                        ).format(_entregasFilterDate ?? DateTime.now()),
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
                  .whereType<DeliveryModel>()
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

              // Sort: status (Aguardando Envio > Em Entrega). Within Aguardando,
              // prioritize nearer delivery forecast; within Em Entrega, keep newest first.
              filtered.sort((a, b) {
                int statusRank(String status) {
                  switch (status) {
                    case 'assigned':
                    case 'pending':
                      return 0; // Aguardando Envio
                    case 'dispatched':
                      return 1; // Em Entrega
                    default:
                      return 2; // Unknown/others last
                  }
                }

                int nullableDateCompare(DateTime? da, DateTime? db) {
                  if (da == null && db == null) return 0;
                  if (da == null) return 1; // nulls last
                  if (db == null) return -1;
                  return da.compareTo(db);
                }

                final statusComparison = statusRank(
                  a.status,
                ).compareTo(statusRank(b.status));
                if (statusComparison != 0) return statusComparison;

                // Inside Aguardando Envio: forecast date asc, period (manha before tarde), then createdAt asc
                if (statusRank(a.status) == 0) {
                  final fa = DateTime.tryParse(a.deliveryForecastDate ?? '');
                  final fb = DateTime.tryParse(b.deliveryForecastDate ?? '');
                  final forecastComparison = nullableDateCompare(fa, fb);
                  if (forecastComparison != 0) return forecastComparison;

                  int periodRank(String? period) {
                    switch (period) {
                      case 'manha':
                        return 0;
                      case 'tarde':
                        return 1;
                      default:
                        return 2; // sem período informado vai para o fim entre iguais
                    }
                  }

                  final periodComparison = periodRank(
                    a.deliveryForecastPeriod,
                  ).compareTo(periodRank(b.deliveryForecastPeriod));
                  if (periodComparison != 0) return periodComparison;

                  final ca =
                      DateTime.tryParse(a.createdAt) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final cb =
                      DateTime.tryParse(b.createdAt) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return ca.compareTo(
                    cb,
                  ); // older created first if everything else tied
                }

                // Inside Em Entrega: keep newest first
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
                final deliveryIdToNavigate = _navigateToDeliveryId;
                final idx = filtered.indexWhere(
                  (e) => e.id == deliveryIdToNavigate,
                );
                if (idx != -1) {
                  final targetDelivery = filtered[idx];
                  final callbackVersion = _navigationCallbackVersion;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Invalida callback se versão mudou (novo rastreio foi feito)
                    if (callbackVersion == _navigationCallbackVersion) {
                      _scrollToAndShowDelivery(targetDelivery);
                    } else {
                      debugPrint(
                        'Callback em entrega: versão obsoleta, cancelando',
                      );
                    }
                  });
                } else {
                  _navigateToDeliveryId = null;
                }
              }

              return filtered.isEmpty
                  ? const Center(child: Text('Nenhuma entrega em andamento.'))
                  : _useGridView
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 150,
                          ),
                      padding: const EdgeInsets.all(10),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        _deliveryKeys.putIfAbsent(d.id, () => GlobalKey());
                        return Container(
                          key: _deliveryKeys[d.id],
                          child: _buildDeliveryCard(context, d),
                        );
                      },
                    )
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
                      : DateFormat(
                          'dd/MM',
                        ).format(_finalizadasFilterDate ?? DateTime.now()),
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
                  .whereType<DeliveryModel>()
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
                  final fd = _finalizadasFilterDate;
                  if (fd == null ||
                      !(f.year == fd.year &&
                          f.month == fd.month &&
                          f.day == fd.day)) {
                    return false;
                  }
                }
                return matchesId || matchesDriver || matchesOrder;
              }).toList();

              return filtered.isEmpty
                  ? const Center(child: Text('Nenhuma entrega finalizada.'))
                  : Builder(
                      builder: (context) {
                        // Se alguém solicitou navegação para uma entrega específica,
                        // tenta abrir a modal após este frame
                        if (_navigateToDeliveryId != null) {
                          try {
                            final deliveryIdToNavigate = _navigateToDeliveryId;
                            final idx = filtered.indexWhere(
                              (e) => e.id == deliveryIdToNavigate,
                            );
                            if (idx != -1) {
                              final targetDelivery = filtered[idx];
                              final callbackVersion =
                                  _navigationCallbackVersion;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                try {
                                  // Invalida callback se versão mudou (novo rastreio foi feito)
                                  if (callbackVersion !=
                                      _navigationCallbackVersion) {
                                    debugPrint(
                                      'Callback finalizadas: versão obsoleta, cancelando',
                                    );
                                    return;
                                  }
                                  if (deliveryIdToNavigate ==
                                          targetDelivery.id &&
                                      mounted) {
                                    _navigateToDeliveryId = null;
                                    _scrollToAndShowDelivery(targetDelivery);
                                  }
                                } catch (e, stack) {
                                  debugPrint(
                                    'Erro ao abrir modal finalizadas: $e',
                                  );
                                  debugPrintStack(stackTrace: stack);
                                  _isShowingDeliveryModal = false;
                                  _navigateToDeliveryId = null;
                                }
                              });
                            } else {
                              _navigateToDeliveryId = null;
                            }
                          } catch (e, stack) {
                            debugPrint('Erro no callback finalizadas: $e');
                            debugPrintStack(stackTrace: stack);
                            _navigateToDeliveryId = null;
                          }
                        }

                        return _useGridView
                            ? GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 240,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 150,
                                    ),
                                padding: const EdgeInsets.all(10),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final d = filtered[index];
                                  _deliveryKeys.putIfAbsent(
                                    d.id,
                                    () => GlobalKey(),
                                  );
                                  return Container(
                                    key: _deliveryKeys[d.id],
                                    child: _buildDeliveryCard(context, d),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final d = filtered[index];
                                  _deliveryKeys.putIfAbsent(
                                    d.id,
                                    () => GlobalKey(),
                                  );
                                  return Container(
                                    key: _deliveryKeys[d.id],
                                    child: _buildDeliveryCard(context, d),
                                  );
                                },
                              );
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
      if (d.dispatchedAt?.isNotEmpty ?? false) {
        final startDt = DateTime.tryParse(d.dispatchedAt ?? '');
        if (startDt != null) {
          final endDt = (d.finishedAt?.isNotEmpty ?? false)
              ? DateTime.tryParse(d.finishedAt ?? '') ?? DateTime.now()
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

    // Cor fixa para tempo em entrega: usar a cor do chip "Em Entrega"
    if (d.status == 'dispatched') {
      timeColor = _getStatusColor('dispatched');
    }

    return Builder(
      builder: (context) {
        if (_useGridView) {
          // Grid view: Compact card design
          return Card(
            margin: const EdgeInsets.all(0),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: InkWell(
              onTap: () {
                if (_canShowDeliveryModal(d)) {
                  _showDeliveryDetailsModal(
                    context,
                    d,
                    driver,
                    elapsedTime,
                    timeColor,
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Entrega #${d.id.substring(0, 8)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _translateStatus(d.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Driver/Team info
                          if (d.teamDriverIds.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  d.teamDriverIds.length > 1
                                      ? Icons.group
                                      : Icons.person,
                                  size: 13,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    d.teamDriverIds.length > 1
                                        ? '${d.teamDriverIds.first} +${d.teamDriverIds.length - 1}'
                                        : d.teamDriverIds.first,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else if (driver != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 13,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    driver.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                          if (d.teamDriverIds.isNotEmpty || driver != null)
                            const SizedBox(height: 4),

                          // Tempo decorrido (if dispatched)
                          if (d.dispatchedAt != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: timeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  elapsedTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: timeColor,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),

                          // Previsão de entrega (if "Aguardando Envio")
                          if ((d.status == 'pending' ||
                                  d.status == 'assigned') &&
                              _formatDeliveryForecast(d) != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 13,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDeliveryForecast(d)!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                          // Data de finalização (if finalizado/cancelado)
                          if ((d.status == 'delivered' ||
                                  d.status == 'cancelled') &&
                              d.finishedAt != null &&
                              d.finishedAt!.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: d.status == 'delivered'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDate(d.finishedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: d.status == 'delivered'
                                        ? Colors.green
                                        : Colors.red,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                          const Spacer(),

                          // Data criação (footer)
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDate(d.createdAt),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // List view: Compacta e sem redundância
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              onTap: () {
                if (_canShowDeliveryModal(d)) {
                  _showDeliveryDetailsModal(
                    context,
                    d,
                    driver,
                    elapsedTime,
                    timeColor,
                  );
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  d.status == 'delivered'
                      ? Icons.check_circle
                      : Icons.local_shipping,
                  color: statusColor,
                  size: 20,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrega #${d.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (d.teamDriverIds.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          d.teamDriverIds.length > 1
                              ? Icons.group
                              : Icons.person,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.teamDriverIds.length > 1
                                ? '${d.teamDriverIds.first} +${d.teamDriverIds.length - 1}'
                                : d.teamDriverIds.first,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else if (driver != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            driver.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 11, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Criado: ${_formatDate(d.createdAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    // Previsão de entrega
                    if ((d.status == 'pending' || d.status == 'assigned') &&
                        _formatDeliveryForecast(d) != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 11,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Previsão: ${_formatDeliveryForecast(d)!}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Row(
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
                              fontSize: 9,
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
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  // Valida se uma entrega pode ser exibida em modal
  bool _canShowDeliveryModal(DeliveryModel? delivery) {
    if (delivery == null) {
      return false;
    }
    if (delivery.id.isEmpty) {
      return false;
    }
    // Verifica se a entrega ainda existe na Hive box
    final existsInBox = _deliveriesBox.get(delivery.id) != null;
    if (!existsInBox) {
      return false;
    }
    return true;
  }

  void _showDeliveryDetailsModal(
    BuildContext context,
    DeliveryModel d,
    DriverModel? driver,
    String elapsedTime,
    Color timeColor,
  ) {
    try {
      // Validação crítica: verifica se a entrega ainda é válida
      if (!_canShowDeliveryModal(d)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Esta entrega não está mais disponível'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // RE-BUSCA dados FRESCOS do Hive para garantir que não estão obsoletos
      final freshDelivery = _deliveriesBox.get(d.id);
      if (freshDelivery == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Entrega não encontrada'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // RE-BUSCA driver fresco também
      final freshDriver = freshDelivery.driverId != null
          ? _driversBox.get(freshDelivery.driverId)
          : null;

      // RE-CALCULA elapsedTime com dados frescos
      String freshElapsedTime = '—';
      try {
        if (freshDelivery.dispatchedAt?.isNotEmpty ?? false) {
          final startDt = DateTime.tryParse(freshDelivery.dispatchedAt ?? '');
          if (startDt != null) {
            final endDt = (freshDelivery.finishedAt?.isNotEmpty ?? false)
                ? DateTime.tryParse(freshDelivery.finishedAt ?? '') ??
                      DateTime.now()
                : DateTime.now();
            final dur = endDt.difference(startDt);
            if (dur.inDays > 0) {
              freshElapsedTime = '${dur.inDays}d ${dur.inHours % 24}h';
            } else if (dur.inHours > 0) {
              freshElapsedTime = '${dur.inHours}h ${dur.inMinutes % 60}m';
            } else {
              freshElapsedTime = '${dur.inMinutes}m';
            }
          }
        }
      } catch (_) {
        freshElapsedTime = '—';
      }

      if (_isShowingDeliveryModal) return;
      _isShowingDeliveryModal = true;

      // Timeout de segurança: reset flag após 10 segundos se algo der errado
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isShowingDeliveryModal) {
          _isShowingDeliveryModal = false;
        }
      });

      showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (dialogContext, setDialogState) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            freshDelivery.status,
                          ).withOpacity(0.1),
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
                                color: _getStatusColor(
                                  freshDelivery.status,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                freshDelivery.status == 'delivered'
                                    ? Icons.check_circle
                                    : Icons.local_shipping,
                                color: _getStatusColor(freshDelivery.status),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Entrega #${freshDelivery.id.substring(0, 8)}',
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
                                      color: _getStatusColor(
                                        freshDelivery.status,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _translateStatus(freshDelivery.status),
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
                              _buildTimelineSection(
                                freshDelivery,
                                freshElapsedTime,
                              ),
                              const Divider(height: 24),
                              _buildDeliveryOrdersWithCallback(
                                freshDelivery,
                                setDialogState,
                              ),
                              const Divider(height: 24),
                              _buildDriverInfoWithCallback(
                                freshDelivery,
                                freshDriver,
                                setDialogState,
                              ),
                              const Divider(height: 24),
                              _buildForecastInfoWithCallback(
                                freshDelivery,
                                setDialogState,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Action Buttons - Always visible
                      _buildActionButtons(
                        context,
                        freshDelivery,
                        setDialogState,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .then((_) {
            _isShowingDeliveryModal = false;
            _navigationCallbackVersion++; // Incrementa para invalidar callbacks antigos
          })
          .catchError((_) {
            _isShowingDeliveryModal = false;
            _navigationCallbackVersion++; // Incrementa mesmo em erro
          });
    } catch (e, stack) {
      debugPrint('Erro ao abrir modal de entrega: $e');
      debugPrintStack(stackTrace: stack);
      _isShowingDeliveryModal = false;
    }
  }

  Widget _buildDeliveryOrdersWithCallback(
    DeliveryModel d,
    void Function(void Function()) updateDialog,
  ) {
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
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Adicionar nota',
              onPressed: () => _showAddOrderToDeliveryDialog(d, updateDialog),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...d.orderIds.map((orderId) {
          try {
            final order = _ordersBox.get(orderId);
            // Se a ordem foi deletada, pula ela
            if (order == null) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.tag, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nota #${order.orderNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (order.responsible case String r
                            when r.isNotEmpty) ...[
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
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Remover nota da entrega',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remover Nota'),
                          content: Text(
                            'Tem certeza que deseja remover a nota #${order.orderNumber} desta entrega?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: Navigator.of(ctx).pop,
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                // Remove a nota da entrega
                                d.orderIds.remove(orderId);
                                d.save();
                                // Atualiza o dialog
                                updateDialog(() {});
                                if (mounted) setState(() {});
                              },
                              child: const Text('Remover'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          } catch (e, stack) {
            debugPrint('Erro ao renderizar nota $orderId: $e');
            debugPrintStack(stackTrace: stack);
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Erro ao carregar nota #$orderId',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildTimelineSection(DeliveryModel d, String elapsedTime) {
    // Converter strings de data para DateTime
    final createdDate = DateTime.tryParse(d.createdAt);
    final dispatchedDate = (d.dispatchedAt?.isNotEmpty ?? false)
        ? DateTime.tryParse(d.dispatchedAt ?? '')
        : null;
    final finishedDate = (d.finishedAt?.isNotEmpty ?? false)
        ? DateTime.tryParse(d.finishedAt ?? '')
        : null;

    // Definir cores por status
    Color getCurrentColor() {
      switch (d.status) {
        case 'pending':
          return Colors.grey;
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

    final currentColor = getCurrentColor();

    // Definir fases da entrega
    final phases = [
      {
        'status': 'pending',
        'label': 'Agendada',
        'icon': Icons.note_add,
        'date': createdDate,
      },
      {
        'status': 'dispatched',
        'label': 'Em Rota',
        'icon': Icons.local_shipping,
        'date': dispatchedDate,
      },
      {
        'status': 'delivered',
        'label': 'Entregue',
        'icon': Icons.check_circle,
        'date': finishedDate,
      },
    ];

    // Encontrar fase atual
    int currentPhaseIndex = 0;
    if (d.status == 'delivered' || d.status == 'cancelled') {
      currentPhaseIndex = 2;
    } else if (d.status == 'dispatched') {
      currentPhaseIndex = 1;
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.timeline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Status da Entrega',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Trilha de eventos - usa LayoutBuilder para alternar entre horizontal e vertical
        LayoutBuilder(
          builder: (context, constraints) {
            // Se a largura for maior que 500px, usa layout horizontal
            final useHorizontalLayout = constraints.maxWidth > 500;

            if (useHorizontalLayout) {
              // Layout Horizontal - Centralizado
              return Center(
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int index = 0; index < phases.length; index++) ...[
                        // Fase
                        Builder(
                          builder: (context) {
                            final phase = phases[index];
                            final isCompleted = index <= currentPhaseIndex;
                            final isCurrent = index == currentPhaseIndex;
                            final phaseDate = phase['date'] as DateTime?;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Círculo
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? currentColor
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    border: isCurrent
                                        ? Border.all(
                                            color: currentColor,
                                            width: 3,
                                          )
                                        : null,
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: currentColor.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    phase['icon'] as IconData,
                                    color: isCompleted
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Label com badge "Atual"
                                SizedBox(
                                  width: 100,
                                  child: Column(
                                    children: [
                                      Text(
                                        phase['label'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isCompleted
                                              ? currentColor
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: currentColor.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'Atual',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: currentColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      if (!isCurrent) const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                                // Data - sempre abaixo
                                SizedBox(
                                  width: 100,
                                  child: phaseDate != null
                                      ? Column(
                                          children: [
                                            Text(
                                              _dateFormat.format(phaseDate),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            // Tempo decorrido para fase em rota
                                            if (phase['status'] ==
                                                    'dispatched' &&
                                                isCurrent &&
                                                elapsedTime != '—') ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.orange
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time,
                                                      size: 12,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      elapsedTime,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.orange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      : Text(
                                          'Pendente',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.6),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                        // Linha conectora horizontal
                        if (index < phases.length - 1)
                          Container(
                            width: 60,
                            height: 2,
                            margin: const EdgeInsets.only(
                              top: 19,
                            ), // Alinha com o centro do círculo (40/2 - 1)
                            decoration: BoxDecoration(
                              color: index < currentPhaseIndex
                                  ? currentColor.withOpacity(0.3)
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            } else {
              // Layout Vertical (original)
              return Column(
                children: List.generate(phases.length, (index) {
                  final phase = phases[index];
                  final isCompleted = index <= currentPhaseIndex;
                  final isCurrent = index == currentPhaseIndex;
                  final isLast = index == phases.length - 1;
                  final phaseDate = phase['date'] as DateTime?;

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Círculo e linha vertical
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? currentColor
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: isCurrent
                                      ? Border.all(
                                          color: currentColor,
                                          width: 3,
                                        )
                                      : null,
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: currentColor.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  phase['icon'] as IconData,
                                  color: isCompleted
                                      ? Colors.white
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? currentColor.withOpacity(0.3)
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Conteúdo da fase
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        phase['label'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isCompleted
                                              ? currentColor
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: currentColor.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'Atual',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: currentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (phaseDate != null) ...[
                                    Text(
                                      _dateFormat.format(phaseDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    // Tempo decorrido para fase em rota
                                    if (phase['status'] == 'dispatched' &&
                                        isCurrent &&
                                        elapsedTime != '—') ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              elapsedTime,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ] else if (!isCompleted) ...[
                                    Text(
                                      'Pendente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              );
            }
          },
        ),

        // Aviso se cancelada
        if (d.status == 'cancelled') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Entrega Cancelada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _scrollToAndShowDelivery(DeliveryModel targetDelivery) async {
    // Validação crítica logo no início
    if (!_canShowDeliveryModal(targetDelivery)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Esta entrega não está mais disponível'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // RE-BUSCA a entrega ATUALIZADA do Hive box para evitar dados obsoletos
    final freshDelivery = _deliveriesBox.get(targetDelivery.id);
    if (freshDelivery == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Entrega não encontrada'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final key = _deliveryKeys[freshDelivery.id];

    // Se há chave e contexto, faz scroll (quando em "Em Entrega")
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
      );
    }

    if (!mounted) return;

    final driver = freshDelivery.driverId != null
        ? _driversBox.get(freshDelivery.driverId)
        : null;
    String elapsedTime = '—';
    Color timeColor = Colors.grey;
    if (freshDelivery.dispatchedAt?.isNotEmpty ?? false) {
      final startDt = DateTime.tryParse(freshDelivery.dispatchedAt ?? '');
      if (startDt != null) {
        final endDt = (freshDelivery.finishedAt?.isNotEmpty ?? false)
            ? DateTime.tryParse(freshDelivery.finishedAt ?? '') ??
                  DateTime.now()
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
      freshDelivery,
      driver,
      elapsedTime,
      timeColor,
    );

    if (mounted) {
      setState(() => _navigateToDeliveryId = null);
    }
  }

  Widget _buildDriverInfoWithCallback(
    DeliveryModel d,
    DriverModel? driver,
    void Function(void Function()) updateDialog,
  ) {
    // Verificar se há equipe de motoristas
    final hasTeam = d.teamDriverIds.isNotEmpty;
    final teamSize = d.teamDriverIds.length;
    final canEdit = d.status != 'delivered' && d.status != 'cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(
              hasTeam && teamSize > 1 ? 'Equipe de Entrega:' : 'Motorista:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (hasTeam && teamSize > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$teamSize pessoas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.person_add_rounded, size: 20),
                tooltip: 'Adicionar à equipe',
                onPressed: () => _addDriverToTeam(d, updateDialog),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasTeam)
          // Mostrar equipe completa
          Column(
            children: d.teamDriverIds.asMap().entries.map((entry) {
              final index = entry.key;
              final driverName = entry.value;
              final isPrimary = index == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isPrimary
                      ? LinearGradient(
                          colors: [Colors.green[700]!, Colors.green[600]!],
                        )
                      : null,
                  color: isPrimary ? null : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: isPrimary
                      ? null
                      : Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? Colors.white.withOpacity(0.2)
                            : Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isPrimary ? Icons.drive_eta : Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isPrimary ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isPrimary ? 'Motorista' : 'Equipe',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPrimary
                                        ? Colors.white
                                        : Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: isPrimary ? Colors.white : null,
                          size: 20,
                        ),
                        offset: const Offset(0, 40),
                        itemBuilder: (context) => [
                          if (!isPrimary)
                            const PopupMenuItem(
                              value: 'primary',
                              child: Row(
                                children: [
                                  Icon(Icons.star, size: 18),
                                  SizedBox(width: 8),
                                  Text('Tornar principal'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.person_remove, size: 18),
                                SizedBox(width: 8),
                                Text('Remover da equipe'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'primary') {
                            _setAsPrimaryDriver(d, index, updateDialog);
                          } else if (value == 'remove') {
                            _removeDriverFromTeam(d, index, updateDialog);
                          }
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          // Mostrar motorista único ou não atribuído
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: driver != null
                  ? LinearGradient(
                      colors: [Colors.green[700]!, Colors.green[600]!],
                    )
                  : null,
              color: driver != null ? null : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: driver != null
                  ? null
                  : Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: driver != null
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    driver != null
                        ? Icons.drive_eta
                        : Icons.person_off_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver?.name ?? 'Não atribuído',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: driver != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: driver != null ? Colors.white : null,
                          fontStyle: driver == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      if (driver != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Motorista',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit && driver != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    tooltip: 'Alterar motorista',
                    onPressed: () => _showAssignDriverDialog(d),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildForecastInfoWithCallback(
    DeliveryModel d,
    void Function(void Function()) updateDialog,
  ) {
    final canEdit = d.status != 'delivered' && d.status != 'cancelled';
    final hasForecast =
        d.deliveryForecastDate != null && d.deliveryForecastPeriod != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Previsão de Entrega:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (canEdit)
              IconButton(
                icon: Icon(
                  hasForecast ? Icons.edit : Icons.add_circle_outline,
                  size: 20,
                ),
                tooltip: hasForecast ? 'Editar previsão' : 'Adicionar previsão',
                onPressed: () => _showEditForecastDialog(d, updateDialog),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasForecast)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue[600]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(
                          DateTime.parse(d.deliveryForecastDate!),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            d.deliveryForecastPeriod == 'manha'
                                ? Icons.wb_sunny
                                : Icons.wb_twilight,
                            size: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            d.deliveryForecastPeriod == 'manha'
                                ? 'Manhã (08:00 - 12:00)'
                                : 'Tarde (13:00 - 18:00)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sem previsão definida',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _addDriverToTeam(
    DeliveryModel delivery,
    void Function(void Function()) updateDialog,
  ) {
    // Estrutura inspirada na aba de selecionar equipe do modal de adicionar entrega
    final List<String> availableDrivers = [
      'Zezinho',
      'Edmar',
      'Antônio Carlos',
      'José Cardoso',
      'Welington',
      'Jailton',
      'Josimar',
      'Ronaldo',
      'Márcio',
      'Fábio',
    ];

    List<String> selectedDrivers = delivery.teamDriverIds.isNotEmpty
        ? List<String>.from(delivery.teamDriverIds)
        : <String>[];

    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filteredDrivers = availableDrivers.where((name) {
            if (searchQuery.isEmpty) return true;
            return name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text('Gerenciar Equipe de Entrega'),
            content: SizedBox(
              width: 520,
              height: 460,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Barra de busca e resumo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar motorista...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setDialogState(() {
                                        searchController.clear();
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (v) =>
                              setDialogState(() => searchQuery = v),
                        ),
                        const SizedBox(height: 8),
                        // Info e resumo
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      selectedDrivers.isEmpty
                                          ? 'Selecione pelo menos um motorista'
                                          : 'Motorista principal: ${selectedDrivers.first}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Visibility(
                                      visible: selectedDrivers.isEmpty,
                                      maintainSize: true,
                                      maintainAnimation: true,
                                      maintainState: true,
                                      child: Text(
                                        'O primeiro selecionado será o motorista principal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: selectedDrivers.length > 1,
                                      maintainSize: true,
                                      maintainAnimation: true,
                                      maintainState: true,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '+${selectedDrivers.length - 1} membro${selectedDrivers.length > 2 ? 's' : ''} na equipe',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  // Lista de motoristas em grid com seleção
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredDrivers.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 2.4,
                          ),
                      itemBuilder: (context, index) {
                        final driverName = filteredDrivers[index];
                        final isSelected = selectedDrivers.contains(driverName);
                        final selectedIndex = selectedDrivers.indexOf(
                          driverName,
                        );
                        final isPrimary = selectedIndex == 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedDrivers.remove(driverName);
                                } else {
                                  selectedDrivers.add(driverName);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isPrimary
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? (isPrimary
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.secondary)
                                      : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withOpacity(0.5),
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              (isPrimary
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.secondary)
                                                  .withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: isSelected
                                          ? (isPrimary
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.secondary)
                                          : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      child: Icon(
                                        isSelected
                                            ? (isPrimary
                                                  ? Icons.local_shipping
                                                  : Icons.person)
                                            : Icons.person_outline,
                                        size: 12,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            driverName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? (isPrimary
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .onPrimaryContainer
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSecondaryContainer)
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              isPrimary
                                                  ? 'Motorista'
                                                  : 'Equipe',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    (isPrimary
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimaryContainer
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSecondaryContainer)
                                                        .withOpacity(0.8),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: isPrimary
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Persistir seleção
                  delivery.teamDriverIds = List<String>.from(selectedDrivers);

                  if (selectedDrivers.isEmpty) {
                    delivery.driverId = null;
                    delivery.status = 'pending';
                  } else {
                    final primary = selectedDrivers.first;
                    // Garantir/obter DriverModel correspondente
                    DriverModel? primaryDriver;
                    try {
                      primaryDriver = _driversBox.values
                          .whereType<DriverModel>()
                          .firstWhere((d) => d.name == primary);
                    } catch (_) {
                      primaryDriver = DriverModel.create(
                        id: 'driver_${DateTime.now().millisecondsSinceEpoch}',
                        name: primary,
                      );
                      _driversBox.put(primaryDriver.id, primaryDriver);
                    }
                    delivery.driverId = primaryDriver.id;
                    if (delivery.status == 'pending') {
                      delivery.status = 'assigned';
                    }
                  }

                  delivery.save();
                  Navigator.of(ctx).pop();
                  setState(() {});
                  updateDialog(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        selectedDrivers.isEmpty
                            ? 'Equipe removida'
                            : (selectedDrivers.length == 1
                                  ? 'Motorista atualizado'
                                  : 'Equipe atualizada (${selectedDrivers.length})'),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  selectedDrivers.isEmpty
                      ? 'Salvar'
                      : 'Salvar (${selectedDrivers.length})',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _setAsPrimaryDriver(
    DeliveryModel delivery,
    int currentIndex,
    void Function(void Function()) updateDialog,
  ) {
    if (currentIndex == 0) return; // Já é o principal

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tornar Motorista Principal'),
        content: Text(
          'Deseja tornar ${delivery.teamDriverIds[currentIndex]} o motorista principal desta entrega?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final updatedTeam = List<String>.from(delivery.teamDriverIds);
              final newPrimary = updatedTeam.removeAt(currentIndex);
              updatedTeam.insert(0, newPrimary);

              // Atualizar também o driverId (procurar ou criar driver)
              final driverMatch = _driversBox.values
                  .whereType<DriverModel>()
                  .firstWhere(
                    (d) => d.name == newPrimary,
                    orElse: () {
                      final id =
                          'driver_${newPrimary.replaceAll(' ', '_').toLowerCase()}';
                      final newDriver = DriverModel.create(
                        id: id,
                        name: newPrimary,
                      );
                      _driversBox.put(id, newDriver);
                      return newDriver;
                    },
                  );

              delivery.teamDriverIds = updatedTeam;
              delivery.driverId = driverMatch.id;
              delivery.save();

              Navigator.of(ctx).pop();
              setState(() {});
              updateDialog(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$newPrimary agora é o motorista principal'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _removeDriverFromTeam(
    DeliveryModel delivery,
    int index,
    void Function(void Function()) updateDialog,
  ) {
    final driverName = delivery.teamDriverIds[index];
    final isPrimary = index == 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da Equipe'),
        content: Text(
          isPrimary
              ? 'Tem certeza que deseja remover $driverName da equipe?\n\nAtenção: Este é o motorista principal. O próximo membro se tornará o motorista principal.'
              : 'Tem certeza que deseja remover $driverName da equipe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final updatedTeam = List<String>.from(delivery.teamDriverIds);
              updatedTeam.removeAt(index);

              if (updatedTeam.isEmpty) {
                // Se não sobrou ninguém, remover atribuição
                delivery.teamDriverIds = updatedTeam;
                delivery.driverId = null;
                delivery.status = 'pending';
              } else {
                // Atualizar driverId para o novo primeiro da lista (pode ter mudado)
                final newPrimaryName = updatedTeam.first;
                final driverMatch = _driversBox.values
                    .whereType<DriverModel>()
                    .firstWhere(
                      (d) => d.name == newPrimaryName,
                      orElse: () {
                        final id =
                            'driver_${newPrimaryName.replaceAll(' ', '_').toLowerCase()}';
                        final newDriver = DriverModel.create(
                          id: id,
                          name: newPrimaryName,
                        );
                        _driversBox.put(id, newDriver);
                        return newDriver;
                      },
                    );

                delivery.teamDriverIds = updatedTeam;
                delivery.driverId = driverMatch.id;
              }

              delivery.save();

              Navigator.of(ctx).pop();
              setState(() {});
              updateDialog(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$driverName removido da equipe'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    DeliveryModel d,
    void Function(void Function()) setDialogState,
  ) {
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
          onPressed: () => _dispatchDelivery(d, setDialogState),
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
          onPressed: () => _finishDelivery(d, setDialogState),
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

  void _dispatchDelivery(
    DeliveryModel d,
    void Function(void Function()) setDialogState,
  ) {
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
              Navigator.of(ctx).pop(); // Fecha apenas o diálogo de confirmação

              // Atualiza o modal sem fechá-lo
              setDialogState(() {});

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

  void _finishDelivery(
    DeliveryModel d,
    void Function(void Function()) setDialogState,
  ) {
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
              Navigator.of(ctx).pop(); // Fecha apenas o diálogo de confirmação

              // Atualiza o modal sem fechá-lo
              setDialogState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrega finalizada com sucesso!'),
                ),
              );
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar Entrega'),
          ),
        ],
      ),
    );
  }

  void _showEditForecastDialog(
    DeliveryModel delivery,
    void Function(void Function()) updateDialog,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    DateTime? selectedDate = delivery.deliveryForecastDate != null
        ? DateTime.parse(delivery.deliveryForecastDate!)
        : null;
    String? selectedPeriod = delivery.deliveryForecastPeriod;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue[600]!],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Previsão de Entrega',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Defina quando será realizada',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Data
                        const Text(
                          'Data da Entrega',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedDate != null
                                    ? Colors.blue
                                    : Colors.grey.withOpacity(0.3),
                                width: selectedDate != null ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: selectedDate != null
                                      ? Colors.blue
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedDate != null
                                        ? dateFormat.format(selectedDate!)
                                        : 'Selecione a data',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selectedDate != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: selectedDate != null
                                          ? null
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Período
                        const Text(
                          'Período de Entrega',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPeriodCardSmall(
                                'Manhã',
                                Icons.wb_sunny,
                                'manha',
                                '08:00 - 12:00',
                                selectedPeriod,
                                (value) {
                                  setModalState(() {
                                    selectedPeriod = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPeriodCardSmall(
                                'Tarde',
                                Icons.wb_twilight,
                                'tarde',
                                '13:00 - 18:00',
                                selectedPeriod,
                                (value) {
                                  setModalState(() {
                                    selectedPeriod = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed:
                              selectedDate != null && selectedPeriod != null
                              ? () {
                                  delivery.deliveryForecastDate = selectedDate!
                                      .toIso8601String();
                                  delivery.deliveryForecastPeriod =
                                      selectedPeriod;
                                  delivery.save();
                                  Navigator.of(ctx).pop();
                                  updateDialog(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Previsão atualizada com sucesso!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                }
                              : null,
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodCardSmall(
    String label,
    IconData icon,
    String value,
    String timeRange,
    String? selectedPeriod,
    void Function(String) onSelected,
  ) {
    final isSelected = selectedPeriod == value;

    return InkWell(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.15)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.blue.withOpacity(0.7) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrderToDeliveryDialog(
    DeliveryModel delivery,
    void Function(void Function()) updateDialog,
  ) {
    String searchQuery = '';
    final Set<String> selectedOrderIds = {};

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return ValueListenableBuilder<Box<OrderModel>>(
                valueListenable: _ordersBox.listenable(),
                builder: (context, box, _) {
                  final allOrders = box.values.whereType<OrderModel>().toList();

                  final deliveries = _deliveriesBox.values
                      .whereType<DeliveryModel>()
                      .toList();
                  final usedOrderIds = <String>{};
                  for (final d in deliveries) {
                    usedOrderIds.addAll(d.orderIds);
                  }

                  final availableOrders = allOrders
                      .where(
                        (o) =>
                            !usedOrderIds.contains(o.id) &&
                            !delivery.orderIds.contains(o.id),
                      )
                      .toList();

                  availableOrders.sort((a, b) {
                    final ad = DateTime.tryParse(a.createdAt);
                    final bd = DateTime.tryParse(b.createdAt);
                    if (ad != null && bd != null) return bd.compareTo(ad);
                    return b.orderNumber.compareTo(a.orderNumber);
                  });

                  final query = searchQuery.trim().toLowerCase();
                  final filteredOrders = query.isEmpty
                      ? availableOrders
                      : availableOrders.where((o) {
                          final num = o.orderNumber.toLowerCase();
                          final resp = o.responsible.toLowerCase();
                          return num.contains(query) || resp.contains(query);
                        }).toList();

                  void addSelectedOrders() {
                    if (selectedOrderIds.isEmpty) return;

                    final addedOrders = <OrderModel>[];
                    for (final id in selectedOrderIds) {
                      final order = _ordersBox.get(id);
                      if (order == null) continue;
                      delivery.orderIds.add(order.id);
                      addedOrders.add(order);
                    }

                    if (addedOrders.isEmpty) return;

                    delivery.save();
                    Navigator.of(ctx).pop();
                    updateDialog(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          addedOrders.length == 1
                              ? 'Nota #${addedOrders.first.orderNumber} adicionada.'
                              : '${addedOrders.length} notas adicionadas.',
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  }

                  return Container(
                    width: 540,
                    constraints: const BoxConstraints(maxHeight: 680),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primaryContainer.withOpacity(
                                  0.75,
                                ),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Adicionar nota à entrega',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Escolha uma nota existente ou cadastre uma nova para esta entrega.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withOpacity(0.8),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: Icon(
                                  Icons.close,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText:
                                            'Buscar por número ou responsável...',
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onChanged: (v) => setModalState(() {
                                        searchQuery = v;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (_) => AddOrderModal(
                                          box: _ordersBox,
                                          sellersBox: _sellersBox,
                                        ),
                                      );
                                      setModalState(() {});
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Nova nota'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (filteredOrders.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => setModalState(() {
                                        final allFilteredIds = filteredOrders
                                            .map((o) => o.id);
                                        final allSelected = filteredOrders
                                            .every(
                                              (o) => selectedOrderIds.contains(
                                                o.id,
                                              ),
                                            );
                                        if (allSelected) {
                                          selectedOrderIds.removeAll(
                                            allFilteredIds,
                                          );
                                        } else {
                                          selectedOrderIds.addAll(
                                            allFilteredIds,
                                          );
                                        }
                                      }),
                                      icon: Icon(
                                        filteredOrders.every(
                                              (o) => selectedOrderIds.contains(
                                                o.id,
                                              ),
                                            )
                                            ? Icons.close_rounded
                                            : Icons.done_all,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      label: Text(
                                        filteredOrders.every(
                                              (o) => selectedOrderIds.contains(
                                                o.id,
                                              ),
                                            )
                                            ? 'Desselecionar todas'
                                            : 'Selecionar todas',
                                      ),
                                    ),
                                  if (filteredOrders.isNotEmpty)
                                    const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.list_alt,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${availableOrders.length} disponíveis',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (selectedOrderIds.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary
                                            .withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.checklist_rounded,
                                            size: 16,
                                            color: theme.colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${selectedOrderIds.length} selecionada${selectedOrderIds.length == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (selectedOrderIds.isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (query.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => setModalState(() {
                                        searchQuery = '';
                                      }),
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: const Text('Limpar busca'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: filteredOrders.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inbox_rounded,
                                        size: 48,
                                        color: theme.colorScheme.outline,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        query.isEmpty
                                            ? 'Nenhuma nota sem entrega encontrada.'
                                            : 'Nenhuma nota corresponde à busca.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (_) => AddOrderModal(
                                              box: _ordersBox,
                                              sellersBox: _sellersBox,
                                            ),
                                          );
                                          setModalState(() {});
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                          'Cadastrar nova nota',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    12,
                                  ),
                                  shrinkWrap: true,
                                  itemCount: filteredOrders.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    final isSelected = selectedOrderIds
                                        .contains(order.id);
                                    final created = _formatDate(
                                      order.createdAt,
                                    );

                                    return InkWell(
                                      onTap: () => setModalState(() {
                                        if (isSelected) {
                                          selectedOrderIds.remove(order.id);
                                        } else {
                                          selectedOrderIds.add(order.id);
                                        }
                                      }),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .outlineVariant,
                                          ),
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                                    .withOpacity(0.08)
                                              : theme.colorScheme.surface,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.03,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (_) =>
                                                  setModalState(() {
                                                    if (isSelected) {
                                                      selectedOrderIds.remove(
                                                        order.id,
                                                      );
                                                    } else {
                                                      selectedOrderIds.add(
                                                        order.id,
                                                      );
                                                    }
                                                  }),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Nota #${order.orderNumber}',
                                                        style: theme
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .primary
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          created,
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 16,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          order.responsible,
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surfaceContainerLow
                                : theme.colorScheme.surfaceContainerHighest
                                      .withOpacity(0.6),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withOpacity(0.5),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: selectedOrderIds.isEmpty
                                      ? null
                                      : addSelectedOrders,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Adicionar à entrega'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ===== MODALS AT TOP LEVEL =====

/// Modal para adicionar nova nota
class AddOrderModal extends StatefulWidget {
  final Box<OrderModel> box;
  final Box<SellerModel> sellersBox;
  final void Function(String id)? onCreated;

  // Boxes are optional to tolerate call sites without args (fallback to global boxes)
  AddOrderModal({
    super.key,
    Box<OrderModel>? box,
    Box<SellerModel>? sellersBox,
    this.onCreated,
  }) : box = box ?? Hive.box<OrderModel>('orders'),
       sellersBox = sellersBox ?? Hive.box<SellerModel>('sellers');

  @override
  State<AddOrderModal> createState() => _AddOrderModalState();
}

class _AddOrderModalState extends State<AddOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberController = TextEditingController();
  final _orderNumberFocusNode = FocusNode();
  final _responsibleFocusNode = FocusNode();
  final _saveButtonFocusNode = FocusNode();
  String _responsible = '';
  bool _isSaving = false;
  int _formRebuildKey = 0;
  String _searchBuffer = '';
  Timer? _searchTimer;
  int _selectedIndex = -1; // Índice da opção selecionada por navegação

  @override
  void dispose() {
    _searchTimer?.cancel();
    _orderNumberController.dispose();
    _orderNumberFocusNode.dispose();
    _responsibleFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  // Normaliza string removendo acentos
  String _normalizeString(String str) {
    const withAccents = 'àáäâãèéëêìíïîòóöôõùúüûñçÀÁÄÂÃÈÉËÊÌÍÏÎÒÓÖÔÕÙÚÜÛÑÇ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

    String result = '';
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      final index = withAccents.indexOf(char);
      if (index >= 0) {
        result += withoutAccents[index];
      } else {
        result += char;
      }
    }
    return result;
  }

  void _handleKeyPress(String character) {
    // Cancela o timer anterior
    _searchTimer?.cancel();

    // Adiciona o caractere ao buffer
    _searchBuffer += character.toLowerCase();

    // Busca o vendedor que corresponde (com suporte a acentos)
    final sellers = widget.sellersBox.values.whereType<SellerModel>().toList();
    if (sellers.isEmpty) return;

    final normalizedBuffer = _normalizeString(_searchBuffer);

    // Tenta encontrar um vendedor que começa com o buffer
    final startsWith = sellers.where(
      (seller) => _normalizeString(
        seller.name.toLowerCase(),
      ).startsWith(normalizedBuffer),
    );

    late SellerModel match;

    if (startsWith.isNotEmpty) {
      match = startsWith.first;
    } else {
      // Se não encontrou, tenta um que contém o buffer
      final contains = sellers.where(
        (seller) => _normalizeString(
          seller.name.toLowerCase(),
        ).contains(normalizedBuffer),
      );
      match = contains.isNotEmpty ? contains.first : sellers.first;
    }

    // Seleciona o vendedor encontrado
    setState(() {
      _responsible = match.name;
      _selectedIndex = sellers.indexOf(match);
    });

    // Reseta o buffer após 1 segundo
    _searchTimer = Timer(const Duration(seconds: 1), () {
      _searchBuffer = '';
    });
  }

  void _navigateOptions(bool moveDown) {
    final sellers = widget.sellersBox.values.whereType<SellerModel>().toList();

    if (sellers.isEmpty) return;

    setState(() {
      if (moveDown) {
        // Seta para baixo - próxima opção
        _selectedIndex = (_selectedIndex + 1) % sellers.length;
      } else {
        // Seta para cima - opção anterior
        _selectedIndex = (_selectedIndex - 1 + sellers.length) % sellers.length;
      }
      _responsible = sellers[_selectedIndex].name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sellers = widget.sellersBox.values.whereType<SellerModel>().toList();
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        key: ValueKey(_formRebuildKey),
        width: 480,
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header com gradiente sutil
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nova Nota',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Preencha os dados da nota',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Número da Nota
                    _buildFieldLabel('Número da Nota', Icons.tag_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _orderNumberController,
                      focusNode: _orderNumberFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _responsibleFocusNode.requestFocus();
                      },
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Ex: 123456',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.receipt_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Campo obrigatório';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Responsável
                    _buildFieldLabel(
                      'Vendedor Responsável',
                      Icons.person_rounded,
                    ),
                    const SizedBox(height: 8),
                    Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          // Verifica se é Enter e já tem vendedor selecionado
                          if (event.logicalKey == LogicalKeyboardKey.enter &&
                              _responsible.isNotEmpty) {
                            _saveButtonFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }

                          // Navegação com setas para cima/baixo
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            _navigateOptions(true);
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _navigateOptions(false);
                            return KeyEventResult.handled;
                          }

                          // Busca por digitação de letras e caracteres acentuados
                          final character = event.character;
                          if (character != null &&
                              character.length == 1 &&
                              RegExp(
                                r'[a-zA-ZàáäâãèéëêìíïîòóöôõùúüûñçÀÁÄÂÃÈÉËÊÌÍÏÎÒÓÖÔÕÙÚÜÛÑÇ]',
                              ).hasMatch(character)) {
                            _handleKeyPress(character);
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: DropdownButtonFormField<String>(
                        focusNode: _responsibleFocusNode,
                        value: _responsible.isEmpty ? null : _responsible,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Selecione o vendedor',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: sellers.map((seller) {
                          return DropdownMenuItem(
                            value: seller.name,
                            child: Text(seller.name),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            final sellers = widget.sellersBox.values
                                .whereType<SellerModel>()
                                .toList();
                            final selectedIndex = sellers.indexWhere(
                              (s) => s.name == v,
                            );
                            setState(() {
                              _responsible = v;
                              _selectedIndex = selectedIndex >= 0
                                  ? selectedIndex
                                  : -1;
                            });
                          }
                          // Move focus to save button after selection
                          if (v != null && v.isNotEmpty) {
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                _saveButtonFocusNode.requestFocus();
                              },
                            );
                          }
                        },
                        validator: (v) {
                          if (v?.isEmpty ?? true) {
                            return 'Selecione um vendedor';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer com ações
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerLow
                    : theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Focus(
                      focusNode: _saveButtonFocusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !_isSaving) {
                          _save();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Criar Nota',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final orderNumber = _orderNumberController.text;

    // Check for duplicate note number
    OrderModel? existing;
    try {
      existing = widget.box.values.whereType<OrderModel>().firstWhere(
        (o) => o.orderNumber == orderNumber,
      );
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      setState(() => _isSaving = false);
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Text('Nota Duplicada'),
            ],
          ),
          content: Text(
            'Já existe uma nota com o número $orderNumber. Deseja continuar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (shouldContinue == true) {
        setState(() => _isSaving = true);
        await _doSave();
      }
    } else {
      await _doSave();
    }
  }

  Future<void> _doSave() async {
    final orderNumber = _orderNumberController.text;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final order = OrderModel.create(
      id: id,
      orderNumber: orderNumber,
      responsible: _responsible,
    );

    // Simula um pequeno delay para feedback visual
    await Future.delayed(const Duration(milliseconds: 300));

    widget.box.put(id, order);

    if (mounted) {
      // Notifica caller para uso imediato (ex.: pré-selecionar a nota)
      widget.onCreated?.call(id);

      // Exibe mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Nota criada com sucesso!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reseta tudo e força rebuild
      setState(() {
        _orderNumberController.clear();
        _responsible = '';
        _isSaving = false;
        _formRebuildKey++; // Força rebuild completo do form
      });

      // Aguarda o rebuild e então reseta a validação
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _formKey.currentState?.reset();
          // Retorna o foco para o primeiro campo
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _orderNumberFocusNode.requestFocus();
            }
          });
        }
      });
    }
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
            final drivers = box.values.whereType<DriverModel>().toList();
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

// ===== SELLERS MODAL =====
class SellersModal extends StatefulWidget {
  final Box<SellerModel> box;
  const SellersModal({super.key, required this.box});

  @override
  State<SellersModal> createState() => _SellersModalState();
}

class _SellersModalState extends State<SellersModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendedores'),
          automaticallyImplyLeading: true,
        ),
        body: ValueListenableBuilder<Box<SellerModel>>(
          valueListenable: widget.box.listenable(),
          builder: (context, box, _) {
            final sellers = box.values.whereType<SellerModel>().toList();
            return sellers.isEmpty
                ? const Center(child: Text('Nenhum vendedor cadastrado.'))
                : ListView.builder(
                    itemCount: sellers.length,
                    itemBuilder: (context, index) {
                      final seller = sellers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text('👤 ${seller.name}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => _handleSellerAction(v, seller),
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
          onPressed: _showAddSellerDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Adicionar'),
        ),
      ),
    );
  }

  void _showAddSellerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddSellerModal(box: widget.box),
    );
  }

  void _handleSellerAction(String action, SellerModel seller) {
    if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deletar Vendedor'),
          content: const Text('Tem certeza que deseja deletar este vendedor?'),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                seller.delete();
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

/// Modal para adicionar vendedor
class AddSellerModal extends StatefulWidget {
  final Box<SellerModel> box;
  const AddSellerModal({super.key, required this.box});

  @override
  State<AddSellerModal> createState() => _AddSellerModalState();
}

class _AddSellerModalState extends State<AddSellerModal> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Vendedor'),
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
    final seller = SellerModel.create(id: id, name: _name);
    widget.box.put(id, seller);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendedor cadastrado com sucesso!')),
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
  // Lista fixa de motoristas disponíveis
  final List<String> _availableDrivers = [
    'Zezinho',
    'Edmar',
    'Antônio Carlos',
    'José Cardoso',
    'Welington',
    'Jailton',
    'Josimar',
    'Ronaldo',
    'Márcio',
    'Fábio',
  ];

  List<String> _selectedDrivers = [];

  @override
  void initState() {
    super.initState();
    // Carregar equipe existente se houver
    if (widget.delivery.teamDriverIds.isNotEmpty) {
      _selectedDrivers = List.from(widget.delivery.teamDriverIds);
    } else if (widget.delivery.driverId != null) {
      // Migração: se tem driverId antigo, tentar encontrar o nome
      final oldDriver = widget.driversBox.get(widget.delivery.driverId);
      if (oldDriver != null && _availableDrivers.contains(oldDriver.name)) {
        _selectedDrivers = [oldDriver.name];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Atribuir Equipe de Entrega'),
          if (_selectedDrivers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motorista principal: ${_selectedDrivers.first}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O primeiro selecionado será o motorista principal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _availableDrivers.map((driverName) {
                    final isSelected = _selectedDrivers.contains(driverName);
                    final index = _selectedDrivers.indexOf(driverName);
                    final isPrimary = index == 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isSelected ? 2 : 0,
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.3)
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(driverName)),
                            if (isSelected) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isPrimary
                                      ? 'Motorista'
                                      : 'Equipe ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isPrimary
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDrivers.remove(driverName);
                            } else {
                              _selectedDrivers.add(driverName);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedDrivers.isEmpty ? null : _save,
          child: Text(
            _selectedDrivers.isEmpty
                ? 'Atribuir'
                : 'Atribuir (${_selectedDrivers.length})',
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_selectedDrivers.isEmpty) return;

    // Salvar a equipe
    widget.delivery.teamDriverIds = List.from(_selectedDrivers);

    // Para compatibilidade, setar o driverId como o primeiro da lista
    // Tentar encontrar ou criar o motorista principal no banco
    final primaryDriverName = _selectedDrivers.first;
    DriverModel? primaryDriver;

    // Buscar motorista existente com o nome
    try {
      primaryDriver = widget.driversBox.values
          .whereType<DriverModel>()
          .firstWhere((d) => d.name == primaryDriverName);
    } catch (_) {
      // Se não encontrar, criar um novo
      primaryDriver = DriverModel.create(
        id: 'driver_${DateTime.now().millisecondsSinceEpoch}',
        name: primaryDriverName,
      );
      widget.driversBox.put(primaryDriver.id, primaryDriver);
    }

    widget.delivery.driverId = primaryDriver.id;
    widget.delivery.status = 'assigned';
    widget.delivery.save();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedDrivers.length == 1
              ? 'Motorista atribuído com sucesso!'
              : 'Equipe de ${_selectedDrivers.length} pessoas atribuída com sucesso!',
        ),
      ),
    );
  }
}

/// Modal para adicionar entrega - Redesenhado com UX aprimorada
class AddDeliveryModal extends StatefulWidget {
  final Box<OrderModel> ordersBox;
  final Box<DeliveryModel> deliveriesBox;
  final Box<DriverModel> driversBox;
  final Box<SellerModel> sellersBox;
  final String? preSelectedOrderId;
  const AddDeliveryModal({
    super.key,
    required this.ordersBox,
    required this.deliveriesBox,
    required this.driversBox,
    required this.sellersBox,
    this.preSelectedOrderId,
  });

  @override
  State<AddDeliveryModal> createState() => _AddDeliveryModalState();
}

class _AddDeliveryModalState extends State<AddDeliveryModal> {
  int _currentStep = 0;
  final List<String> _selectedOrderIds = [];
  final List<String> _selectedDrivers = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _deliveryForecastDate;
  String? _deliveryForecastPeriod; // 'manha' ou 'tarde'

  // Lista fixa de motoristas disponíveis
  final List<String> _availableDrivers = [
    'Zezinho',
    'Edmar',
    'Antônio Carlos',
    'José Cardoso',
    'Welington',
    'Jailton',
    'Josimar',
    'Ronaldo',
    'Márcio',
    'Fábio',
  ];

  @override
  void initState() {
    super.initState();
    final preSelectedId = widget.preSelectedOrderId;
    if (preSelectedId != null) {
      _selectedOrderIds.add(preSelectedId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(child: _buildContent()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nova Entrega',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentStep == 0
                      ? 'Selecione as notas para entrega'
                      : _currentStep == 1
                      ? 'Defina a equipe de entrega'
                      : _currentStep == 2
                      ? 'Defina a previsão de entrega'
                      : 'Confirme os detalhes',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onPrimary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepCircle(0, 'Notas', Icons.receipt_long),
          Expanded(child: _buildStepLine(0)),
          _buildStepCircle(1, 'Equipe', Icons.group),
          Expanded(child: _buildStepLine(1)),
          _buildStepCircle(2, 'Previsão', Icons.calendar_today),
          Expanded(child: _buildStepLine(2)),
          _buildStepCircle(3, 'Confirmar', Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, IconData icon) {
    final theme = Theme.of(context);
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isActive || isCompleted
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final theme = Theme.of(context);
    final isCompleted = _currentStep > step;

    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentStep) {
      case 0:
        return _buildOrdersStep();
      case 1:
        return _buildTeamStep();
      case 2:
        return _buildForecastStep();
      case 3:
        return _buildConfirmationStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOrdersStep() {
    return ValueListenableBuilder<Box<OrderModel>>(
      valueListenable: widget.ordersBox.listenable(),
      builder: (context, box, _) {
        final orders = box.values.whereType<OrderModel>().toList();
        final deliveries = widget.deliveriesBox.values
            .whereType<DeliveryModel>()
            .toList();
        final usedOrderIds = <String>{};
        for (final d in deliveries) {
          usedOrderIds.addAll(d.orderIds);
        }

        var availableOrders = orders
            .where((o) => !usedOrderIds.contains(o.id))
            .toList();

        // Newest notes first
        availableOrders.sort((a, b) {
          final da =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });

        // Aplicar busca
        if (_searchQuery.isNotEmpty) {
          availableOrders = availableOrders.where((o) {
            return o.orderNumber.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                o.responsible.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
        }

        return Column(
          children: [
            // Barra de busca e ações rápidas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por número ou responsável...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      if (_selectedOrderIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedOrderIds.length} selecionada${_selectedOrderIds.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            // Lista de notas
            Expanded(
              child: availableOrders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: availableOrders.length,
                      itemBuilder: (context, index) {
                        final order = availableOrders[index];
                        final isSelected = _selectedOrderIds.contains(order.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withOpacity(0.3)
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.receipt_long,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              'Nota #${order.orderNumber}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.responsible,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedOrderIds.remove(order.id);
                                } else {
                                  _selectedOrderIds.add(order.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma nota disponível'
                  : 'Nenhuma nota encontrada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Crie uma nova nota para começar'
                  : 'Tente ajustar sua busca',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AddOrderModal(
                      box: widget.ordersBox,
                      sellersBox: widget.sellersBox,
                      onCreated: (newId) {
                        if (mounted) {
                          setState(() {
                            if (!_selectedOrderIds.contains(newId)) {
                              _selectedOrderIds.add(newId);
                            }
                          });
                        }
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Criar nova nota'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamStep() {
    final filteredDrivers = _availableDrivers.where((name) {
      if (_searchQuery.isEmpty) return true;
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Barra de busca e resumo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar motorista...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              // Info e resumo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedDrivers.isEmpty
                                ? 'Selecione pelo menos um motorista'
                                : 'Motorista principal: ${_selectedDrivers.first}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Visibility(
                            visible: _selectedDrivers.isEmpty,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Text(
                              'O primeiro selecionado será o motorista principal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: _selectedDrivers.length > 1,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '+${_selectedDrivers.length - 1} membro${_selectedDrivers.length > 2 ? 's' : ''} na equipe',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        // Lista de motoristas
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDrivers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (context, index) {
              final driverName = filteredDrivers[index];
              final isSelected = _selectedDrivers.contains(driverName);
              final selectedIndex = _selectedDrivers.indexOf(driverName);
              final isPrimary = selectedIndex == 0;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDrivers.remove(driverName);
                      } else {
                        _selectedDrivers.add(driverName);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isPrimary
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isPrimary
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary)
                            : Theme.of(
                                context,
                              ).colorScheme.outlineVariant.withOpacity(0.5),
                        width: isSelected ? 1.5 : 0.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    (isPrimary
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.secondary)
                                        .withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Avatar circular minimalista
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelected
                                ? (isPrimary
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.secondary)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              isSelected
                                  ? (isPrimary
                                        ? Icons.local_shipping
                                        : Icons.person)
                                  : Icons.person_outline,
                              size: 14,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Nome do motorista
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? (isPrimary
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    isPrimary ? 'Motorista' : 'Equipe',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          (isPrimary
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer)
                                              .withOpacity(0.8),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Checkmark para selecionado
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: isPrimary
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForecastStep() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informação
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Defina quando a entrega será realizada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Seleção de data
          Text(
            'Data da Entrega',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deliveryForecastDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _deliveryForecastDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _deliveryForecastDate != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: _deliveryForecastDate != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _deliveryForecastDate != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _deliveryForecastDate != null
                          ? dateFormat.format(_deliveryForecastDate!)
                          : 'Selecione a data',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _deliveryForecastDate != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _deliveryForecastDate != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Seleção de período
          Text(
            'Período de Entrega',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPeriodCard(
                  'Manhã',
                  Icons.wb_sunny,
                  'manha',
                  '08:00 - 12:00',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPeriodCard(
                  'Tarde',
                  Icons.wb_twilight,
                  'tarde',
                  '13:00 - 18:00',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(
    String label,
    IconData icon,
    String value,
    String timeRange,
  ) {
    final isSelected = _deliveryForecastPeriod == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _deliveryForecastPeriod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    final orders = _selectedOrderIds
        .map((id) => widget.ordersBox.get(id))
        .whereType<OrderModel>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumo da entrega
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tudo pronto!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Revise os detalhes antes de criar a entrega',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Seção de notas
          _buildConfirmationSection(
            icon: Icons.receipt_long,
            title: 'Notas Selecionadas',
            count: orders.length,
            color: Colors.blue,
            children: orders.map((order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.tag,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nota #${order.orderNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Seção de equipe
          _buildConfirmationSection(
            icon: Icons.group,
            title: 'Equipe de Entrega',
            count: _selectedDrivers.length,
            color: Colors.green,
            children: _selectedDrivers.asMap().entries.map((entry) {
              final index = entry.key;
              final name = entry.value;
              final isPrimary = index == 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isPrimary
                        ? LinearGradient(
                            colors: [Colors.green[700]!, Colors.green[600]!],
                          )
                        : null,
                    color: isPrimary ? null : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: isPrimary
                        ? null
                        : Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? Colors.white.withOpacity(0.2)
                              : Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isPrimary ? Icons.drive_eta : Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isPrimary ? Colors.white : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? Colors.white.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isPrimary ? 'Motorista' : 'Equipe',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPrimary ? Colors.white : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Seção de previsão
          if (_deliveryForecastDate != null && _deliveryForecastPeriod != null)
            _buildConfirmationSection(
              icon: Icons.calendar_today,
              title: 'Previsão de Entrega',
              count: 1,
              color: Colors.blue,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.event_available,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(_deliveryForecastDate!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _deliveryForecastPeriod == 'manha'
                                      ? Icons.wb_sunny
                                      : Icons.wb_twilight,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _deliveryForecastPeriod == 'manha'
                                      ? 'Manhã (08:00 - 12:00)'
                                      : 'Tarde (13:00 - 18:00)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSection({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildActions() {
    final canProceed = _currentStep == 0
        ? _selectedOrderIds.isNotEmpty
        : _currentStep == 1
        ? _selectedDrivers.isNotEmpty
        : _currentStep == 2
        ? _deliveryForecastDate != null && _deliveryForecastPeriod != null
        : true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AddOrderModal(
                    box: widget.ordersBox,
                    sellersBox: widget.sellersBox,
                    onCreated: (newId) {
                      if (mounted) {
                        setState(() {
                          if (!_selectedOrderIds.contains(newId)) {
                            _selectedOrderIds.add(newId);
                          }
                        });
                      }
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova nota'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          const Spacer(),
          if (_currentStep < 3)
            FilledButton.icon(
              onPressed: canProceed
                  ? () {
                      setState(() {
                        _currentStep++;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(_currentStep == 0 ? 'Continuar' : 'Avançar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Criar Entrega'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _save() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final delivery = DeliveryModel.create(id: id, orderIds: _selectedOrderIds);

    // Salvar a equipe
    delivery.teamDriverIds = List.from(_selectedDrivers);

    // Salvar previsão de entrega
    if (_deliveryForecastDate != null) {
      delivery.deliveryForecastDate = _deliveryForecastDate!.toIso8601String();
    }
    if (_deliveryForecastPeriod != null) {
      delivery.deliveryForecastPeriod = _deliveryForecastPeriod;
    }

    // Para compatibilidade, setar o driverId como o primeiro da lista
    final primaryDriverName = _selectedDrivers.first;
    DriverModel? primaryDriver;

    // Buscar motorista existente com o nome
    try {
      primaryDriver = widget.driversBox.values
          .whereType<DriverModel>()
          .firstWhere((d) => d.name == primaryDriverName);
    } catch (_) {
      // Se não encontrar, criar um novo
      primaryDriver = DriverModel.create(
        id: 'driver_${DateTime.now().millisecondsSinceEpoch}',
        name: primaryDriverName,
      );
      widget.driversBox.put(primaryDriver.id, primaryDriver);
    }

    delivery.driverId = primaryDriver.id;
    delivery.status = 'assigned';
    widget.deliveriesBox.put(id, delivery);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDrivers.length == 1
                    ? 'Entrega criada com sucesso!'
                    : 'Entrega criada com equipe de ${_selectedDrivers.length} pessoas!',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
