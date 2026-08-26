import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'main.dart' show dioProvider, sessionProvider;

/// Workers table — only CEO (superadmin) can add / deactivate.
class WorkersPage extends ConsumerStatefulWidget {
  const WorkersPage({super.key});
  @override
  ConsumerState<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends ConsumerState<WorkersPage> {
  List<Map<String, dynamic>> workers = [];
  String? err;
  bool loading = true;

  bool get isCEO {
    final s = ref.read(sessionProvider);
    return s?.role == 'superadmin' || s?.demoMode == true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    final session = ref.read(sessionProvider);
    if (session?.demoMode == true) {
      setState(() {
        workers = [
          {
            'id': 'ceo',
            'first_name': 'Zeni',
            'last_name': 'CEO',
            'phone': '254700000000',
            'role': 'superadmin',
            'is_active': true,
            'last_login_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 'w1',
            'first_name': 'Amina',
            'last_name': 'Otieno',
            'phone': '254711000001',
            'role': 'admin',
            'is_active': true,
            'last_login_at':
                DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
        loading = false;
      });
      return;
    }
    try {
      final res = await ref.read(dioProvider).get('/admin/workers');
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      final list = (data is Map ? data['workers'] : null) as List? ?? [];
      setState(() {
        workers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    final phoneC = TextEditingController();
    final passC = TextEditingController();
    final firstC = TextEditingController();
    final lastC = TextEditingController();
    final emailC = TextEditingController();
    String role = 'admin';
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add worker'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: firstC,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: lastC,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneC,
                  decoration: const InputDecoration(labelText: 'Phone 2547…'),
                  validator: (v) => (v == null || v.length < 9) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailC,
                  decoration: const InputDecoration(labelText: 'Work email (recommended)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passC,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Temp password (min 8)'),
                  validator: (v) => (v == null || v.length < 8) ? 'Min 8 chars' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin (underwriter)')),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                  ],
                  onChanged: (v) => role = v ?? 'admin',
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true);
            },
            child: const Text('Add to table'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(dioProvider).post('/admin/workers', data: {
        'phone': phoneC.text.trim(),
        'password': passC.text,
        'first_name': firstC.text.trim(),
        'last_name': lastC.text.trim(),
        'email': emailC.text.trim(),
        'role': role,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker added — they can sign in now')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deactivate(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate worker?'),
        content: Text('Remove access for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/admin/workers/$id/deactivate');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmt(dynamic last) {
    if (last == null) return '—';
    try {
      return DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse('$last'));
    } catch (_) {
      return '$last';
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Workers',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (isCEO)
            FilledButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add worker'),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          isCEO
              ? 'Only you (CEO) can add workers. Last login updates when they sign in.'
              : 'Worker list (read-only). Only the CEO can add staff.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (err != null)
          Expanded(child: Center(child: Text(err!, style: const TextStyle(color: Colors.red))))
        else
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Last login')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: workers.map((w) {
                      final name = '${w['first_name'] ?? ''} ${w['last_name'] ?? ''}'.trim();
                      final active = w['is_active'] == true;
                      final role = '${w['role'] ?? ''}';
                      return DataRow(cells: [
                        DataCell(Text(name.isEmpty ? '—' : name)),
                        DataCell(Text('${w['phone'] ?? ''}')),
                        DataCell(Chip(
                          label: Text(role.toUpperCase(), style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        )),
                        DataCell(Text(active ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: active ? Colors.greenAccent.shade400 : Colors.redAccent,
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(_fmt(w['last_login_at']))),
                        DataCell(
                          isCEO && role != 'superadmin' && active
                              ? TextButton(
                                  onPressed: () => _deactivate('${w['id']}', name),
                                  child: const Text('Deactivate'),
                                )
                              : const Text('—'),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Activity log — CEO only: logins, logouts, approvals, worker changes.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});
  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> sessions = [];
  String? err;
  bool loading = true;
  String filter = 'all'; // all | login | logout | login_failed
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    final session = ref.read(sessionProvider);
    if (session?.demoMode == true) {
      final now = DateTime.now();
      setState(() {
        sessions = [
          {
            'worker_name': 'Demo Worker',
            'role': 'admin',
            'phone': '254711000001',
            'status': 'online',
            'last_login_at': now.subtract(const Duration(minutes: 12)).toIso8601String(),
            'last_logout_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
            'last_login_ip': '41.90.x.x',
          },
          {
            'worker_name': 'Zeni CEO',
            'role': 'superadmin',
            'phone': '254700000000',
            'status': 'online',
            'last_login_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
            'last_login_ip': '41.90.x.x',
          },
        ];
        rows = [
          {
            'worker_name': 'Demo Worker',
            'action': 'login',
            'resource': 'session',
            'ip_address': '41.90.12.34',
            'created_at': now.subtract(const Duration(minutes: 12)).toIso8601String(),
            'details': {'event': 'sign_in'},
          },
          {
            'worker_name': 'Demo Worker',
            'action': 'logout',
            'resource': 'session',
            'ip_address': '41.90.12.34',
            'created_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
            'details': {'event': 'sign_out'},
          },
          {
            'worker_name': 'Demo Worker',
            'action': 'login',
            'resource': 'session',
            'ip_address': '41.90.12.34',
            'created_at': now.subtract(const Duration(hours: 6)).toIso8601String(),
          },
          {
            'worker_name': '—',
            'action': 'login_failed',
            'resource': 'session',
            'ip_address': '102.0.1.9',
            'created_at': now.subtract(const Duration(hours: 7)).toIso8601String(),
            'details': {'identifier': 'am***@zeni.loan'},
          },
          {
            'worker_name': 'Demo Worker',
            'action': 'approve_loan',
            'resource': 'loan',
            'resource_id': 'demo-loan-1',
            'created_at': now.subtract(const Duration(hours: 8)).toIso8601String(),
          },
        ];
        loading = false;
      });
      return;
    }
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('/admin/activity', queryParameters: {'limit': 300}),
        dio.get('/admin/sessions'),
      ]);
      final actRaw = results[0].data;
      final actData = actRaw is Map && actRaw['data'] is Map ? actRaw['data'] : actRaw;
      final list = (actData is Map ? actData['activity'] : null) as List? ?? [];

      final sessRaw = results[1].data;
      final sessData = sessRaw is Map && sessRaw['data'] is Map ? sessRaw['data'] : sessRaw;
      final sessList = (sessData is Map ? sessData['sessions'] : null) as List? ?? [];

      setState(() {
        rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        sessions = sessList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filtered {
    if (filter == 'all') return rows;
    return rows.where((r) => '${r['action']}' == filter).toList();
  }

  Color _actionColor(String action, ColorScheme cs) {
    switch (action) {
      case 'login':
        return const Color(0xFF34D399);
      case 'logout':
        return const Color(0xFF60A5FA);
      case 'login_failed':
        return const Color(0xFFF87171);
      case 'approve_loan':
      case 'disburse_loan':
        return const Color(0xFFA78BFA);
      case 'reject_loan':
      case 'deactivate_worker':
        return const Color(0xFFFB923C);
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _fmtWhen(dynamic v) {
    try {
      return DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.parse('$v'));
    } catch (_) {
      return '—';
    }
  }

  String _details(Map r) {
    final d = r['details'];
    if (d == null) return '—';
    if (d is Map) {
      return d.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    final s = '$d';
    return s.isEmpty || s == '{}' ? '—' : s;
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'online':
        bg = const Color(0xFF064E3B);
        fg = const Color(0xFF6EE7B7);
        label = 'ONLINE';
        break;
      case 'offline':
        bg = const Color(0xFF1E293B);
        fg = const Color(0xFF94A3B8);
        label = 'OFFLINE';
        break;
      default:
        bg = const Color(0xFF3F3F46);
        fg = const Color(0xFFA1A1AA);
        label = 'NEVER';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isCEO = session?.role == 'superadmin' || session?.demoMode == true;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;

    if (!isCEO) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 48, color: muted),
          const SizedBox(height: 12),
          Text('Only the CEO can view worker login & logout activity.',
              style: TextStyle(color: muted)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Worker activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 4),
        Text('See who signed in, who signed out, and every staff action.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Sessions (login / logout)'),
            Tab(text: 'Full audit trail'),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (err != null)
          Expanded(
            child: Center(
              child: Text(err!, style: TextStyle(color: cs.error)),
            ),
          )
        else
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── Sessions overview ──
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: sessions.isEmpty
                      ? Center(child: Text('No session data yet. Workers appear after first login.', style: TextStyle(color: muted)))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Worker')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Last login')),
                              DataColumn(label: Text('Login IP')),
                              DataColumn(label: Text('Last logout')),
                              DataColumn(label: Text('Logout IP')),
                            ],
                            rows: sessions.map((s) {
                              return DataRow(cells: [
                                DataCell(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${s['worker_name'] ?? '—'}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${s['phone'] ?? ''}',
                                        style: TextStyle(fontSize: 11, color: muted)),
                                  ],
                                )),
                                DataCell(Text('${s['role'] ?? ''}'.toUpperCase())),
                                DataCell(_statusPill('${s['status'] ?? 'never'}')),
                                DataCell(Text(_fmtWhen(s['last_login_at']))),
                                DataCell(Text('${s['last_login_ip'] ?? '—'}')),
                                DataCell(Text(_fmtWhen(s['last_logout_at']))),
                                DataCell(Text('${s['last_logout_ip'] ?? '—'}')),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
                // ── Full audit ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in [
                          ('all', 'All'),
                          ('login', 'Logins'),
                          ('logout', 'Logouts'),
                          ('login_failed', 'Failed logins'),
                        ])
                          FilterChip(
                            selected: filter == f.$1,
                            label: Text(f.$2),
                            onSelected: (_) => setState(() => filter = f.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('No events for this filter yet.',
                                    style: TextStyle(color: muted)))
                            : SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('When')),
                                    DataColumn(label: Text('Worker')),
                                    DataColumn(label: Text('Action')),
                                    DataColumn(label: Text('IP')),
                                    DataColumn(label: Text('Resource')),
                                    DataColumn(label: Text('Details')),
                                  ],
                                  rows: filtered.map((r) {
                                    final action = '${r['action'] ?? ''}';
                                    return DataRow(cells: [
                                      DataCell(Text(_fmtWhen(r['created_at']))),
                                      DataCell(Text('${r['worker_name'] ?? '—'}')),
                                      DataCell(
                                        Text(
                                          action.toUpperCase(),
                                          style: TextStyle(
                                            color: _actionColor(action, cs),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('${r['ip_address'] ?? '—'}')),
                                      DataCell(Text(
                                          '${r['resource'] ?? ''}${r['resource_id'] != null && '${r['resource_id']}'.isNotEmpty ? ' · ${r['resource_id']}' : ''}')),
                                      DataCell(SizedBox(
                                        width: 220,
                                        child: Text(_details(r),
                                            overflow: TextOverflow.ellipsis, maxLines: 2),
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ]),
    );
  }
}
