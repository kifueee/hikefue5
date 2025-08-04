import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Theme colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class DriverApplicationForm extends StatefulWidget {
  final String eventId;
  const DriverApplicationForm({super.key, required this.eventId});

  @override
  State<DriverApplicationForm> createState() => _DriverApplicationFormState();
}

class _DriverApplicationFormState extends State<DriverApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  File? _licenseImage;
  bool _isLoading = false;
  String? _selectedVehicleType;
  List<String> _carMakes = [];
  List<String> _carModels = [];
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  Timer? _makeDebounce;
  Timer? _modelDebounce;

  @override
  void initState() {
    super.initState();
    _loadCarMakes();
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _makeDebounce?.cancel();
    _modelDebounce?.cancel();
    super.dispose();
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: Icon(icon, color: accentColor),
        errorStyle: GoogleFonts.poppins(color: Colors.red.shade300),
      ),
      validator: validator,
    );
  }

  Future<void> _loadCarMakes() async {
    setState(() {
      _isLoadingMakes = true;
    });

    try {
      // Malaysian car makes
      final makes = [
        'Perodua', 'Proton', 'Toyota', 'Honda', 'Nissan', 'Mitsubishi',
        'Mazda', 'Hyundai', 'Kia', 'Suzuki', 'Isuzu', 'Ford', 'Volkswagen',
        'BMW', 'Mercedes-Benz', 'Audi', 'Lexus', 'Subaru', 'Chevrolet', 'Peugeot'
      ];

      setState(() {
        _carMakes = makes;
        _isLoadingMakes = false;
      });
      
      print('Loaded car makes: $_carMakes'); // Debug log
    } catch (e) {
      print('Error loading car makes: $e');
      setState(() {
        _isLoadingMakes = false;
      });
    }
  }

  Future<void> _loadCarModels(String make) async {
    setState(() {
      _isLoadingModels = true;
    });

    try {
      // Malaysian car models by make
      final Map<String, List<String>> modelsByMake = {
        'Perodua': ['Myvi', 'Axia', 'Bezza', 'Alza', 'Ativa', 'Aruz'],
        'Proton': ['Saga', 'Persona', 'Iriz', 'X50', 'X70', 'Exora'],
        'Toyota': ['Vios', 'Corolla', 'Camry', 'Hilux', 'Fortuner', 'Alphard'],
        'Honda': ['City', 'Civic', 'Accord', 'CR-V', 'HR-V', 'BR-V'],
        'Nissan': ['Almera', 'Sylphy', 'Teana', 'X-Trail', 'Navara', 'Serena'],
        'Mitsubishi': ['Triton', 'Pajero', 'ASX', 'Outlander', 'Attrage'],
        'Mazda': ['Mazda2', 'Mazda3', 'Mazda6', 'CX-3', 'CX-5', 'CX-8'],
        'Hyundai': ['i10', 'i20', 'Elantra', 'Sonata', 'Tucson', 'Santa Fe'],
        'Kia': ['Picanto', 'Rio', 'Cerato', 'K3', 'K5', 'Sorento'],
        'Suzuki': ['Swift', 'Ciaz', 'Jimny', 'Vitara', 'Ertiga'],
        'Isuzu': ['D-Max', 'MU-X'],
        'Ford': ['Ranger', 'Everest', 'Raptor'],
        'Volkswagen': ['Polo', 'Golf', 'Passat', 'Tiguan', 'T-Roc'],
        'BMW': ['1 Series', '3 Series', '5 Series', 'X1', 'X3', 'X5'],
        'Mercedes-Benz': ['A-Class', 'C-Class', 'E-Class', 'GLC', 'GLE'],
        'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7'],
        'Lexus': ['ES', 'IS', 'NX', 'RX', 'LX'],
        'Subaru': ['Forester', 'XV', 'Outback', 'WRX'],
        'Chevrolet': ['Colorado', 'Trailblazer'],
        'Peugeot': ['208', '308', '3008', '5008'],
      };

      setState(() {
        _carModels = modelsByMake[make] ?? [];
        _isLoadingModels = false;
      });
      
      print('Loaded car models for $make: $_carModels'); // Debug log
    } catch (e) {
      print('Error loading car models: $e');
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _licenseImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadLicenseImage(String userId) async {
    if (_licenseImage == null) {
      print('No license image selected.');
      return null;
    }
    
    // Double-check authentication before upload
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not authenticated during upload');
      return null;
    }
    
    try {
      print('Uploading license image for user: $userId');
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://hikefue5-8f6ae',
      );
      final ref = storage.ref().child('license_photos/$userId.jpg');
      final uploadTask = ref.putFile(_licenseImage!);
      final snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        print('License image uploaded. Download URL: $url');
        return url;
      } else {
        print('Upload failed with state: ${snapshot.state}');
        return null;
      }
    } catch (e) {
      print('Error uploading license image: $e');
      // Provide more specific error messages
      if (e.toString().contains('unauthorized')) {
        print('Authentication error during upload. User may not be properly authenticated.');
      }
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all fields and upload your license photo.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You must be logged in to submit an application. Please log in and try again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    final userId = user.uid;
    final licensePhotoUrl = await _uploadLicenseImage(userId);
    if (licensePhotoUrl == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload license photo. Please try again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    // Combine vehicle details into a single string
    final vehicleDetails = '${_vehicleMakeController.text} ${_vehicleModelController.text} '
        '(${_vehicleColorController.text}) - ${_vehiclePlateController.text} '
        '- ${_selectedVehicleType?.toUpperCase()}';

    await FirebaseFirestore.instance
        .collection('driver_applications')
        .add({
      'userId': userId,
      'eventId': widget.eventId,
      'status': 'pending',
      'licenseNumber': _licenseNumberController.text.trim(),
      'licensePhotoUrl': licensePhotoUrl,
      'vehicleDetails': vehicleDetails,
      'vehicleMake': _vehicleMakeController.text.trim(),
      'vehicleModel': _vehicleModelController.text.trim(),
      'vehicleColor': _vehicleColorController.text.trim(),
      'vehiclePlate': _vehiclePlateController.text.trim(),
      'vehicleType': _selectedVehicleType,
      'submittedAt': FieldValue.serverTimestamp(),
      'name': user.displayName ?? '',
      'email': user.email ?? '',
    });

    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application submitted! Await organizer approval.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: accentColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Blur and overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: primaryColor.withOpacity(0.7),
            ),
          ),
          // Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    'Driver Application',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  centerTitle: true,
                  floating: true,
                  snap: true,
                ),
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // License Information
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.badge, color: accentColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'License Information',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _licenseNumberController,
                                    label: 'Driver License Number',
                                    icon: Icons.confirmation_number,
                                    validator: (v) => v == null || v.isEmpty ? 'Enter license number' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _licenseImage == null
                                      ? Container(
                                          width: double.infinity,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              style: BorderStyle.solid,
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: _pickImage,
                                            borderRadius: BorderRadius.circular(15),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.upload_file,
                                                  color: accentColor,
                                                  size: 32,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Upload License Photo',
                                                  style: GoogleFonts.poppins(
                                                    color: accentColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: double.infinity,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(
                                              color: accentColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: Image.file(
                                              _licenseImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Vehicle Details Section
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.directions_car, color: accentColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Vehicle Details',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Vehicle Type Dropdown
                                  DropdownButtonFormField<String>(
                                    value: _selectedVehicleType,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    dropdownColor: darkBackgroundColor,
                                    decoration: InputDecoration(
                                      labelText: 'Vehicle Type',
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(color: accentColor, width: 2),
                                      ),
                                      prefixIcon: const Icon(Icons.category, color: accentColor),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'sedan',
                                        child: Text('Sedan'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'suv',
                                        child: Text('SUV'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'mpv',
                                        child: Text('MPV'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'hatchback',
                                        child: Text('Hatchback'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'pickup',
                                        child: Text('Pickup Truck'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedVehicleType = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select vehicle type';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  // Vehicle Make and Model in a row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Make',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white.withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _vehicleMakeController.text.isEmpty ? null : _vehicleMakeController.text,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                              dropdownColor: darkBackgroundColor,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.1),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                                ),
                                                prefixIcon: const Icon(Icons.directions_car, color: accentColor),
                                                suffixIcon: _isLoadingMakes
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : null,
                                              ),
                                              items: _carMakes.map((make) {
                                                return DropdownMenuItem<String>(
                                                  value: make,
                                                  child: Text(
                                                    make,
                                                    style: GoogleFonts.poppins(color: Colors.white),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? make) {
                                                if (make != null) {
                                                  setState(() {
                                                    _vehicleMakeController.text = make;
                                                  });
                                                  _loadCarModels(make);
                                                }
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please select vehicle make';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Model',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white.withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _vehicleModelController.text.isEmpty ? null : _vehicleModelController.text,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                              dropdownColor: darkBackgroundColor,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.1),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                                ),
                                                prefixIcon: const Icon(Icons.model_training, color: accentColor),
                                                suffixIcon: _isLoadingModels
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : null,
                                              ),
                                              items: _carModels.map((model) {
                                                return DropdownMenuItem<String>(
                                                  value: model,
                                                  child: Text(
                                                    model,
                                                    style: GoogleFonts.poppins(color: Colors.white),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? model) {
                                                if (model != null) {
                                                  setState(() {
                                                    _vehicleModelController.text = model;
                                                  });
                                                }
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please select vehicle model';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Vehicle Color and Plate Number in a row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _vehicleColorController,
                                          label: 'Color',
                                          icon: Icons.color_lens,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter vehicle color';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _vehiclePlateController,
                                          label: 'Plate Number',
                                          icon: Icons.confirmation_number,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter plate number';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: darkBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(darkBackgroundColor),
                                      ),
                                    )
                                  : Text(
                                      'Submit Application',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: darkBackgroundColor,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
    );
  }
} 