import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class CompanyProfileDialog extends StatefulWidget {
  const CompanyProfileDialog({super.key});

  @override
  State<CompanyProfileDialog> createState() => _CompanyProfileDialogState();
}

class _CompanyProfileDialogState extends State<CompanyProfileDialog> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  
  // Company Info Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _organizationController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyRegController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  // Bank details controllers
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _bankDetails = [];
  int _selectedBankIndex = -1;
  
  // Company logo
  String? _logoUrl;
  XFile? _selectedLogo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _organizationController.dispose();
    _companyPhoneController.dispose();
    _companyRegController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _swiftCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final doc = await _firestore.collection('organizers').doc(userId).get();
        if (doc.exists) {
          _profileData = doc.data();
          
          // Load basic info - Fix phone number persistence issue
          _nameController.text = _profileData?['name'] ?? '';
          _emailController.text = _auth.currentUser?.email ?? '';
          
          // Use companyPhone (from registration) or phone as fallback
          final phoneValue = _profileData?['companyPhone'] ?? _profileData?['phone'] ?? '';
          _companyPhoneController.text = phoneValue;
          
          // Load company details
          _organizationController.text = _profileData?['organizationName'] ?? '';
          _companyRegController.text = _profileData?['companyRegNumber'] ?? '';
          _websiteController.text = _profileData?['website'] ?? '';
          _descriptionController.text = _profileData?['description'] ?? '';
          
          // Load address info
          final address = _profileData?['address'] ?? {};
          _addressController.text = address['street'] ?? '';
          _cityController.text = address['city'] ?? '';
          _stateController.text = address['state'] ?? '';
          _postalCodeController.text = address['postalCode'] ?? '';
          
          _logoUrl = _profileData?['logoUrl'];
          
          // Load bank details
          final bankDocs = await _firestore
              .collection('organizers')
              .doc(userId)
              .collection('bankDetails')
              .get();
          
          _bankDetails = bankDocs.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  


  Future<void> _saveCompanyProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        String? logoDownloadUrl = _logoUrl;
        
        // Upload new logo if selected
        if (_selectedLogo != null) {
          logoDownloadUrl = await _uploadLogo();
        }
        
        await _firestore.collection('organizers').doc(userId).set({
          'name': _nameController.text.trim(),
          'companyPhone': _companyPhoneController.text.trim(), // Use consistent field name
          'phone': _companyPhoneController.text.trim(), // Keep both for compatibility
          'email': _emailController.text.trim(),
          'organizationName': _organizationController.text.trim(),
          'companyRegNumber': _companyRegController.text.trim(),
          'website': _websiteController.text.trim(),
          'description': _descriptionController.text.trim(),
          'address': {
            'street': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _stateController.text.trim(),
            'postalCode': _postalCodeController.text.trim(),
          },
          'logoUrl': logoDownloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company profile updated successfully!')),
        );
        setState(() => _isEditing = false);
        await _loadProfileData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<String?> _uploadLogo() async {
    if (_selectedLogo == null) return null;
    
    try {
      final userId = _auth.currentUser?.uid;
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('company_logos').child('$userId.jpg');
      
      if (kIsWeb) {
        final bytes = await _selectedLogo!.readAsBytes();
        await ref.putData(bytes);
      } else {
        final file = File(_selectedLogo!.path);
        await ref.putFile(file);
      }
      
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      return null;
    }
  }
  
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedLogo = pickedFile;
      });
    }
  }

  Future<void> _saveBankDetails() async {
    if (_bankNameController.text.trim().isEmpty ||
        _accountNumberController.text.trim().isEmpty ||
        _accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required bank details')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final bankData = {
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'accountHolder': _accountHolderController.text.trim(),
          'swiftCode': _swiftCodeController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        await _firestore
            .collection('organizers')
            .doc(userId)
            .collection('bankDetails')
            .add(bankData);
        
        _clearBankForm();
        await _loadProfileData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details saved successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving bank details: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearBankForm() {
    _bankNameController.clear();
    _accountNumberController.clear();
    _accountHolderController.clear();
    _swiftCodeController.clear();
  }

  Future<void> _deleteBankDetails(String bankId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore
            .collection('organizers')
            .doc(userId)
            .collection('bankDetails')
            .doc(bankId)
            .delete();
        
        await _loadProfileData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details deleted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bank details: $e')),
      );
    }
  }
  


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: darkBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Header with Company Info
            _buildHeader(),
            
            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.business), text: 'Company'),
                Tab(icon: Icon(Icons.account_balance), text: 'Banking'),
              ],
              labelColor: accentColor,
              unselectedLabelColor: Colors.white70,
              indicatorColor: accentColor,
            ),
            
            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: accentColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCompanyTab(),
                        _buildBankingTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final status = _profileData?['status'] ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Company Logo
          GestureDetector(
            onTap: _isEditing ? _pickLogo : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor, width: 2),
              ),
              child: _selectedLogo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb 
                          ? Image.network(_selectedLogo!.path, fit: BoxFit.cover)
                          : Image.file(File(_selectedLogo!.path), fit: BoxFit.cover),
                    )
                  : _logoUrl != null && _logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_logoUrl!, fit: BoxFit.cover),
                        )
                      : Icon(
                          _isEditing ? Icons.add_photo_alternate : Icons.business,
                          color: accentColor,
                          size: 32,
                        ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Company Name and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileData?['organizationName'] ?? 'Company Name',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusChip(status),
                    const SizedBox(width: 12),
                    Text(
                      'Reg: ${_profileData?['companyRegNumber'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Close Button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.verified;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Company Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                if (!_isEditing)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveCompanyProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _isEditing = false);
                          _loadProfileData();
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Basic Company Info
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _nameController,
                    label: 'Contact Person Name',
                    icon: Icons.person,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _organizationController,
                    label: 'Company Name',
                    icon: Icons.business,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _companyPhoneController,
                    label: 'Company Phone',
                    icon: Icons.phone,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _companyRegController,
                    label: 'Registration Number',
                    icon: Icons.badge,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _websiteController,
                    label: 'Website',
                    icon: Icons.web,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Company Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Company Description',
              icon: Icons.description,
              enabled: _isEditing,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Address Section
            Text(
              'Company Address',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _addressController,
              label: 'Street Address',
              icon: Icons.location_on,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.map,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    icon: Icons.markunread_mailbox,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banking Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildBankDetailsForm(),
          
          const SizedBox(height: 24),
          
          if (_bankDetails.isNotEmpty) ...[
            Text(
              'Saved Bank Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildSavedBankDetails(),
          ],
        ],
      ),
    );
  }



  Widget _buildBankDetailsForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _bankNameController,
                label: 'Bank Name',
                icon: Icons.account_balance,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _accountNumberController,
                label: 'Account Number',
                icon: Icons.credit_card,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _accountHolderController,
                label: 'Account Holder Name',
                icon: Icons.person,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _swiftCodeController,
                label: 'SWIFT Code (Optional)',
                icon: Icons.code,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveBankDetails,
            icon: const Icon(Icons.save),
            label: const Text('Save Bank Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedBankDetails() {
    return Column(
      children: _bankDetails.asMap().entries.map((entry) {
        final index = entry.key;
        final bank = entry.value;
        final isSelected = index == _selectedBankIndex;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.account_balance,
              color: isSelected ? accentColor : Colors.white70,
            ),
            title: Text(
              '${bank['bankName']} - ${bank['accountNumber']}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Account Holder: ${bank['accountHolder']}',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle, color: accentColor, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteBankDetails(bank['id']),
                ),
              ],
            ),
            onTap: () => setState(() => _selectedBankIndex = index),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        prefixIcon: Icon(icon, color: accentColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02),
      ),
      validator: enabled && controller == _nameController || controller == _organizationController || controller == _companyPhoneController
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }
}

// For backward compatibility, keep ProfileDialog as an alias
class ProfileDialog extends CompanyProfileDialog {
  const ProfileDialog({super.key});
}