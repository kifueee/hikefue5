import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/firestore_service.dart';
import '../../services/organizer_notification_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/tag.dart';

const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class OrganizerCreateEvent extends StatefulWidget {
  const OrganizerCreateEvent({super.key});

  @override
  State<OrganizerCreateEvent> createState() => _OrganizerCreateEventState();
}

class _OrganizerCreateEventState extends State<OrganizerCreateEvent> {
  int _currentStep = 0;
  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  bool _isSubmitting = false; // Add loading state

  // Step 1: Basic Information
  final _eventNameController = TextEditingController();
  final _eventDescriptionController = TextEditingController();
  DateTime? _eventDate;
  
  // Image upload variables
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploadingImage = false;
  String? _posterUrl;

  // Step 2: Event Details
  String? _selectedDifficulty;
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Hard', 'Expert'];
  String? _selectedFitnessLevel;
  final List<String> _fitnessLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  // Step 3: Location & Meeting Point
  final _locationController = TextEditingController();
  final _meetingPointController = TextEditingController();
  double? _locationLat, _locationLng;
  double? _meetingLat, _meetingLng;

  // Step 4: Schedule & Pricing
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _eventFeeController = TextEditingController(text: '10.00'); // Default to RM10.00
  DateTime? _paymentDeadline;

  // Step 5: Settings & Bank Details
  bool _isPublic = true;
  bool _isActive = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://hikefue5-8f6ae',
  );
  List<Map<String, dynamic>> _bankDetails = [];
  String? _selectedBankId;
  bool _loadingBanks = false;

  // Tag selection variables
  List<Tag> _availableTags = [];
  final List<String> _selectedTagIds = [];
  bool _loadingTags = false;

  // New tag creation
  final TextEditingController _newTagNameController = TextEditingController();
  Color _newTagColor = Colors.blue;
  bool _addingTag = false;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
    _fetchTags();
  }

  Future<void> _loadBankDetails() async {
    setState(() => _loadingBanks = true);
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final bankDocs = await _firestore.collection('organizers').doc(userId).collection('bankDetails').get();
      setState(() {
        _bankDetails = bankDocs.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        if (_bankDetails.isNotEmpty) {
          _selectedBankId = _bankDetails.first['id'];
        }
        _loadingBanks = false;
      });
    } else {
      setState(() => _loadingBanks = false);
    }
  }

  Future<void> _fetchTags() async {
    setState(() => _loadingTags = true);
    final tags = await FirestoreService().getAllTags();
    setState(() {
      _availableTags = tags;
      _loadingTags = false;
    });
  }

  Future<void> _addNewTag() async {
    final name = _newTagNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _addingTag = true);
    final tag = Tag(id: '', name: name, color: '#${_newTagColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    await FirestoreService().addTag(tag);
    _newTagNameController.clear();
    setState(() {
      _newTagColor = Colors.blue;
      _addingTag = false;
    });
    await _fetchTags();
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _selectedImageBytes = result.files.first.bytes;
          _selectedImageName = result.files.first.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImageBytes == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final userId = _auth.currentUser?.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'event_posters/${userId}_$timestamp.jpg';
      
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putData(
        _selectedImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _posterUrl = downloadUrl;
        _isUploadingImage = false;
      });

      return downloadUrl;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e', style: GoogleFonts.poppins())),
      );
      return null;
    }
  }

  void _nextStep() {
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      if (_currentStep < 4) {
        setState(() => _currentStep++);
      } else {
        _submitEvent();
      }
    }
  }

  void _backStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submitEvent() async {
    if (_isSubmitting) return; // Prevent multiple submissions
    
    setState(() => _isSubmitting = true);
    
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    // Fetch organizer profile info
    final organizerProfile = await FirestoreService().getUserData(userId, 'organizer');
    
    // Debug: Print organizer profile data
    print('Organizer profile data: $organizerProfile');
    print('Organization name: ${organizerProfile?['organizationName']}');
    print('Company phone: ${organizerProfile?['companyPhone']}');
    print('Email: ${organizerProfile?['email']}');
    print('Name: ${organizerProfile?['name']}');

    // Upload image if selected but not uploaded yet
    String? finalPosterUrl = _posterUrl;
    if (_selectedImageBytes != null && _posterUrl == null) {
      finalPosterUrl = await _uploadImage();
    }

    // Get selected bank details
    Map<String, dynamic>? selectedBank;
    if (_selectedBankId != null) {
      selectedBank = _bankDetails.firstWhere((bank) => bank['id'] == _selectedBankId);
    }

    final eventData = {
      'name': _eventNameController.text.trim(),
      'description': _eventDescriptionController.text.trim(),
      'date': _eventDate,
      'details': {
        'difficulty': _selectedDifficulty,
        'distance': double.tryParse(_distanceController.text) ?? 0,
        'duration': double.tryParse(_durationController.text) ?? 0,
        'fitnessLevel': _selectedFitnessLevel,
        'maxParticipants': int.tryParse(_maxParticipantsController.text) ?? 0,
        'currentParticipants': 1, // Organizer is first participant
      },
      'location': {
        'address': _locationController.text.trim(),
        'coordinates': {
          'latitude': _locationLat ?? 0.0,
          'longitude': _locationLng ?? 0.0,
        },
      },
      'meetingPoint': {
        'address': _meetingPointController.text.trim(),
        'coordinates': {
          'latitude': _meetingLat ?? 0.0,
          'longitude': _meetingLng ?? 0.0,
        },
      },
      'media': {
        'images': finalPosterUrl != null ? [finalPosterUrl] : [],
        if (finalPosterUrl != null) 'posterUrl': finalPosterUrl,
      },
      'schedule': {
        'startTime': _startTime != null ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' : '',
        'endTime': _endTime != null ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : '',
      },
      'pricing': {
        'eventFee': double.tryParse(_eventFeeController.text) ?? 0,
        'paymentDeadline': _paymentDeadline,
        'bankDetails': selectedBank != null ? {
          'bankName': selectedBank['bankName'],
          'accountNumber': selectedBank['accountNumber'],
          'accountHolder': selectedBank['accountHolder'],
        } : null,
      },
      'metadata': {
        'isActive': _isActive,
        'isPublic': _isPublic,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      'organizer': {
        'id': userId,
        'role': 'organizer',
        'name': organizerProfile?['organizationName'] ?? organizerProfile?['name'] ?? 'Unknown Organization',
        'email': organizerProfile?['email'] ?? 'No email available',
        'phone': organizerProfile?['companyPhone'] ?? organizerProfile?['phone'] ?? 'No phone available',
        if (organizerProfile != null && organizerProfile['logoUrl'] != null) 'logoUrl': organizerProfile['logoUrl'],
      },
      'organizerId': userId,
      'participants': {
        userId: {
          'role': 'organizer',
          'status': 'registered',
          'registeredAt': FieldValue.serverTimestamp(),
          'paymentDetails': {
            'amount': 0, // Organizer doesn't pay
            'paid': true,
            'paymentStatus': 'completed',
          },
        },
      },
      'status': 'approved',
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'tags': _selectedTagIds,
    };

    final docRef = await _firestore.collection('events').add(eventData);
    
    // Create notification for event creation
    await OrganizerNotificationService.onEventCreated(
      docRef.id,
      _eventNameController.text.trim(),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event created successfully! Your event is now live and ready for participants.', style: GoogleFonts.poppins()),
          backgroundColor: accentColor,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDescriptionController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _maxParticipantsController.dispose();
    _locationController.dispose();
    _meetingPointController.dispose();
    _eventFeeController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.white60),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          // Blurred Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: primaryColor.withOpacity(0.7)),
          ),
          // Back button (top left)
          Positioned(
            top: 24,
            left: 24,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Stepper Progress Bar
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              decoration: BoxDecoration(
                                color: darkBackgroundColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  for (int i = 0; i < 5; i++) ...[
                                    _buildStepIndicator(i + 1, i <= _currentStep, i == _currentStep),
                                    if (i < 4) _buildStepConnector(i < _currentStep),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 48),
                            
                            // Step Content
                            if (_currentStep == 0) _buildStepOne(),
                            if (_currentStep == 1) _buildStepTwo(),
                            if (_currentStep == 2) _buildStepThree(),
                            if (_currentStep == 3) _buildStepFour(),
                            if (_currentStep == 4) _buildStepFive(),
                          ],
                        ),
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
  }

  Widget _buildStepIndicator(int step, bool completed, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: completed || active ? accentColor : Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: completed && !active
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                step.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _buildStepConnector(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: active ? accentColor : Colors.white.withOpacity(0.2),
      ),
    );
  }

  Widget _buildStepOne() {
    return Form(
      key: _formKeys[0],
      child: Column(
        children: [
          Text(
            'Basic Information',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Event Poster Upload
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
        child: Column(
              children: [
                if (_selectedImageBytes == null) ...[
                  Icon(Icons.add_photo_alternate, color: accentColor, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Add Event Poster',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload an attractive poster for your event',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else ...[
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(_selectedImageBytes!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedImageName ?? 'Selected Image',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImageBytes = null;
                            _selectedImageName = null;
                            _posterUrl = null;
                          });
                        },
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  if (_isUploadingImage) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(color: accentColor),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading image...',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _eventNameController,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration('Event name...'),
            validator: (v) => v == null || v.isEmpty ? 'Please enter event name' : null,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _eventDescriptionController,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration('Describe your hiking event...'),
            maxLines: 3,
            validator: (v) => v == null || v.isEmpty ? 'Please enter description' : null,
          ),
          const SizedBox(height: 24),
          _buildTagSelector(),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: accentColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event Date', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      Text(
                        _eventDate == null ? 'Select date' : _eventDate!.toLocal().toString().split(' ')[0],
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Pick Date', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_eventDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select an event date', style: GoogleFonts.poppins())),
                  );
                  return;
                }
                _nextStep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONTINUE TO NEXT STEP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector() {
    if (_loadingTags) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: CircularProgressIndicator(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: accentColor,
            letterSpacing: 1.2,
          ),
        ),
        Wrap(
          spacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTagIds.contains(tag.id);
            return ChoiceChip(
              label: Text(tag.name, style: GoogleFonts.poppins(color: Colors.white)),
              selected: isSelected,
              backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')),
              selectedColor: Color(int.parse('0xff${tag.color.substring(1)}')).withOpacity(0.8),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTagIds.add(tag.id);
                  } else {
                    _selectedTagIds.remove(tag.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTagNameController,
                decoration: InputDecoration(
                  labelText: 'Add new tag',
                  labelStyle: GoogleFonts.poppins(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: () async {
                Color picked = _newTagColor;
                await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Pick Tag Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: _newTagColor,
                          onColorChanged: (color) {
                            picked = color;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Select'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
                setState(() {
                  _newTagColor = picked;
                });
              },
            ),
            _addingTag
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addNewTag,
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Form(
      key: _formKeys[1],
      child: Column(
        children: [
            Text(
            'Event Details',
            style: GoogleFonts.poppins(
              fontSize: 32,
                fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // Difficulty Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Difficulty',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: _difficulties.map((difficulty) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDifficulty = difficulty),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedDifficulty == difficulty ? accentColor : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedDifficulty == difficulty ? accentColor : Colors.white.withOpacity(0.3),
                            width: _selectedDifficulty == difficulty ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          difficulty,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: _selectedDifficulty == difficulty ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Fitness Level Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fitness Level',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: _fitnessLevels.map((level) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFitnessLevel = level),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedFitnessLevel == level ? accentColor : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFitnessLevel == level ? accentColor : Colors.white.withOpacity(0.3),
                            width: _selectedFitnessLevel == level ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          level,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: _selectedFitnessLevel == level ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Input Fields Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _distanceController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  decoration: _inputDecoration('Distance (km)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Enter distance' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  decoration: _inputDecoration('Duration (hours)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Enter duration' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _maxParticipantsController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  decoration: _inputDecoration('Max participants'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Enter max participants' : null,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    return Form(
      key: _formKeys[2],
      child: Column(
        children: [
          Text(
            'Location & Meeting Point',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LocationPicker(
            label: 'Event Location',
            hint: 'Search or pick event location...',
            icon: Icons.location_on,
            iconColor: accentColor,
            initialValue: _locationController.text,
            onLocationSelected: (address, latLng) {
              setState(() {
                _locationController.text = address;
                _locationLat = latLng.latitude;
                _locationLng = latLng.longitude;
              });
            },
            extraMarkers: _meetingLat != null && _meetingLng != null
                ? {
                    Marker(
                      markerId: const MarkerId('meeting_point'),
                      position: LatLng(_meetingLat!, _meetingLng!),
                      infoWindow: const InfoWindow(title: 'Meeting Point'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  }
                : {},
            searchBoxId: 'event-location-search-box',
          ),
          const SizedBox(height: 24),
          LocationPicker(
            label: 'Meeting Point',
            hint: 'Search or pick meeting point...',
            icon: Icons.meeting_room,
            iconColor: accentColor,
            initialValue: _meetingPointController.text,
            onLocationSelected: (address, latLng) {
              setState(() {
                _meetingPointController.text = address;
                _meetingLat = latLng.latitude;
                _meetingLng = latLng.longitude;
              });
            },
            extraMarkers: _locationLat != null && _locationLng != null
                ? {
                    Marker(
                      markerId: const MarkerId('event_location'),
                      position: LatLng(_locationLat!, _locationLng!),
                      infoWindow: const InfoWindow(title: 'Event Location'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                  }
                : {},
            searchBoxId: 'meeting-point-search-box',
          ),
          const SizedBox(height: 40),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepFour() {
    return Form(
      key: _formKeys[3],
      child: Column(
        children: [
          Text(
            'Schedule & Pricing',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Time Selection
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) setState(() => _startTime = time);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: accentColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _startTime?.format(context) ?? 'Select time',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Time', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) setState(() => _endTime = time);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: accentColor, size: 20),
                            const SizedBox(width: 8),
            Text(
                              _endTime?.format(context) ?? 'Select time',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Event Fee
          TextFormField(
            controller: _eventFeeController,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration('Event fee (RM) - Minimum RM1.00'),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter event fee';
              final fee = double.tryParse(v);
              if (fee == null) return 'Enter a valid amount';
              if (fee < 1.0) return 'Event fee must be at least RM1.00';
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Payment Deadline
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: accentColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Deadline', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      Text(
                        _paymentDeadline == null ? 'Select deadline' : _paymentDeadline!.toLocal().toString().split(' ')[0],
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: _eventDate ?? DateTime(2100),
                    );
                    if (picked != null) setState(() => _paymentDeadline = picked);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Pick Date', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepFive() {
    return Form(
      key: _formKeys[4],
      child: Column(
        children: [
          Text(
            'Settings & Payment Details',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Event Settings
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.public, color: accentColor, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Public Event', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                          Text('Allow anyone to see and join this event', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: (value) => setState(() => _isPublic = value),
                      activeColor: accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.visibility, color: accentColor, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Event', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                          Text('Event is ready for registrations', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeColor: accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Bank Details Selection
          Text('Select Payment Details', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          
          _loadingBanks
              ? const CircularProgressIndicator(color: accentColor)
              : _bankDetails.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        'No bank details found. Please add bank details in your profile.',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: _bankDetails.map((bank) => GestureDetector(
                        onTap: () => setState(() => _selectedBankId = bank['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _selectedBankId == bank['id'] ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedBankId == bank['id'] ? accentColor : Colors.white.withOpacity(0.3),
                              width: _selectedBankId == bank['id'] ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance,
                                color: _selectedBankId == bank['id'] ? accentColor : Colors.white70,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${bank['bankName']} - ${bank['accountNumber']}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Account Holder: ${bank['accountHolder']}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedBankId == bank['id'])
                                Icon(Icons.check_circle, color: accentColor, size: 24),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
          
          const SizedBox(height: 40),
          
          // Final Submit Button
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _backStep,
                  child: Text('Back', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () {
                    if (_selectedBankId == null && _bankDetails.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select bank details', style: GoogleFonts.poppins())),
                      );
                      return;
                    }
                    if (_startTime == null || _endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select start and end times', style: GoogleFonts.poppins())),
                      );
                      return;
                    }
                    if (_paymentDeadline == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select payment deadline', style: GoogleFonts.poppins())),
                      );
                      return;
                    }
                    _submitEvent();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('CREATE EVENT'),
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: TextButton(
              onPressed: _backStep,
              child: Text('Back', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              // Validate current step
              if (_currentStep == 1) {
                if (_selectedDifficulty == null || _selectedFitnessLevel == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select difficulty and fitness level', style: GoogleFonts.poppins())),
                  );
                  return;
                }
              }
              _nextStep();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONTINUE TO NEXT STEP'),
          ),
        ),
      ],
    );
  }
} 