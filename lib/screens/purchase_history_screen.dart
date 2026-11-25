import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _purchases = [];

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.getMyPurchases();
    if (!mounted) return;

    if (response['success'] == true && response['data'] != null) {
      final raw = response['data'];
      final List list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
              ? raw['data']
              : (raw is Map && raw['purchases'] is List
                  ? raw['purchases']
                  : []));

      setState(() {
        _purchases = list.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = ApiService.extractErrorMessage(
          response,
          fallback: 'Could not load purchase history.',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: const IosNavBar(title: 'Purchase History'),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : _purchases.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadPurchases,
                      color: IosTheme.primaryBlue,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _purchases.length,
                        itemBuilder: (context, index) =>
                            _buildPurchaseCard(_purchases[index]),
                      ),
                    ),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> item) {
    final title = item['item_title']?.toString() ??
        item['title']?.toString() ??
        (item['purchasable'] is Map
            ? item['purchasable']['title']?.toString()
            : null) ??
        'Order Receipt';
    final orderId = item['order_id']?.toString() ?? '#${item['id'] ?? ''}';
    final amount = item['amount']?.toString() ?? '0.00';
    final status =
        (item['payment_status'] ?? item['status'] ?? 'completed')
            .toString()
            .toLowerCase();
    final dateStr = item['created_at']?.toString() ?? '';
    final dateShort = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;

    final Color statusColor = status == 'completed'
        ? IosTheme.systemGreen
        : (status == 'pending' ? IosTheme.systemOrange : IosTheme.systemRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: IosTheme.separator),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: $orderId${dateShort.isNotEmpty ? " • $dateShort" : ""}',
                style: const TextStyle(
                  fontSize: 12,
                  color: IosTheme.labelTertiary,
                ),
              ),
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.bag,
              size: 48,
              color: IosTheme.labelTertiary,
            ),
            SizedBox(height: 12),
            Text(
              'No Purchases Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: IosTheme.labelPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your course and test series invoices and payment receipts will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: IosTheme.labelTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: IosTheme.systemRed,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              child: IosPrimaryButton(label: 'Retry', onPressed: _loadPurchases),
            ),
          ],
        ),
      ),
    );
  }
}
