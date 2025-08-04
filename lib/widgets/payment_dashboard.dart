import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hikefue5/services/payment_service.dart';
import 'package:hikefue5/models/payment_status.dart';
import 'package:intl/intl.dart';

class PaymentDashboard extends StatefulWidget {
  const PaymentDashboard({super.key});

  @override
  State<PaymentDashboard> createState() => _PaymentDashboardState();
}

class _PaymentDashboardState extends State<PaymentDashboard> {
  static const Color primaryColor = Color(0xFF004A4D);
  static const Color accentColor = Color(0xFF94BC45);
  static const Color darkBackgroundColor = Color(0xFF231F20);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Payment Overview',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<PaymentInfo>>(
            stream: PaymentService.getUserPayments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final payments = snapshot.data ?? [];
              final pendingPayments = payments.where((p) => p.isPending).toList();
              final completedPayments = payments.where((p) => p.isCompleted).toList();
              final failedPayments = payments.where((p) => p.isFailed).toList();

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          pendingPayments.length.toString(),
                          Colors.orange,
                          Icons.pending,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          completedPayments.length.toString(),
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Failed',
                          failedPayments.length.toString(),
                          Colors.red,
                          Icons.error,
                        ),
                      ),
                    ],
                  ),
                  if (pendingPayments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPendingPaymentsList(pendingPayments),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentsList(List<PaymentInfo> pendingPayments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Payments',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...pendingPayments.take(3).map((payment) => _buildPendingPaymentItem(payment)),
        if (pendingPayments.length > 3)
          TextButton(
            onPressed: () {
              // Navigate to payments page
            },
            child: Text(
              'View all ${pendingPayments.length} pending payments',
              style: GoogleFonts.poppins(
                color: accentColor,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingPaymentItem(PaymentInfo payment) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: PaymentService.getEventDetails(payment.eventId),
      builder: (context, snapshot) {
        final eventName = snapshot.data?['name'] ?? 'Unknown Event';
        final isExpired = payment.isExpired;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isExpired ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${payment.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExpired 
                          ? 'Expired on ${DateFormat('MMM d').format(payment.deadline)}'
                          : 'Due ${DateFormat('MMM d').format(payment.deadline)}',
                      style: GoogleFonts.poppins(
                        color: isExpired ? Colors.red : Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: isExpired ? null : () => _handlePaymentAction(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired ? Colors.grey : accentColor,
                    foregroundColor: isExpired ? Colors.white70 : darkBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isExpired ? 'Expired' : 'Pay',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePaymentAction(PaymentInfo payment) async {
    try {
      final eventDetails = await PaymentService.getEventDetails(payment.eventId);
      if (eventDetails != null && mounted) {
        Navigator.pushNamed(
          context,
          '/payment',
          arguments: {
            'payment': payment,
            'eventDetails': eventDetails,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 