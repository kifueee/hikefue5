import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/event_status_service.dart';

class QRAttendanceWidget extends StatefulWidget {
  final String eventId;
  final bool isOrganizer;

  const QRAttendanceWidget({
    Key? key,
    required this.eventId,
    required this.isOrganizer,
  }) : super(key: key);

  @override
  State<QRAttendanceWidget> createState() => _QRAttendanceWidgetState();
}

class _QRAttendanceWidgetState extends State<QRAttendanceWidget> {
  String? _qrData;
  DateTime? _qrGeneratedAt;

  @override
  void initState() {
    super.initState();
    if (widget.isOrganizer) {
      _generateQRCode();
    }
  }

  void _generateQRCode() {
    setState(() {
      _qrData = EventStatusService.generateAttendanceQRData(widget.eventId);
      _qrGeneratedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOrganizer) {
      return _buildOrganizerView();
    } else {
      return _buildParticipantView();
    }
  }

  Widget _buildOrganizerView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Attendance QR Code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_qrData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Generated: ${_qrGeneratedAt!.hour}:${_qrGeneratedAt!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Participants can scan this code to check in',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generateQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('Generate New Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan QR Code to Check In',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask the organizer to show the QR code',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showQRScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRScanner(BuildContext context) async {
    // Request camera permission first
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text('Camera access is needed to scan QR codes for event check-in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => QRScannerSheet(
          eventId: widget.eventId,
          onScanComplete: (result) {
            Navigator.of(context).pop();
            _showCheckInResult(context, result);
          },
        ),
      );
    }
  }

  void _showCheckInResult(BuildContext context, Map<String, dynamic> result) {
    final isSuccess = result['success'] ?? false;
    final message = result['message'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(isSuccess ? 'Check-in Successful!' : 'Check-in Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class QRScannerSheet extends StatefulWidget {
  final String eventId;
  final Function(Map<String, dynamic>) onScanComplete;

  const QRScannerSheet({
    Key? key,
    required this.eventId,
    required this.onScanComplete,
  }) : super(key: key);

  @override
  State<QRScannerSheet> createState() => _QRScannerSheetState();
}

class _QRScannerSheetState extends State<QRScannerSheet> {
  MobileScannerController? controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan QR Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (!_isProcessing && barcode.rawValue != null) {
                        _processQRCode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Custom overlay
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Processing check-in...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() => _isProcessing = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        widget.onScanComplete({
          'success': false,
          'message': 'You must be logged in to check in',
        });
        return;
      }

      final result = await EventStatusService.checkInWithQR(
        qrData,
        currentUser.uid,
      );
      
      widget.onScanComplete(result);
    } catch (e) {
      widget.onScanComplete({
        'success': false,
        'message': 'Error processing QR code: $e',
      });
    }
  }
}