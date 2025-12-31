import 'package:flutter/material.dart';
import 'package:coaching/models/test_series_models.dart';
import 'package:coaching/services/api_service.dart';
import 'package:coaching/screens/test_series/subject_tests_screen.dart';

class TestSeriesSubjectsScreen extends StatefulWidget {
  final int testSeriesId;
  final String title;

  const TestSeriesSubjectsScreen({
    Key? key,
    required this.testSeriesId,
    required this.title,
  }) : super(key: key);

  @override
  State<TestSeriesSubjectsScreen> createState() =>
      _TestSeriesSubjectsScreenState();
}

class _TestSeriesSubjectsScreenState extends State<TestSeriesSubjectsScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  TestSeries? _seriesDetails;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getTestSeriesSubjects(
        widget.testSeriesId,
      );
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _seriesDetails = TestSeries.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load subjects';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_isPurchasing) return;

    // In a real app, integrate payment gateway here
    // For now, mock the purchase API call
    setState(() => _isPurchasing = true);

    try {
      final response = await ApiService.purchaseTestSeries(widget.testSeriesId);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Successful!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSubjects(); // Refresh to unlock
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Purchase failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8F9FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchSubjects,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _seriesDetails == null
          ? const Center(child: Text('No details found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_seriesDetails!.isPurchased &&
                      !_seriesDetails!.isAccessible)
                    _buildPurchaseCard(),
                  if (_seriesDetails!.isPurchased ||
                      _seriesDetails!.isAccessible)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Purchased / Access Granted',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subjects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_seriesDetails!.subjects != null)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _seriesDetails!.subjects!.length,
                      itemBuilder: (context, index) {
                        return _buildSubjectCard(
                          _seriesDetails!.subjects![index],
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPurchaseCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get access to all tests',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPurchasing ? null : _handlePurchase,
              icon: _isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.credit_card),
              label: Text(
                _isPurchasing
                    ? 'Processing...'
                    : 'Buy Now - ₹${_seriesDetails!.price}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(TestSeriesSubject subject) {
    bool isLocked = !_seriesDetails!.isAccessible && !subject.isAccessible;

    return InkWell(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please purchase the series to access this subject',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubjectTestsScreen(
                testSeriesId: widget.testSeriesId,
                subjectId: subject.id,
                title: subject.name,
                seriesTitle: widget.title,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey[100]
                    : const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.book_rounded,
                color: isLocked ? Colors.grey : const Color(0xFF6366F1),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subject.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${subject.testCount} Tests',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (isLocked)
              const Icon(Icons.lock, color: Colors.grey, size: 20)
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}
