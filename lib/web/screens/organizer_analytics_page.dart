import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/rating_service.dart';
import '../../utils/data_utils.dart';

const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class OrganizerAnalyticsPage extends StatefulWidget {
  const OrganizerAnalyticsPage({super.key});

  @override
  State<OrganizerAnalyticsPage> createState() => _OrganizerAnalyticsPageState();
}

class _OrganizerAnalyticsPageState extends State<OrganizerAnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  int _totalParticipants = 0;
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _recentEvents = [];

  // Comparison state
  List<Map<String, dynamic>> _compareEventsData = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final eventsSnap = await _firestore
        .collection('events')
        .where('organizerId', isEqualTo: userId)
        .get();
    final events = eventsSnap.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id, // Add document ID for ratings lookup
    }).toList();
    int totalParticipants = 0;
    double totalRevenue = 0;
    for (final event in events) {
      final participants = (event['details']?['currentParticipants'] ?? 0) as int;
      totalParticipants += participants;
      final fee = (event['pricing']?['eventFee'] ?? 0.0) as num;
      totalRevenue += (fee * participants).toDouble();
    }
    events.sort((a, b) => ((b['details']?['currentParticipants'] ?? 0) as int).compareTo((a['details']?['currentParticipants'] ?? 0) as int));
    setState(() {
      _events = events;
      _totalParticipants = totalParticipants;
      _totalRevenue = totalRevenue;
      _recentEvents = events.take(5).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        elevation: 0,
        title: Text('Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildStatCard('Total Events', _events.length.toString(), Icons.event, accentColor),
                          _buildStatCard('Total Participants', _totalParticipants.toString(), Icons.people, Colors.blueAccent),
                          _buildStatCard('Total Revenue', 'RM${_totalRevenue.toStringAsFixed(2)}', Icons.monetization_on, Colors.orange),
                          _buildRatingStatsCard(),
                          if (_events.isNotEmpty)
                            _buildStatCard('Most Popular Event', _events.first['name'] ?? '-', Icons.star, Colors.purple),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('Recent Events', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildRecentEventsTable(),
                  const SizedBox(height: 40),
                  _buildCompareEventsChart(),
                  if (_compareEventsData.isNotEmpty) ...[
                    Text('Event Comparison', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildCompareEventsTable(),
                  ],
                ],
              ),
            ),
    );
  }

  void _showCompareEventsDialog() async {
    if (_events.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You need at least 2 events to compare', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selected = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        List<bool> selectedEvents = List.generate(_events.length, (_) => false);
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.compare_arrows, color: accentColor),
                const SizedBox(width: 12),
                Text('Select Events to Compare', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose 2 or more events to compare their performance metrics',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, i) {
                        final event = _events[i];
                        final date = event['date'] != null ? (event['date'] as Timestamp).toDate() : null;
                        final participants = event['details']?['currentParticipants'] ?? 0;
                        final revenue = ((event['pricing']?['eventFee'] ?? 0.0) * participants).toStringAsFixed(2);
                        
                        return CheckboxListTile(
                          value: selectedEvents[i],
                          onChanged: (checked) => setState(() => selectedEvents[i] = checked ?? false),
                          title: Text(
                            event['name'] ?? '-',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date != null)
                                Text(
                                  'Date: ${date.toString().split(' ').first}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              Text(
                                'Participants: $participants | Revenue: RM$revenue',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () {
                  final selectedData = [
                    for (int i = 0; i < _events.length; i++)
                      if (selectedEvents[i]) _events[i]
                  ];
                  if (selectedData.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select at least 2 events', style: GoogleFonts.poppins()),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, selectedData);
                },
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                child: Text('Compare Events', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );
      },
    );
    
    if (selected != null && selected.length >= 2) {
      setState(() {
        _compareEventsData = selected;
      });
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade700)),
        ],
      ),
    );
  }



  Widget _buildRecentEventsTable() {
    if (_recentEvents.isEmpty) {
      return _buildEmptyChart('No recent events');
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(accentColor.withOpacity(0.15)),
        columns: [
          DataColumn(label: Text('Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Participants', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Revenue', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Rating', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
        ],
        rows: [
          for (final event in _recentEvents)
            DataRow(cells: [
              DataCell(Text(event['name'] ?? '-', style: GoogleFonts.poppins())),
              DataCell(Text(event['date'] != null ? (event['date'] as Timestamp).toDate().toString().split(' ').first : '-', style: GoogleFonts.poppins())),
              DataCell(Text('${event['details']?['currentParticipants'] ?? 0}', style: GoogleFonts.poppins())),
              DataCell(Text('RM${((event['pricing']?['eventFee'] ?? 0.0) * (event['details']?['currentParticipants'] ?? 0)).toStringAsFixed(2)}', style: GoogleFonts.poppins())),
              DataCell(_buildEventRatingCell(event['id'] ?? '')),
              DataCell(Text(event['status'] ?? '-', style: GoogleFonts.poppins())),
            ]),
        ],
      ),
    );
  }

  Widget _buildRatingStatsCard() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return _buildStatCard('Overall Rating', 'N/A', Icons.star_rate, Colors.amber);
    }
    
    return FutureBuilder<OrganizerRatingStats?>(
      future: RatingService.getOrganizerStats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 220,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final stats = snapshot.data;
        if (stats == null || stats.totalRatings == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: 220,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rate, color: Colors.amber, size: 32),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < stats.averageRating.round()
                            ? Icons.star
                            : Icons.star_outline,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${stats.averageRating.toStringAsFixed(1)}/5.0',
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Overall Rating (${stats.totalRatings} reviews)',
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventRatingCell(String eventId) {
    if (eventId.isEmpty) {
      return Text('-', style: GoogleFonts.poppins());
    }
    
    return FutureBuilder<List<EventRating>>(
      future: RatingService.getEventRatings(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        
        final ratings = snapshot.data;
        if (ratings == null || ratings.isEmpty) {
          return Text('No ratings', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12));
        }
        
        final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
        final averageRating = totalRating / ratings.length;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 14),
            const SizedBox(width: 4),
            Text(
              '${averageRating.toStringAsFixed(1)} (${ratings.length})',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber[700],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompareEventsTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(accentColor.withOpacity(0.15)),
        columns: [
          DataColumn(label: Text('Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Registrations', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Revenue', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Paid %', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
        ],
        rows: [
          for (final event in _compareEventsData)
            DataRow(cells: [
              DataCell(Text(event['name'] ?? '-', style: GoogleFonts.poppins())),
              DataCell(Text('${event['details']?['currentParticipants'] ?? 0}', style: GoogleFonts.poppins())),
              DataCell(Text('RM${((event['pricing']?['eventFee'] ?? 0.0) * (event['details']?['currentParticipants'] ?? 0)).toStringAsFixed(2)}', style: GoogleFonts.poppins())),
              DataCell(Text(_getPaidPercent(event), style: GoogleFonts.poppins())),
            ]),
        ],
      ),
    );
  }

  String _getPaidPercent(Map<String, dynamic> event) {
    final participants = event['details']?['currentParticipants'] ?? 0;
    final paid = (event['participants'] as Map<String, dynamic>? ?? {}).values.where((p) => DataUtils.safeBool((p as Map<String, dynamic>)['paymentDetails']?['paid'])).length;
    if (participants == 0) return '-';
    return '${((paid / participants) * 100).toStringAsFixed(1)}%';
  }

  Widget _buildCompareEventsChart() {
    if (_compareEventsData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Performance Comparison', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare Events'),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                onPressed: _showCompareEventsDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Select two or more events to compare their performance.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Performance Comparison', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare Events'),
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
              onPressed: _showCompareEventsDialog,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSingleMetricChart('Registrations', _compareEventsData.map((e) => ((e['details']?['currentParticipants'] ?? 0) as num).toDouble()).toList(), accentColor, 'Participants')),
            const SizedBox(width: 16),
            Expanded(child: _buildSingleMetricChart('Revenue (RM)', _compareEventsData.map((e) => (((e['pricing']?['eventFee'] ?? 0.0) as num) * ((e['details']?['currentParticipants'] ?? 0) as num)).toDouble()).toList(), Colors.blue, 'RM')),
            const SizedBox(width: 16),
            Expanded(child: _buildSingleMetricChart('Payment Rate', _compareEventsData.map((e) {
              final participants = (e['details']?['currentParticipants'] ?? 0) as num;
              final paid = (e['participants'] as Map<String, dynamic>? ?? {}).values.where((p) => DataUtils.safeBool((p as Map<String, dynamic>)['paymentDetails']?['paid'])).length;
              if (participants == 0) return 0.0;
              return (paid / participants) * 100.0;
            }).map((v) => v.toDouble()).toList(), Colors.orange, '%')),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleMetricChart(String title, List<double> values, Color color, String unit) {
    final maxValue = values.isNotEmpty ? values.reduce((double a, double b) => a > b ? a : b) : 1.0;
    
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: [
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: color,
                          width: 30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return Text('0', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600));
                        if (value == maxValue) return Text('${value.toInt()}$unit', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600));
                        if (value == maxValue / 2) return Text('${(maxValue / 2).toInt()}$unit', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600));
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _compareEventsData.length) return const SizedBox.shrink();
                        final eventName = _compareEventsData[idx]['name'] ?? '-';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            width: 60,
                            child: Text(
                              eventName.length > 8 ? '${eventName.substring(0, 8)}...' : eventName,
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final eventName = _compareEventsData[group.x]['name'] ?? '-';
                      final value = values[group.x];
                      String displayValue;
                      
                      if (unit == '%') {
                        displayValue = '${value.toStringAsFixed(1)}%';
                      } else if (unit == 'RM') {
                        displayValue = 'RM${value.toStringAsFixed(2)}';
                      } else {
                        displayValue = value.toString();
                      }
                      
                      return BarTooltipItem(
                        '$eventName\n$title: $displayValue',
                        GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxValue / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                groupsSpace: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Text(message, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
    );
  }
} 